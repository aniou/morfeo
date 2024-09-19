
package bus

import "core:log"
import "core:fmt"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:ram"

a2560k_read8 :: proc(bus: ^Bus, addr: u32) -> (val: u8) {
    //log.debugf("%s read       from 0x %04X:%04X", bus.name, u16(addr >> 16), u16(addr & 0x0000_ffff))
    switch addr {
    case                              :  return a2560k_bus_error(bus, "read", addr)
    }

    return
}

a2560k_write8 :: proc(bus: ^Bus, addr: u32, val: u8) {
    //log.debugf("%s write %02x   to 0x %04X:%04X", bus.name, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    switch addr {
    case                             :  a2560k_bus_error(bus, "write", addr)
    }
}

a2560k_make :: proc(name: string, pic: ^pic.PIC) -> ^Bus {
    b        := new(Bus)
    b.name    = name
    b.pic     = pic

    ebus = b
    return b
}

a2560k_bus_error :: proc(b: ^Bus, op: string, addr: u32) -> u8 {
    log.errorf("%s err %5s    at 0x %04X:%04X - a2560k unknown segment", b.name, op, u16(addr >> 16), u16(addr & 0x0000_ffff))
    return 0
}

a2560k_not_implemented :: proc(addr: u32, name: string) -> u8 {
    log.warnf("%s error      at 0x %04X:%04X - a2560k not implemented", name, u16(addr >> 16), u16(addr & 0x0000_ffff))
    return 0
}
