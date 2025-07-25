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

BITS :: emu.Bitsize
TTY  :: struct {
    read:     proc(^TTY, BITS, u32, u32) -> u32,
    write:    proc(^TTY, BITS, u32, u32,    u32),
    delete:   proc(^TTY),

    name:       string,
    id:         int,

    master:     os.Handle,
    slave:      os.Handle,
    pty_name:   [128]u8,
    debug:      bool,
}

tty_make :: proc(name: string) -> ^TTY {
    d         := new(TTY)
    d.delete   = tty_delete
    d.name     = name

    pty_ok    := false
    when ODIN_OS == .Linux {
        if err := openpty(&d.master, &d.slave, &d.pty_name[0], nil, nil); err == 0 {
            pty_ok = true
            d.pty_name[127] = 0
            log.infof("tty: PTY available %s", transmute(cstring)&d.pty_name)
        }
    }

    if pty_ok {
        //t.read     = tty_read
        d.read     = tty_fake_read      // read support not ready yet
        d.write    = tty_write
    } else {
        d.read     = tty_fake_read
        d.write    = tty_fake_write
        log.warnf("tty: PTY not available or not supported, using dummy routines")
    }

    return d
}

// not used yet
tty_read :: proc(d: ^TTY, mode: BITS, base, busaddr: u32) -> (val: u32) {

    if mode != .bits_8 {
        emu.unsupported_read_size(#procedure, d.name, d.id, mode, busaddr)
        return
    }

    return 0xFF
}

tty_write :: proc(d: ^TTY, mode: BITS, base, busaddr, val: u32) {

    if mode != .bits_8 {
        emu.unsupported_write_size(#procedure, d.name, d.id, mode, busaddr, val)
        return
    }

    // this is sick. first such a thing I found in Odin
    k, i := utf8.encode_rune(rune(val))
    fmt.fprintf(d.master, string(k[:i]))
    return
}

tty_fake_read :: proc(d: ^TTY, mode: BITS, base, busaddr: u32) -> (val: u32) {
    log.warnf("tty: %6s Read  addr %6x is not implemented, 0xFF returned", d.name, busaddr)
    return 0xFF
}

tty_fake_write :: proc(d: ^TTY, mode: BITS, base, busaddr, val: u32)         {
    log.warnf("tty: %6s Write addr %6x val %2x is not implemented", d.name, busaddr, val)
    return
}

tty_delete :: proc(d: ^TTY) {
    when ODIN_OS == .Linux {
        fmt.fprintf(d.master, "\n\n\n*** exiting\n")
        //time.sleep(time.Second * 10)
        os.close(d.master)
        os.close(d.slave)
    }
    free(d)
}


