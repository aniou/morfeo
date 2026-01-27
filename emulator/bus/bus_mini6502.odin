
package bus

import "core:log"
import "core:fmt"
import "core:prof/spall"

import "lib:emu"

import "emulator:pic"
import "emulator:ram"

make_mini6502 :: proc(name: string) -> ^Bus {
    bus        := new(Bus)
    bus.name    = name

    bus.delete  = delete_mini6502
    bus.read    =   read_mini6502
    bus.write   =  write_mini6502

    return bus
}

delete_mini6502 :: proc(bus: ^Bus) {
    free(bus)
    return
}

read_mini6502 :: proc(bus: ^Bus, mode: MODE, ra: u32) -> (out: u32) {

    //if bus.debug do emu.debug_read(bus.name, mode, ra, ra)

    switch ra {
    case 0x0000 ..= 0xFFFF: out = bus.ram0->read(mode, ra)        // ea == ra here
    case                  : emu.error_read(bus.name, &bus.req, .NOT_IMPL, mode, ra)
    }

    if bus.debug do emu.debug_read(bus.name, mode, ra, ra, out)
    return
}

write_mini6502 :: proc(bus: ^Bus, mode: MODE, ra, val: u32) {

    if bus.debug do emu.debug_write(bus.name, mode, ra, ra, val)

    switch ra {
    case 0x0000 ..= 0xFFFF: bus.ram0->write(mode, ra, val)
    case                  : emu.error_write(bus.name, &bus.req, .NOT_IMPL, mode, ra, val)
    }
}

