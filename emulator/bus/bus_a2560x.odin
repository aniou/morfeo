package bus

import "core:log"
import "core:fmt"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:ram"

import "lib:emu"

import "core:prof/spall"

BUS_A2560X :: struct {
    using bus: ^Bus
}

// XXX - incomplete!
a2560x_make :: proc(name: string, pic: ^pic.PIC) -> ^Bus {
    bus        := new(Bus)
    bus.name    = name
    bus.pic0    = pic
    bus.model   = BUS_A2560X{bus = bus}
    return bus
}

a2560x_delete :: proc(bus: ^Bus) {
    free(bus)
    return
}

// XXX: temporary
a2560x_read8 :: proc(bus: ^BUS_A2560X, ra: u32) -> (out: u32) {
    out = read_a2560x(bus, .mode_8, ra)
    return
}
a2560x_read16 :: proc(bus: ^BUS_A2560X, ra: u32) -> (out: u32) {
    out = read_a2560x(bus, .mode_16be, ra)
    return
}
a2560x_read32 :: proc(bus: ^BUS_A2560X, ra: u32) -> (out: u32) {
    out = read_a2560x(bus, .mode_32be, ra)
    return
}

a2560x_write8 :: proc(bus: ^BUS_A2560X, ra, val: u32) {
    write_a2560x(bus, .mode_8, ra, val)
}
a2560x_write16 :: proc(bus: ^BUS_A2560X, ra, val: u32) {
    write_a2560x(bus, .mode_16be, ra, val)
}
a2560x_write32 :: proc(bus: ^BUS_A2560X, ra, val: u32) {
    write_a2560x(bus, .mode_32be, ra, val)
}


read_a2560x :: proc(bus: ^BUS_A2560X, mode: MODE, ra: u32) -> (out: u32) {
    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer)
    //log.debugf("%s read       from 0x %04X:%04X", bus.name, u16(ra >> 16), u16(ra & 0x0000_ffff))

    switch ra {
    case 0x00_00_0000 ..= 0x00_3F_FFFF:  out =   bus.ram0->read(mode, ra - 0x00_00_0000, ra)
    case 0x00_80_0000 ..= 0x00_9F_FFFF:  out =   bus.gpu1->read(mode, ra - 0x00_80_0000, ra, .VRAM0) // XXX VRAMA and VRAMB
    case 0x00_A0_0000 ..= 0x00_BF_FFFF:  emu.error_read(bus.name, .NOT_IMPL, mode, ra - ra, ra, .NONE)
    case 0x02_00_0000 ..= 0x05_FF_FFFF:  out =   bus.ram1->read(mode, ra - 0x02_00_0000, ra)
    case 0xFE_C0_0080 ..= 0xFE_C0_009F:  out =   bus.rtc0->read(mode, ra - 0xFE_C0_0080, ra)
    case 0xFE_C0_0100 ..= 0xFE_C0_011F:  out =   bus.pic0->read(mode, ra - 0xFE_C0_0100, ra)
    case 0xFE_C0_0200 ..= 0xFE_C0_022F:  out = bus.timer0->read(mode, ra - 0xFE_C0_0200, ra)
    case 0xFE_C0_0400 ..= 0xFE_C0_040F:  out =   bus.ata0->read(mode, ra - 0xFE_C0_0400, ra)
    case 0xFE_C0_2060 ..= 0xFE_C0_2068:  out =   bus.ps20->read(mode, ra - 0xFE_C0_2060, ra)
    case 0xFE_C0_0000 ..= 0xFE_C1_FFFF:  out =   bus.rom0->read(mode, ra - 0xFE_C0_0000, ra)

    case 0xFE_C4_0000 ..= 0xFE_C4_003C:  out =   bus.gpu0->read(mode, ra - 0xFE_C4_0000, ra, .MAIN_A)
    case 0xFE_C4_8000 ..= 0xFE_C4_8FFF:  out =   bus.gpu0->read(mode, ra - 0xFE_C4_8000, ra, .FONT_BANK0)
    case 0xFE_C6_0000 ..= 0xFE_C6_3FFF:  out =   bus.gpu0->read(mode, ra - 0xFE_C6_0000, ra, .TEXT)
    case 0xFE_C6_8000 ..= 0xFE_C6_BFFF:  out =   bus.gpu0->read(mode, ra - 0xFE_C6_8000, ra, .TEXT_COLOR)
    case 0xFE_C6_C400 ..= 0xFE_C6_C43F:  out =   bus.gpu0->read(mode, ra - 0xFE_C6_C400, ra, .TEXT_FG_LUT)
    case 0xFE_C6_C440 ..= 0xFE_C6_C47F:  out =   bus.gpu0->read(mode, ra - 0xFE_C6_C440, ra, .TEXT_BG_LUT)

    case 0xFE_C8_0000 ..= 0xFE_C8_003C:  out =   bus.gpu1->read(mode, ra - 0xFE_C8_0000, ra, .MAIN_B)
    case 0xFE_C8_0100 ..= 0xFE_C8_0107:  out =   bus.gpu1->read(mode, ra - 0xFE_C8_0000, ra, .MAIN_B)
    case 0xFE_C8_2000 ..= 0xFE_C8_3FFF:  out =   bus.gpu1->read(mode, ra - 0xFE_C8_2000, ra, .LUT)
    case 0xFE_C8_8000 ..= 0xFE_C8_8FFF:  out =   bus.gpu1->read(mode, ra - 0xFE_C8_8000, ra, .FONT_BANK0)
    case 0xFE_CA_0000 ..= 0xFE_CA_3FFF:  out =   bus.gpu1->read(mode, ra - 0xFE_CA_0000, ra, .TEXT)
    case 0xFE_CA_8000 ..= 0xFE_CA_BFFF:  out =   bus.gpu1->read(mode, ra - 0xFE_CA_8000, ra, .TEXT_COLOR)
    case 0xFE_CA_C400 ..= 0xFE_CA_C43F:  out =   bus.gpu1->read(mode, ra - 0xFE_CA_C400, ra, .TEXT_FG_LUT)
    case 0xFE_CA_C440 ..= 0xFE_CA_C47F:  out =   bus.gpu1->read(mode, ra - 0xFE_CA_C440, ra, .TEXT_BG_LUT)

    case 0xFF_C0_0000 ..= 0xFF_FF_FFFF:  emu.error_read(bus.name, .NOT_IMPL, mode, ra, ra, .NONE) // FLASH0
    case                              :  emu.error_read(bus.name, .NOT_IMPL, mode, ra, ra, .NONE)
    }

    //log.debugf("%s read%d  %08x from 0x %04X:%04X", bus.name, size, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    return
}

write_a2560x :: proc(bus: ^BUS_A2560X, mode: MODE, ra, val: u32) {
    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer)

    //log.debugf("%s write%d %08x   to 0x %04X:%04X", bus.name, size, val, u16(ra >> 16), u16(ra & 0x0000_ffff))
    switch ra {
    case 0x00_00_0000 ..= 0x00_3F_FFFF:    bus.ram0->write(mode, ra - 0x00_00_0000, ra, val)
    case 0x00_80_0000 ..= 0x00_9F_FFFF:    bus.gpu1->write(mode, ra - 0x00_80_0000, ra, val, .VRAM0) // XXX VRAMA and VRAMB
    case 0x00_A0_0000 ..= 0x00_BF_FFFF:  emu.error_write(bus.name, .NOT_IMPL, mode, ra - 0x00_A0_0000, ra, val, .VRAM1)
    case 0x02_00_0000 ..= 0x05_FF_FFFF:    bus.ram1->write(mode, ra - 0x02_00_0000, ra, val)     // 64MB SDRAM in X/K
    case 0xFE_C0_0080 ..= 0xFE_C0_009F:    bus.rtc0->write(mode, ra - 0xFE_C0_0080, ra, val)
    case 0xFE_C0_0100 ..= 0xFE_C0_011F:    bus.pic0->write(mode, ra - 0xFE_C0_0100, ra, val)

    case 0xFE_C0_0200 ..= 0xFE_C0_022F:  bus.timer0->write(mode, ra - 0xFE_C0_0200, ra, val)
    case 0xFE_C0_0400 ..= 0xFE_C0_040F:    bus.ata0->write(mode, ra - 0xFE_C0_0400, ra, val)
    case 0xFE_C0_2060 ..= 0xFE_C0_2068:    bus.ps20->write(mode, ra - 0xFE_C0_2060, ra, val)
    case 0xFE_C0_0000 ..= 0xFE_C1_FFFF:  emu.error_write(bus.name, .NOT_IMPL, mode, ra - 0xFE_C0_0000, ra, val, .ROM0)
    case 0xFE_C4_0000 ..= 0xFE_C4_003C:    bus.gpu0->write(mode, ra - 0xFE_C4_0000, ra, val, .MAIN_A)
    case 0xFE_C4_8000 ..= 0xFE_C4_8FFF:    bus.gpu0->write(mode, ra - 0xFE_C4_8000, ra, val, .FONT_BANK0)
    case 0xFE_C6_0000 ..= 0xFE_C6_3FFF:    bus.gpu0->write(mode, ra - 0xFE_C6_0000, ra, val, .TEXT)
    case 0xFE_C6_8000 ..= 0xFE_C6_BFFF:    bus.gpu0->write(mode, ra - 0xFE_C6_8000, ra, val, .TEXT_COLOR)
    case 0xFE_C6_C400 ..= 0xFE_C6_C43F:    bus.gpu0->write(mode, ra - 0xFE_C6_C400, ra, val, .TEXT_FG_LUT)
    case 0xFE_C6_C440 ..= 0xFE_C6_C47F:    bus.gpu0->write(mode, ra - 0xFE_C6_C440, ra, val, .TEXT_BG_LUT)

    case 0xFE_C8_0000 ..= 0xFE_C8_003C:    bus.gpu1->write(mode, ra - 0xFE_C8_0000, ra, val, .MAIN_B)
    case 0xFE_C8_0100 ..= 0xFE_C8_0107:    bus.gpu1->write(mode, ra - 0xFE_C8_0000, ra, val, .MAIN_B)
    case 0xFE_C8_2000 ..= 0xFE_C8_3FFF:    bus.gpu1->write(mode, ra - 0xFE_C8_2000, ra, val, .LUT)
    case 0xFE_C8_8000 ..= 0xFE_C8_8FFF:    bus.gpu1->write(mode, ra - 0xFE_C8_8000, ra, val, .FONT_BANK0)
    case 0xFE_CA_0000 ..= 0xFE_CA_3FFF:    bus.gpu1->write(mode, ra - 0xFE_CA_0000, ra, val, .TEXT)
    case 0xFE_CA_8000 ..= 0xFE_CA_BFFF:    bus.gpu1->write(mode, ra - 0xFE_CA_8000, ra, val, .TEXT_COLOR)
    case 0xFE_CA_C400 ..= 0xFE_CA_C43F:    bus.gpu1->write(mode, ra - 0xFE_CA_C400, ra, val, .TEXT_FG_LUT)
    case 0xFE_CA_C440 ..= 0xFE_CA_C47F:    bus.gpu1->write(mode, ra - 0xFE_CA_C440, ra, val, .TEXT_BG_LUT)
    case 0xFF_C0_0000 ..= 0xFF_FF_FFFF:  emu.error_write(bus.name, .NOT_IMPL, mode, ra - 0xFF_C0_0000, ra, val, .FLASH0)
    case                              :  emu.error_write(bus.name, .NOT_IMPL, mode, ra, ra, val, .NONE)
    }

    return
}

