package rng

import "core:fmt"
import "core:log"
import "core:math/rand"
import "lib:emu"

MODE :: emu.OpMode

// a very rudimentary implementation, has nothing with original RNG
// does not support seeding etc.

RNG :: struct {
    name:       string,

    delete:     proc(^RNG),
    read:       proc(^RNG, MODE, u32, u32) -> u32,
    write:      proc(^RNG, MODE, u32, u32,    u32),

    seed:       u32,        // in real: u16
}

rng_c256_make :: proc(name: string) -> ^RNG {
    rng             := new(RNG)
    rng.name         = name

    rng.delete       = delete_rng_c256
    rng.read         =   read_rng_c256
    rng.write        =  write_rng_c256

    return rng
}

delete_rng_c256:: proc(r: ^RNG) {
    free(r)
}


read_rng_c256 :: proc(r: ^RNG, mode: MODE, addr, ra: u32) -> (out: u32 = 0x55) {
    switch addr {
    case 0: out = u32(rand.int_max(256))
    case 1: out = u32(rand.int_max(256))
    case  : emu.error_read(r.name, .NOT_IMPL, mode, addr, ra, .NONE)
    }
    return
}

write_rng_c256 :: proc(r: ^RNG, mode: MODE, addr, ra, val: u32) {
    emu.error_write(r.name, .NOT_IMPL, mode, addr, ra, val, .NONE)
}

// eof
