package joy

import "core:fmt"
import "core:log"
import "lib:emu"

BITS :: emu.Bitsize

// BUTTON3 does not exists, in fact it fills the gap in bit_set
JOYSIGS :: enum {UP, DOWN, LEFT, RIGHT, BUTTON0, BUTTON3, BUTTON1, BUTTON2}

JOY :: struct {
    name:       string,
    id:         u8,

    read:       proc(^JOY, BITS, u32, u32) -> u32,
    write:      proc(^JOY, BITS, u32, u32,    u32),
    delete:     proc(^JOY),

    state:      bit_set[JOYSIGS; u32]
}

joy_c256_make :: proc(name: string) -> ^JOY {
    j             := new(JOY)
    j.name         = name
    j.delete       = joy_c256_delete
    j.read         = joy_c256_read
    j.write        = joy_c256_write
    return j
}

joy_c256_read :: proc(j: ^JOY, mode: BITS, base, busaddr: u32) -> (val: u32) {
    addr := busaddr - base
    switch addr {
    case 0: 
        //log.debugf("%s: Read  addr %6x returned %08b", j.name, busaddr, ~j.state)
        val = transmute(u32) ~j.state       // there is reverse logic for that? again?
    case  : 
        log.warnf("%s: Read  addr %6x is not implemented, 0 returned", j.name, busaddr)
    }
    return
}

joy_c256_write :: proc(j: ^JOY, mode: BITS, base, busaddr, val: u32) {
    log.warnf("%s: wrte addr %6x val %02x not implemented", j.name, busaddr, val)
}

joy_c256_delete :: proc(j: ^JOY) {
    free(j)
}

// eof
