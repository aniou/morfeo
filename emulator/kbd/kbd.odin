package kbd

// Copyright 2026 Piotr Meyer <aniou+morfeo@smutek.pl>

import "core:container/queue"
import "core:log"
import "emulator:pic"
import "lib:emu"

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

BITS :: emu.Bitsize
ADDR :: emu.BusAddress
KBD  :: struct {
    nread:     proc(^KBD, ADDR) -> u32,
    nwrite:    proc(^KBD, ADDR,    u32),
    send_key:  proc(^KBD, emu.KEY, emu.KEY_STATE),
    delete:    proc(^KBD),
    //kick:      proc(^KBD),

    pic:           ^pic.PIC,
    name:           string,
    id:             int,

    outbuf:         queue.Queue(u32),		// 2048 characters max?
    key_state:      [8][2]u32,

    debug:          bool,   // temporary
}

kbd_make :: proc(name: string, pic: ^pic.PIC) -> ^KBD {
    s             := new(KBD)
    s.pic          = pic
    s.nread        = kbd_nread
    s.nwrite       = kbd_nwrite
    s.delete       = kbd_delete
    s.send_key     = kbd_send_key
    s.debug        = true
    s.name         = name

    for a in 0..=7 {
        s.key_state[a][0] = u32(a << 4)
    }

    queue.init(&s.outbuf)
    return s
}

kbd_nread :: proc(s: ^KBD, ba: ADDR) -> (val: u32) {

    if ba.size != .bits_8 {
        emu.unsupported_read_size(#procedure, s.name, ba)
        return
    }

	addr := ba.ea - ba.base
    switch addr {
    case OPT_KBD_DATA:
        if queue.len(s.outbuf) == 0 {
            val = 0
            log.debugf("kbd: %6s read     KBD_DATA: read from empty queue", s.name)
            return
        }
        val = queue.pop_front(&s.outbuf)
        if s.debug {
            log.debugf("kbd: %6s read     KBD_DATA: val %02x qlen: %d", s.name, val, queue.len(s.outbuf))
            //for a in 0 ..< queue.len(s.outbuf) {
            //    log.debugf("kbd: %6s read     KBD_DATA:  queue remain: %02x", s.name, queue.get(&s.outbuf, a))
            //}
        }

	case OPT_KBD_STATUS: val = 0 if queue.len(s.outbuf) > 0 else 1
	case OPT_KBD_CNT_LO: val = u32( queue.len(s.outbuf)       & 0xFF)
	case OPT_KBD_CNT_HI: val = u32((queue.len(s.outbuf) >> 8) & 0xFF)
    }

    return
}

kbd_nwrite :: proc(s: ^KBD, ba: ADDR, val: u32) {
    emu.write_not_implemented(#procedure, "kbd0", ba, val)
	return
}

kbd_delete :: proc(d: ^KBD) {
    free(d)
}

kbd_send_key :: proc(s: ^KBD, key: emu.KEY, state: emu.KEY_STATE) {
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

