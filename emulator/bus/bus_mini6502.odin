
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
    switch ra {
    case 0x0000 ..= 0xFFFF: out = bus.ram0->read(mode, ra, ra)        // ea == ra here
    case                  : emu.error_read(bus.name, .NOT_IMPL, mode, ra, ra, .NONE)                                  
    }
    return
}

write_mini6502 :: proc(bus: ^Bus, mode: MODE, ra, val: u32) {
    switch ra {
    case 0x0000 ..= 0xFFFF: bus.ram0->write(mode, ra, ra, val)
    case                  : emu.error_write(bus.name, .NOT_IMPL, mode, ra, ra, val, .NONE)
    }
}

