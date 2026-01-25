
package bus

// this is an "alternate" bus implementation, where all values
// required by debug/error messages are locate in separate 
// structure (`rec`) 
// it spares us from setting additional parameters do device
// routines, only for occasional messaging and providin context
// as a bonus there is also a field for PC, that is (at least 
// for a 65xxxx) updated at moment of command execution)

// that bus should be eventually a base standard for all 
// machines

import "core:log"
import "core:fmt"
import "core:prof/spall"

import "lib:emu"

import "emulator:pic"
import "emulator:ram"

make_alt816 :: proc(name: string) -> ^Bus {
    bus        := new(Bus)
    bus.name    = name
    bus.req     = emu.BusRequest{}

    bus.delete  = delete_alt816
    bus.read    =   read_alt816
    bus.write   =  write_alt816

    return bus
}

delete_alt816 :: proc(bus: ^Bus) {
    free(bus)
    return
}

read_alt816 :: proc(bus: ^Bus, mode: MODE, ra: u32) -> (out: u32) {
    bus.req.ra = ra

    switch ra {
    case 0x00_0000 ..= 0xFF_FFFF: out = bus.aram0->read(mode, ra)        // ea == ra here
    case                        : emu.error_read(bus.name, &bus.req, .NOT_IMPL, mode, ra)
    }

    if bus.debug do emu.debug_read(bus.name, mode, ra, ra, out)
    return
}

write_alt816 :: proc(bus: ^Bus, mode: MODE, ra, val: u32) {
    bus.req.ra = ra

    if bus.debug do emu.debug_write(bus.name, mode, ra, ra, val)

    switch ra {
    case 0x00_0000 ..= 0xFF_FFFF: bus.aram0->write(mode, ra, val)
    case                        : emu.error_write(bus.name, &bus.req, .NOT_IMPL, mode, ra, val)
    }
}

