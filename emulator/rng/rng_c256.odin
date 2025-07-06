package rng

import "core:fmt"
import "core:log"
import "core:math/rand"
import "lib:emu"

BITS :: emu.Bitsize

// a very rudimentary implementation, has nothing with original RNG
// does not support seeding etc.

RNG :: struct {
    name:       string,
    id:         u8,

    read:       proc(^RNG, BITS, u32, u32) -> u32,
    write:      proc(^RNG, BITS, u32, u32,    u32),
    delete:     proc(^RNG),

    seed:       u32,        // in real: u16
}

rng_c256_make :: proc(name: string) -> ^RNG {
    r             := new(RNG)
    r.name         = name
    r.delete       = rng_c256_delete
    r.read         = rng_c256_read
    r.write        = rng_c256_write
    return r
}

rng_c256_read :: proc(r: ^RNG, mode: BITS, base, busaddr: u32) -> (val: u32) {
    addr := busaddr - base
    switch addr {
    case 0: val = u32(rand.int_max(256))
    case 1: val = u32(rand.int_max(256))
    case  : 
        log.warnf("%s: Read  addr %6x is not implemented, 0 returned", r.name, busaddr)
    }
    return
}

rng_c256_write :: proc(r: ^RNG, mode: BITS, base, busaddr, val: u32) {
    log.warnf("%s: wrte addr %6x val %02x not implemented", r.name, busaddr, val)
}

rng_c256_delete :: proc(r: ^RNG) {
    free(r)
}

// eof
