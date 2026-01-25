package tty

// It is a kind of 'fake' TTY 

import "core:c"
import "core:fmt"
import "core:log"
import "core:os"
import "core:time"
import "core:unicode/utf8"
import "lib:emu"

when ODIN_OS == .Linux {
    foreign import pty "system:util"

    foreign pty {
        openpty     :: proc "c" (rawptr, rawptr, rawptr, rawptr, rawptr) -> int ---
    }
}

MODE :: emu.OpMode
TTY  :: struct {
    name:     string,
    req:      ^emu.BusRequest,
    debug:    bool,

    delete:   proc(^TTY),
    read:     proc(^TTY, MODE, u32, u32) -> u32,
    write:    proc(^TTY, MODE, u32, u32,    u32),

    master:     os.Handle,
    slave:      os.Handle,
    pty_name:   [128]u8,
}

make_tty :: proc(name: string, dcb: ^emu.DeviceConfig) -> ^TTY {
    d         := new(TTY)
    d.name     = name
    d.req      = dcb.req

    d.delete   = delete_tty

    pty_ok    := false
    when ODIN_OS == .Linux {
        if err := openpty(&d.master, &d.slave, &d.pty_name[0], nil, nil); err == 0 {
            pty_ok = true
            d.pty_name[127] = 0
            log.infof("tty: PTY available %s", transmute(cstring)&d.pty_name)
            time.sleep(5 * time.Second)
        }
    }

    if pty_ok {
        d.read     =  read_tty
        d.write    = write_tty
    } else {
        d.read     =  read_tty_fake
        d.write    = write_tty_fake
        log.warnf("tty: PTY not available or not supported, using dummy routines")
    }

    return d
}

// not used yet
read_tty :: proc(tty: ^TTY, mode: MODE, addr, ra: u32) -> (out: u32) {

    if mode != .mode_8 {
        emu.error_read(tty.name, tty.req, .BAD_MODE, mode, addr)
        return
    }
    v : [1]u8

    _, err := os.read(tty.master, v[0:])
    if err != 0 {
        log.errorf("TTY read error: %s", err)
        return 0
    }

    return u32(v[0])
}

delete_tty :: proc(tty: ^TTY) {
    when ODIN_OS == .Linux {
        fmt.fprintf(tty.master, "\n\n\n*** exiting\n")
        //time.sleep(time.Second * 10)
        os.close(tty.master)
        os.close(tty.slave)
    }
    free(tty)
}

write_tty :: proc(tty: ^TTY, mode: MODE, addr, ra, val: u32) {

    if mode != .mode_8 {
        emu.error_write(tty.name, tty.req, .BAD_MODE, mode, addr, val)
        return
    }

    // this is sick. first such a thing I found in Odin
    k, i := utf8.encode_rune(rune(val))
    fmt.fprintf(tty.master, string(k[:i]))
    return
}

read_tty_fake :: proc(tty: ^TTY, mode: MODE, addr, ra: u32) -> (out: u32 = 0x55) {
	emu.error_read(tty.name, tty.req, .BAD_MODE, mode, addr)
	return
}

write_tty_fake :: proc(tty: ^TTY, mode: MODE, addr, ra, val: u32)         {
    emu.error_write(tty.name, tty.req, .BAD_MODE, mode, addr, val)
}


