
package bus

import "core:log"
import "core:fmt"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:ram"

import "lib:emu"

import "core:prof/spall"

make_simple6502 :: proc(name: string, pic: ^pic.PIC) -> ^Bus {
    d        := new(Bus)
    d.name    = name
    d.pic     = pic
    d.read    = read_simple6502
    d.write   = write_simple6502
    d.delete  = delete_simple6502

    return d
}

delete_simple6502 :: proc(bus: ^Bus) {
    free(bus)
    return
}

read_simple6502   :: proc(bus: ^Bus, size: emu.Bitsize, addr: u32) -> (val: u32) {
    switch addr {
    case 0x0000 ..= 0xFFFF:  val = bus.ram0->read(size, 0x0000, addr)
    case                  :  bus_error_simple6502(bus, "read", size, addr)
    }
    return
}

write_simple6502   :: proc(bus: ^Bus, size: emu.Bitsize, addr, val: u32) {
    switch addr {
    case 0x0000 ..= 0xFFFF:  bus.ram0->write(size, 0x0000, addr, val)
    case                  :  bus_error_simple6502(bus, "write", size, addr)
    }
    return
}

bus_error_simple6502 :: proc(d: ^Bus, op: string, size: emu.Bitsize, addr: u32) {
    log.errorf("%s err %5s%d    at 0x %04X:%04X - simple6502 unknown segment", 
                d.name, 
                op, 
                size, 
                u16(addr >> 16), 
                u16(addr & 0x0000_ffff))
    return
}

not_implemented_simple6502 :: proc(addr: u32, name: string) {
    log.warnf("%s error      at 0x %04X:%04X - simple6502 not implemented", 
                name, 
                u16(addr >> 16), 
                u16(addr & 0x0000_ffff))
    return
}
