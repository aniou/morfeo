
package bus

import "core:log"
import "core:fmt"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:ram"

import "lib:emu"

import "core:prof/spall"

a2560x_make :: proc(name: string, pic: ^pic.PIC) -> ^Bus {
    d        := new(Bus)
    d.name    = name
    d.pic     = pic
    d.read    = a2560x_read
    d.write   = a2560x_write
    d.delete  = a2560x_delete

    ebus = d
    return d
}

a2560x_delete :: proc(bus: ^Bus) {
    free(bus)
    return
}

a2560x_read :: proc(bus: ^Bus, size: emu.Request_Size, addr: u32) -> (val: u32) {
    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    //log.debugf("%s read       from 0x %04X:%04X", bus.name, u16(addr >> 16), u16(addr & 0x0000_ffff))

    switch addr {
    case 0x00_00_0000 ..= 0x00_3F_FFFF:  val = bus.ram0->read(size, addr)
    case 0x00_80_0000 ..= 0x00_9F_FFFF:  val = bus.gpu1->read(size, addr, addr - 0x00_80_0000, .VRAM0) // XXX VRAMA i VRAMB
    case 0x00_A0_0000 ..= 0x00_BF_FFFF:  emu.not_implemented(#procedure, "vram1", size, addr)  
    case 0x02_00_0000 ..= 0x05_FF_FFFF:  emu.not_implemented(#procedure, "dram0", size, addr)
    case 0xFE_C0_0080 ..= 0xFE_C0_009F:  val =  bus.rtc->read(size, addr, addr - 0xFE_C0_0080)        // XXX unify that
    case 0xFE_C0_0100 ..= 0xFE_C0_011F:  val =  bus.pic->read(size, addr, addr - 0xFE_C0_0100)
    case 0xFE_C0_0220                 :  val =  bus.gpu0.frames   // TIMER 3
    case 0xFE_C0_0224                 :  val =  bus.gpu1.frames   // TIMER 4 
    case 0xFE_C0_0400 ..= 0xFE_C0_040F:  val = bus.ata0->read(size, addr, addr - 0xFE_C0_0400)
    case 0xFE_C0_2060 ..= 0xFE_C0_2068:  val =  bus.ps2->read(size, addr, addr - 0xFE_C0_2060)

    case 0xFE_C4_0000 ..= 0xFE_C4_003C:  val = bus.gpu0->read(size, addr, addr - 0xFE_C4_0000, .MAIN_A)
    case 0xFE_C4_8000 ..= 0xFE_C4_8FFF:  val = bus.gpu0->read(size, addr, addr - 0xFE_C4_8000, .FONT_BANK0)
    case 0xFE_C6_0000 ..= 0xFE_C6_3FFF:  val = bus.gpu0->read(size, addr, addr - 0xFE_C6_0000, .TEXT)
    case 0xFE_C6_8000 ..= 0xFE_C6_BFFF:  val = bus.gpu0->read(size, addr, addr - 0xFE_C6_8000, .TEXT_COLOR)
    case 0xFE_C6_C400 ..= 0xFE_C6_C43F:  val = bus.gpu0->read(size, addr, addr - 0xFE_C6_C400, .TEXT_FG_LUT)
    case 0xFE_C6_C440 ..= 0xFE_C6_C47F:  val = bus.gpu0->read(size, addr, addr - 0xFE_C6_C440, .TEXT_BG_LUT)

    case 0xFE_C8_0000 ..= 0xFE_C8_003C:  val = bus.gpu1->read(size, addr, addr - 0xFE_C8_0000, .MAIN_B)
    case 0xFE_C8_0100 ..= 0xFE_C8_0107:  val = bus.gpu1->read(size, addr, addr - 0xFE_C8_0000, .MAIN_B)
    case 0xFE_C8_2000 ..= 0xFE_C8_3FFF:  val = bus.gpu1->read(size, addr, addr - 0xFE_C8_2000, .LUT)
    case 0xFE_C8_8000 ..= 0xFE_C8_8FFF:  val = bus.gpu1->read(size, addr, addr - 0xFE_C8_8000, .FONT_BANK0)
    case 0xFE_CA_0000 ..= 0xFE_CA_3FFF:  val = bus.gpu1->read(size, addr, addr - 0xFE_CA_0000, .TEXT)
    case 0xFE_CA_8000 ..= 0xFE_CA_BFFF:  val = bus.gpu1->read(size, addr, addr - 0xFE_CA_8000, .TEXT_COLOR)
    case 0xFE_CA_C400 ..= 0xFE_CA_C43F:  val = bus.gpu1->read(size, addr, addr - 0xFE_CA_C400, .TEXT_FG_LUT)
    case 0xFE_CA_C440 ..= 0xFE_CA_C47F:  val = bus.gpu1->read(size, addr, addr - 0xFE_CA_C440, .TEXT_BG_LUT)

    case 0xFF_C0_0000 ..= 0xFF_FF_FFFF:  emu.not_implemented(#procedure, "flash0", size, addr)
    case                              :  a2560x_bus_error(bus, "read", size, addr)
    }

    //log.debugf("%s read%d  %08x from 0x %04X:%04X", bus.name, size, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    return
}

a2560x_write :: proc(bus: ^Bus, size: emu.Request_Size, addr, val: u32) {
    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

    //log.debugf("%s write%d %08x   to 0x %04X:%04X", bus.name, size, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    switch addr {
    case 0x00_00_0000 ..= 0x00_3F_FFFF:  bus.ram0->write(size, addr, val)
    case 0x00_80_0000 ..= 0x00_9F_FFFF:  bus.gpu1->write(size, addr, addr - 0x00_80_0000, val, .VRAM0) // XXX VRAMA i VRAMB
    case 0x00_A0_0000 ..= 0x00_BF_FFFF:  emu.not_implemented(#procedure, "vram1", size, addr)   // 8M in 2M banks?
    case 0x02_00_0000 ..= 0x05_FF_FFFF:  emu.not_implemented(#procedure, "dram0", size, addr)
    case 0xFE_C0_0080 ..= 0xFE_C0_009F:   bus.rtc->write(size, addr, addr - 0xFE_C0_0080, val)        // XXX unify that
    case 0xFE_C0_0100 ..= 0xFE_C0_011F:   bus.pic->write(size, addr, addr - 0xFE_C0_0100, val)

    case 0xFE_C0_0400 ..= 0xFE_C0_040F:  bus.ata0->write(size, addr, addr - 0xFE_C0_0400, val)
    case 0xFE_C0_2060 ..= 0xFE_C0_2068:   bus.ps2->write(size, addr, addr - 0xFE_C0_2060, val)

    case 0xFE_C4_0000 ..= 0xFE_C4_003C:  bus.gpu0->write(size, addr, addr - 0xFE_C4_0000, val, .MAIN_A)
    case 0xFE_C4_8000 ..= 0xFE_C4_8FFF:  bus.gpu0->write(size, addr, addr - 0xFE_C4_8000, val, .FONT_BANK0)
    case 0xFE_C6_0000 ..= 0xFE_C6_3FFF:  bus.gpu0->write(size, addr, addr - 0xFE_C6_0000, val, .TEXT)
    case 0xFE_C6_8000 ..= 0xFE_C6_BFFF:  bus.gpu0->write(size, addr, addr - 0xFE_C6_8000, val, .TEXT_COLOR)
    case 0xFE_C6_C400 ..= 0xFE_C6_C43F:  bus.gpu0->write(size, addr, addr - 0xFE_C6_C400, val, .TEXT_FG_LUT)
    case 0xFE_C6_C440 ..= 0xFE_C6_C47F:  bus.gpu0->write(size, addr, addr - 0xFE_C6_C440, val, .TEXT_BG_LUT)

    case 0xFE_C8_0000 ..= 0xFE_C8_003C:  bus.gpu1->write(size, addr, addr - 0xFE_C8_0000, val, .MAIN_B)
    case 0xFE_C8_0100 ..= 0xFE_C8_0107:  bus.gpu1->write(size, addr, addr - 0xFE_C8_0000, val, .MAIN_B)
    case 0xFE_C8_2000 ..= 0xFE_C8_3FFF:  bus.gpu1->write(size, addr, addr - 0xFE_C8_2000, val, .LUT)
    case 0xFE_C8_8000 ..= 0xFE_C8_8FFF:  bus.gpu1->write(size, addr, addr - 0xFE_C8_8000, val, .FONT_BANK0)
    case 0xFE_CA_0000 ..= 0xFE_CA_3FFF:  bus.gpu1->write(size, addr, addr - 0xFE_CA_0000, val, .TEXT)
    case 0xFE_CA_8000 ..= 0xFE_CA_BFFF:  bus.gpu1->write(size, addr, addr - 0xFE_CA_8000, val, .TEXT_COLOR)
    case 0xFE_CA_C400 ..= 0xFE_CA_C43F:  bus.gpu1->write(size, addr, addr - 0xFE_CA_C400, val, .TEXT_FG_LUT)
    case 0xFE_CA_C440 ..= 0xFE_CA_C47F:  bus.gpu1->write(size, addr, addr - 0xFE_CA_C440, val, .TEXT_BG_LUT)

    case 0xFF_C0_0000 ..= 0xFF_FF_FFFF:  emu.not_implemented(#procedure, "flash0", size, addr)
    case                              :  a2560x_bus_error(bus, "write", size, addr)
    }

    return
}

a2560x_bus_error :: proc(d: ^Bus, op: string, size: emu.Request_Size, addr: u32) {
    log.errorf("%s err %5s%d    at 0x %04X:%04X - a2560x unknown segment", 
                d.name, 
                op, 
                size, 
                u16(addr >> 16), 
                u16(addr & 0x0000_ffff))
    return
}

a2560x_not_implemented :: proc(addr: u32, name: string) {
    log.warnf("%s error      at 0x %04X:%04X - a2560x not implemented", 
                name, 
                u16(addr >> 16), 
                u16(addr & 0x0000_ffff))
    return
}
