package joy

import "core:fmt"
import "core:log"
import "lib:emu"

MODE :: emu.OpMode

// BUTTON3 does not exists, in fact it fills the gap in bit_set
JOYSIGS :: enum {UP, DOWN, LEFT, RIGHT, BUTTON0, BUTTON3, BUTTON1, BUTTON2}

JOY :: struct {
    name:       string,
    id:         u8,

    read:       proc(^JOY, MODE, u32, u32) -> u32,
    write:      proc(^JOY, MODE, u32, u32,    u32),
    delete:     proc(^JOY),

    state:      bit_set[JOYSIGS; u32]
}

joy_c256_make :: proc(name: string) -> ^JOY {
    joy             := new(JOY)
    joy.name         = name
    joy.delete       = delete_joy_c256
    joy.read         =   read_joy_c256
    joy.write        =  write_joy_c256
    return joy
}

delete_joy_c256 :: proc(joy: ^JOY) {
    free(joy)
}


read_joy_c256 :: proc(j: ^JOY, mode: MODE, addr, ra: u32) -> (out: u32 = 0x55) {
    switch addr {
    case 0: 
        //log.debugf("%s: Read  addr %6x returned %08b", j.name, busaddr, ~j.state)
        out = transmute(u32) ~j.state       // there is reverse logic for that? again?
    case  : 
         emu.error_read(j.name, .NOT_IMPL, mode, addr, ra)
    }
    return
}

write_joy_c256 :: proc(j: ^JOY, mode: MODE, addr, ra, val: u32) {
    emu.error_write(j.name, .NOT_IMPL, mode, addr, ra, val)
}

// eof
