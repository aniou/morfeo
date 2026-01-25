
package bus

import "core:log"
import "core:fmt"
import "core:prof/spall"

import "lib:emu"

import "emulator:pic"
import "emulator:ram"

make_mini816 :: proc(name: string) -> ^Bus {
    bus        := new(Bus)
    bus.name    = name

    bus.delete  = delete_mini816
    bus.read    =   read_mini816
    bus.write   =  write_mini816

    return bus
}

delete_mini816 :: proc(bus: ^Bus) {
    free(bus)
    return
}

read_mini816 :: proc(bus: ^Bus, mode: MODE, ra: u32) -> (out: u32) {

    //if bus.debug do emu.debug_read(bus.name, mode, ra, ra)

    switch ra {
    case 0x00_0000 ..= 0xFF_FFFF: out = bus.ram0->read(mode, ra, ra)        // ea == ra here
    case                        : emu.error_read(bus.name, &bus.req, .NOT_IMPL, mode, ra)
    }

    if bus.debug do emu.debug_read(bus.name, mode, ra, ra, out)
    return
}

write_mini816 :: proc(bus: ^Bus, mode: MODE, ra, val: u32) {

    if bus.debug do emu.debug_write(bus.name, mode, ra, ra, val)

    switch ra {
    case 0x00_0000 ..= 0xFF_FFFF: bus.ram0->write(mode, ra, ra, val)
    case                        : emu.error_write(bus.name, &bus.req, .NOT_IMPL, mode, ra, val)
    }
}

