package kbd

// Copyright 2026 Piotr Meyer <aniou+morfeo@smutek.pl>

import "core:container/queue"
import "core:log"

import "lib:emu"

import "emulator:pic"

/* from Gadget's kbd_f256k2.asm
OPT_KBD_DATA     = $ddc0        ; Data Port - Need to read 16 bytes (to complete Scan Set)
OPT_KBD_STAT     = $ddc1        ; {MECH_OPTICALn_i, 3'b000, 3'b000, empty}; empty when 1, FIFO has content when Empty = 0, MECH_Optical = 0 if OpticalKey Keyboard installed
OPT_KBD_CNT_LO   = $ddc2        ; 3'b010: CPU_D_o = rd_data_count[7:0];
OPT_KBD_CNT_HI   = $ddc3        ; 3'b011: CPU_D_o = {4'b0000, rd_data_count[11:8]};
*/

OPT_KBD_DATA    :: 0x00
OPT_KBD_STATUS  :: 0x01
OPT_KBD_CNT_LO  :: 0x02
OPT_KBD_CNT_HI  :: 0x03

MODE :: emu.OpMode
KBD  :: struct {
    delete:    proc(^KBD),
    read:      proc(^KBD, MODE, u32, u32) -> u32,
    write:     proc(^KBD, MODE, u32, u32,    u32),

    send_key:  proc(^KBD, emu.KEY, emu.KEY_STATE),
    //kick:      proc(^KBD),

    pic:           ^pic.PIC,
    name:           string,
    id:             int,

    outbuf:         queue.Queue(u32),		// 2048 characters max?
    key_state:      [8][2]u32,

    debug:          bool,   // temporary
}

make_kbd :: proc(name: string, pic: ^pic.PIC) -> ^KBD {
    k             := new(KBD)
    k.pic          = pic
    k.delete       = delete_kbd
    k.read         =   read_kbd
    k.write        =  write_kbd
    k.send_key     =   send_kbd_key

    k.debug        = true
    k.name         = name

    for a in 0..=7 {
        k.key_state[a][0] = u32(a << 4)
    }

    queue.init(&k.outbuf)
    return k
}

delete_kbd :: proc(d: ^KBD) {
    free(d)
}

read_kbd :: proc(kbd: ^KBD, mode: MODE, addr, ra: u32) -> (out: u32) {

    if mode != .mode_8 {
        emu.error_read(kbd.name, .BAD_MODE, mode, addr, ra, .NONE)
        return
    }

    switch addr {
    case OPT_KBD_DATA:
        if queue.len(kbd.outbuf) == 0 {
            out = 0
            log.debugf("kbd: %6s read     KBD_DATA: read from empty queue", kbd.name)
            return
        }
        out = queue.pop_front(&kbd.outbuf)
        if kbd.debug {
            log.debugf("kbd: %6s read     KBD_DATA: out %02x qlen: %d", kbd.name, out, queue.len(kbd.outbuf))
            //for a in 0 ..< queue.len(kbd.outbuf) {
            //    log.debugf("kbd: %6s read     KBD_DATA:  queue remain: %02x", kbd.name, queue.get(&kbd.outbuf, a))
            //}
        }

	case OPT_KBD_STATUS: out = 0 if queue.len(kbd.outbuf) > 0 else 1
	case OPT_KBD_CNT_LO: out = u32( queue.len(kbd.outbuf)       & 0xFF)
	case OPT_KBD_CNT_HI: out = u32((queue.len(kbd.outbuf) >> 8) & 0xFF)
    }

    return
}

write_kbd :: proc(kbd: ^KBD, mode: MODE, addr, ra, val: u32)          {
    emu.error_write(kbd.name, .NOT_IMPL, mode, addr, ra, val, .NONE)
	return
}

send_kbd_key :: proc(s: ^KBD, key: emu.KEY, state: emu.KEY_STATE) {
        log.debugf("------")
        log.debugf("kbd: %6s send_key %v current status %v", s.name, key, state)

        row    := scancode[key][0]
        high   := scancode[key][1]
        bit9   := scancode[key][2]
        low    := scancode[key][3]

        if row > 7 {
            log.debugf("kbd: %6s not-mapped key %v, skipping", s.name, key)
            return
        }

        s.key_state[row][0] = row << 4 
        if state == .DOWN {
            s.key_state[row][0]   |= bit9
            s.key_state[row][1]   |= low
        } else {
            s.key_state[row][1]  &~= low
        }

        for k in s.key_state {
            queue.push_back(&s.outbuf, k[0])
            queue.push_back(&s.outbuf, k[1])
        }

        s.pic->trigger(.KBD_A2560K)     // XXX: clean-up and provide common names for irqs
        return
}

