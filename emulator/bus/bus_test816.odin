
package bus

import "core:log"
import "core:fmt"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:ram"

import "lib:emu"

import "core:prof/spall"

test816_make :: proc(name: string, pic: ^pic.PIC) -> ^Bus {
    d        := new(Bus)
    d.name    = name
    d.pic0    = pic
    d.read    = test816_read
    d.write   = test816_write
    d.delete  = test816_delete

    return d
}

test816_delete :: proc(bus: ^Bus) {
    free(bus)
    return
}

test816_read :: proc(bus: ^Bus, size: emu.Bitsize, addr: u32) -> (val: u32) {
    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    //log.debugf("%s read       from 0x %04X:%04X", bus.name, u16(addr >> 16), u16(addr & 0x0000_ffff))
    switch addr {
    case 0x00_0000 ..= 0xFF_FFFF:  val = bus.ram0->read(size, 0x00_0000, addr)
    case                              :  test816_bus_error(bus, "read", size, addr)
    }
    return
}

test816_write :: proc(bus: ^Bus, size: emu.Bitsize, addr, val: u32) {
    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    //log.debugf("%s write%d %08x   to 0x %04X:%04X", bus.name, size, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    switch addr {
    case 0x00_0000 ..= 0xFF_FFFF:  bus.ram0->write(size, 0x00_0000, addr, val)
    case                              :  test816_bus_error(bus, "write", size, addr)
    }
    return
}

test816_bus_error :: proc(d: ^Bus, op: string, size: emu.Bitsize, addr: u32) {
    log.errorf("%s err %5s%d    at 0x %04X:%04X - test816 unknown segment", 
                d.name, 
                op, 
                size, 
                u16(addr >> 16), 
                u16(addr & 0x0000_ffff))
    return
}

test816_not_implemented :: proc(addr: u32, name: string) {
    log.warnf("%s error      at 0x %04X:%04X - test816 not implemented", 
                name, 
                u16(addr >> 16), 
                u16(addr & 0x0000_ffff))
    return
}
