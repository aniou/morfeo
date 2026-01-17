
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

    //log.debugf("%s about to read%d from 0x %04X:%04X",
    //            bus.name, mode, u16(ra >> 16), u16(ra & 0x0000_ffff))

    switch ra {
    case 0x00_0000 ..= 0xFF_FFFF: out = bus.ram0->read(mode, ra, ra)        // ea == ra here
    case                        : emu.error_read(bus.name, .NOT_IMPL, mode, ra, ra, .NONE)
    }

    //log.debugf("%s read val %02x from 0x %04X:%04X", bus.name, out, u16(ra >> 16), u16(ra & 0x0000_ffff))

    return
}

write_mini816 :: proc(bus: ^Bus, mode: MODE, ra, val: u32) {
    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    //log.debugf("%s write %08x  to 0x %04X:%04X", bus.name, val, u16(ra >> 16), u16(ra & 0x0000_ffff))

    switch ra {
    case 0x00_0000 ..= 0xFF_FFFF: bus.ram0->write(mode, ra, ra, val)
    case                        : emu.error_write(bus.name, .NOT_IMPL, mode, ra, ra, val, .NONE)
    }
    return
}

