package bus

import "core:log"
import "core:fmt"
import "emulator:gpu"
import "emulator:intu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:ram"

import "lib:emu"

import "core:prof/spall"


BUS_C256 :: struct {
    using bus:	^Bus,
	vdma:		DMA,
	sdma:		DMA,
}



c256_make :: proc(name: string, pic: ^pic.PIC, type: emu.Type) -> ^Bus {
    d        := new(Bus)
    d.name    = name
    d.type    = type
    d.pic     = pic
    d.delete  = c256_delete
    d.debug   = false

    switch type {
    case .C256U:
        d.read    = c256_read
        d.write   = c256_write
    case .C256UPLUS:
        d.read    = c256_read
        d.write   = c256_write
    case .C256FMX:
        d.read    = c256fmx_read
        d.write   = c256fmx_write
    }

	b            := BUS_C256{sdma = DMA{}, vdma = DMA{}}
    d.model       = b
    ebus          = d
    return d
}

c256_delete :: proc(bus: ^Bus) {
    free(bus)
    return
}

// FMX/U/U+ memory model
//
// $00:0000 - $1f:ffff - 2MB RAM
//   $00:100 - $00:01ff - math core, IRQ CTRL, Timers, SDMA
// $20:0000 - $3f:ffff - 2MB RAM on FMX revB and U+
// $40:0000 - $ae:ffff - empty space (for example: extenps2n card)
// $af:0000 - $af:9fff - IO registers (mostly VICKY)
//   $af:0800 - $af:080f - RTC
//   $af:1000 - $af:13ff - GABE

// $af:1F40 - $af:1F7F - VICKY - Text Foreground Look-Up Table 
// $af:1F80 - $af:1FFF - VICKY - Text Background Look-Up Table 
// $af:8000 - $af:87FF - VICKY - FONT BANK0 (no bank1 at all?)
// $af:8800 - $af:9fff - VICKY - reserved, unused
// $af:a000 - $af:bfff - VICKY - TEXT  RAM
// $af:c000 - $af:dfff - VICKY - COLOR RAM
// $af:e000 - $af:ffff - IO registers (Trinity, Unity, GABE, SDCARD)
// $b0:0000 - $ef:ffff - VIDEO RAM
// $f0:0000 - $f7:ffff - 512KB System Flash
// $f8:0000 - $ff:ffff - 512KB User Flash (if populated)

c256fmx_read :: proc(bus: ^Bus, size: emu.Request_Size, addr: u32) -> (val: u32) {
    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    //log.debugf("%s read     from 0x %04X:%04X", bus.name, u16(addr >> 16), u16(addr & 0x0000_ffff))

    switch addr {
    //case 0x00_00_0000 ..= 0x00_00_00FF:  val = bus.ram0->read(size, addr                             )
    //case 0x00_00_0100 ..= 0x00_00_01FF:  emu.read_not_implemented(#procedure, "xxxxxx", size, addr              )
    case 0x00_00_0100 ..= 0x00_00_012B:  val = bus.intu->read(size, addr, addr - 0x00_00_0100)
    case 0x00_00_0140 ..= 0x00_00_014F:  val = bus.pic->read(size, addr, addr)
    case 0x00_00_0000 ..= 0x00_00_01FF:  val = bus.ram0->read(size, addr                             )
    case 0x00_00_0200 ..= 0x00_1F_FFFF:  val = bus.ram0->read(size, addr                             )
    case 0x00_20_0000 ..= 0x00_4F_FFFF:  val = bus.ram0->read(size, addr             )
    case 0x00_AF_0400 ..= 0x00_AF_040F:  val = c256_dma_read(bus, size, addr)
    case 0x00_AF_0420 ..= 0x00_AF_0430:  val = c256_dma_read(bus, size, addr)
    case 0x00_AF_0000 ..= 0x00_AF_07FF:  val = bus.gpu0->read(size, addr, addr - 0x00_AF_0000, .MAIN_A     )
    case 0x00_AF_1060 ..= 0x00_AF_1064:  val = bus.ps2->read (size, addr, addr - 0x00_AF_1060)

    case 0x00_AF_1F40 ..= 0x00_AF_1F7F:  val = bus.gpu0->read(size, addr, addr - 0x00_AF_1F40, .TEXT_FG_LUT)
    case 0x00_AF_1F80 ..= 0x00_AF_1FFF:  val = bus.gpu0->read(size, addr, addr - 0x00_AF_1F80, .TEXT_BG_LUT)
    case 0x00_AF_2000 ..= 0x00_AF_3FFF:  val = bus.gpu0->read(size, addr, addr - 0x00_AF_1F80, .LUT        )
    case 0x00_AF_8000 ..= 0x00_AF_87FF:  val = bus.gpu0->read(size, addr, addr - 0x00_AF_8000, .FONT_BANK0 )
    case 0x00_AF_8800 ..= 0x00_AF_9FFF:  emu.read_not_implemented(#procedure, "empty0", size, addr              )
    case 0x00_AF_A000 ..= 0x00_AF_BFFF:  val = bus.gpu0->read(size, addr, addr - 0x00_AF_A000, .TEXT       )
    case 0x00_AF_C000 ..= 0x00_AF_DFFF:  val = bus.gpu0->read(size, addr, addr - 0x00_AF_C000, .TEXT_COLOR )
    case 0x00_AF_E400 ..= 0x00_AF_E41f:  val = 0 // SID0
    case 0x00_AF_E80E                 :  val = 0x03 // boot BASIC
    case 0x00_AF_E887                 :  val = 0x00 // simulate FMX id
    case 0x00_AF_E000 ..= 0x00_AF_FFFF:  emu.read_not_implemented(#procedure, "io", size, addr                  )
    case 0x00_B0_0000 ..= 0x00_EF_FFFF:  val = bus.gpu0->read(size, addr, addr - 0x00_B0_0000, .VRAM0      )
    case 0x00_F0_0000 ..= 0x00_F7_FFFF:  emu.read_not_implemented(#procedure, "flash0", size, addr              )
    case 0x00_F8_0000 ..= 0x00_FF_FFFF:  emu.read_not_implemented(#procedure, "flash1", size, addr              )
    case                              :  c256_bus_error(bus, "read", size, addr)
    }

    if bus.debug {
        log.debugf("%s read%d  %08x from 0x %04X:%04X", bus.name, size, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    }
    return
}

// XXX: todo - add base address for ram?
c256fmx_write :: proc(bus: ^Bus, size: emu.Request_Size, addr, val: u32) {
    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

    if bus.debug {
        log.debugf("%s write%d %08x   to 0x %04X:%04X", bus.name, size, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    }
    /*
    switch addr {
    case 0x00_00_0010: log.debugf("%s write%d %08x   to 0x %04X:%04X", bus.name, size, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    case 0x00_00_0011: log.debugf("%s write%d %08x   to 0x %04X:%04X", bus.name, size, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    case 0x00_00_0012: log.debugf("%s write%d %08x   to 0x %04X:%04X", bus.name, size, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    case: { }
    }
    */

    switch addr {
    //case 0x00_00_0000 ..= 0x00_00_00FF:  bus.ram0->write(size, addr, val                        )
    //case 0x00_00_0100 ..= 0x00_00_01FF:  emu.write_not_implemented(#procedure, "xxxxxx", size, addr, val               )
    case 0x00_00_0100 ..= 0x00_00_012B:  bus.intu->write(size, addr, addr - 0x00_00_0100, val)
    case 0x00_00_0140 ..= 0x00_00_014F:  bus.pic->write(size, addr, addr, val)
    case 0x00_00_0000 ..= 0x00_00_01FF:  bus.ram0->write(size, addr, val                        )
    case 0x00_00_0200 ..= 0x00_1F_FFFF:  bus.ram0->write(size, addr, val                        )
    case 0x00_20_0000 ..= 0x00_4F_FFFF:  bus.ram0->write(size, addr,  val         )          // only valid for 4MB models
    case 0x00_AF_0400 ..= 0x00_AF_040F:  c256_dma_write(bus, size, addr, val)
    case 0x00_AF_0420 ..= 0x00_AF_0430:  c256_dma_write(bus, size, addr, val)
    case 0x00_AF_0000 ..= 0x00_AF_07FF:  bus.gpu0->write(size, addr, addr - 0x00_AF_0000, val, .MAIN_A     )
    case 0x00_AF_1060 ..= 0x00_AF_1064:  bus.ps2->write (size, addr, addr - 0x00_AF_1060, val)
    case 0x00_AF_1F40 ..= 0x00_AF_1F7F:  bus.gpu0->write(size, addr, addr - 0x00_AF_1F40, val, .TEXT_FG_LUT)
    case 0x00_AF_1F80 ..= 0x00_AF_1FFF:  bus.gpu0->write(size, addr, addr - 0x00_AF_1F80, val, .TEXT_BG_LUT)
    case 0x00_AF_2000 ..= 0x00_AF_3FFF:  bus.gpu0->write(size, addr, addr - 0x00_AF_2000, val, .LUT        )
    case 0x00_AF_8000 ..= 0x00_AF_87FF:  bus.gpu0->write(size, addr, addr - 0x00_AF_8000, val, .FONT_BANK0 )
    case 0x00_AF_8800 ..= 0x00_AF_9FFF:  emu.write_not_implemented(#procedure, "empty0", size, addr, val               )
    case 0x00_AF_A000 ..= 0x00_AF_BFFF:  bus.gpu0->write(size, addr, addr - 0x00_AF_A000, val, .TEXT       )
    case 0x00_AF_C000 ..= 0x00_AF_DFFF:  bus.gpu0->write(size, addr, addr - 0x00_AF_C000, val, .TEXT_COLOR )
    case 0x00_AF_E400 ..= 0x00_AF_E41F:  // SID0
    case 0x00_AF_E000 ..= 0x00_AF_FFFF:  emu.write_not_implemented(#procedure, "io", size, addr, val                   )
    case 0x00_B0_0000 ..= 0x00_EF_FFFF:  bus.gpu0->write(size, addr, addr - 0x00_B0_0000, val, .VRAM0      )
    case 0x00_F0_0000 ..= 0x00_F7_FFFF:  emu.write_not_implemented(#procedure, "flash0", size, addr, val               )
    case 0x00_F8_0000 ..= 0x00_FF_FFFF:  emu.write_not_implemented(#procedure, "flash1", size, addr, val               )
    case                              :  c256_bus_error(bus, "write", size, addr)
    }

    return
}

c256_read :: proc(bus: ^Bus, size: emu.Request_Size, addr: u32) -> (val: u32) {
    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    //log.debugf("%s read       from 0x %04X:%04X", bus.name, u16(addr >> 16), u16(addr & 0x0000_ffff))

    switch addr {
    //case 0x00_00_0000 ..= 0x00_00_00FF:  val = bus.ram0->read(size, addr                             )
    //case 0x00_00_0100 ..= 0x00_00_01FF:  emu.read_not_implemented(#procedure, "xxxxxx", size, addr              )
    case 0x00_00_0140 ..= 0x00_00_014F:  val = bus.pic->read(size, addr, addr)
    case 0x00_00_0000 ..= 0x00_00_01FF:  val = bus.ram0->read(size, addr                             )
    case 0x00_00_0200 ..= 0x00_1F_FFFF:  val = bus.ram0->read(size, addr                             )
    case 0x00_20_0000 ..= 0x00_4F_FFFF:  val = bus.ram0->read(size, addr             )
    case 0x00_AF_0400 ..= 0x00_AF_040F:  val = c256_dma_read(bus, size, addr)
    case 0x00_AF_0420 ..= 0x00_AF_0430:  val = c256_dma_read(bus, size, addr)
    case 0x00_AF_0000 ..= 0x00_AF_07FF:  val = bus.gpu0->read(size, addr, addr - 0x00_AF_0000, .MAIN_A     )
    case 0x00_AF_1803 ..= 0x00_AF_1807:  val = bus.ps2->read (size, addr, addr - 0x00_AF_1800)
    case 0x00_AF_1F40 ..= 0x00_AF_1F7F:  val = bus.gpu0->read(size, addr, addr - 0x00_AF_1F40, .TEXT_FG_LUT)
    case 0x00_AF_1F80 ..= 0x00_AF_1FFF:  val = bus.gpu0->read(size, addr, addr - 0x00_AF_1F80, .TEXT_BG_LUT)
    case 0x00_AF_2000 ..= 0x00_AF_3FFF:  val = bus.gpu0->read(size, addr, addr - 0x00_AF_1F80, .LUT        )
    case 0x00_AF_8000 ..= 0x00_AF_87FF:  val = bus.gpu0->read(size, addr, addr - 0x00_AF_8000, .FONT_BANK0 )
    case 0x00_AF_8800 ..= 0x00_AF_9FFF:  emu.read_not_implemented(#procedure, "empty0", size, addr              )
    case 0x00_AF_A000 ..= 0x00_AF_BFFF:  val = bus.gpu0->read(size, addr, addr - 0x00_AF_A000, .TEXT       )
    case 0x00_AF_C000 ..= 0x00_AF_DFFF:  val = bus.gpu0->read(size, addr, addr - 0x00_AF_C000, .TEXT_COLOR )
    case 0x00_AF_E400 ..= 0x00_AF_E41f:  val = 0 // SID0
    case 0x00_AF_E887                 :  val = 0x05 // simulate U+ id
    case 0x00_AF_E000 ..= 0x00_AF_FFFF:  emu.read_not_implemented(#procedure, "io", size, addr                  )
    case 0x00_B0_0000 ..= 0x00_CF_FFFF:  val = bus.gpu0->read(size, addr, addr - 0x00_B0_0000, .VRAM0      )
    case 0x00_F0_0000 ..= 0x00_F7_FFFF:  emu.read_not_implemented(#procedure, "flash0", size, addr              )
    case 0x00_F8_0000 ..= 0x00_FF_FFFF:  emu.read_not_implemented(#procedure, "flash1", size, addr              )
    case                              :  c256_bus_error(bus, "read", size, addr)
    }

    //log.debugf("%s read%d  %08x from 0x %04X:%04X", bus.name, size, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    return
}

// XXX: todo - add base address for ra,?
c256_write :: proc(bus: ^Bus, size: emu.Request_Size, addr, val: u32) {
    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

    //log.debugf("%s write%d %08x   to 0x %04X:%04X", bus.name, size, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    switch addr {
    //case 0x00_00_0000 ..= 0x00_00_00FF:  bus.ram0->write(size, addr, val                        )
    //case 0x00_00_0100 ..= 0x00_00_01FF:  emu.write_not_implemented(#procedure, "xxxxxx", size, addr, val               )
    case 0x00_00_0140 ..= 0x00_00_014F:  bus.pic->write(size, addr, addr, val)
    case 0x00_00_0000 ..= 0x00_00_01FF:  bus.ram0->write(size, addr, val                        )
    case 0x00_00_0200 ..= 0x00_1F_FFFF:  bus.ram0->write(size, addr, val                        )
    case 0x00_20_0000 ..= 0x00_4F_FFFF:  bus.ram0->write(size, addr,  val         )          // only valid for 4MB models
    case 0x00_AF_0400 ..= 0x00_AF_040F:  c256_dma_write(bus, size, addr, val)
    case 0x00_AF_0420 ..= 0x00_AF_0430:  c256_dma_write(bus, size, addr, val)
    case 0x00_AF_0000 ..= 0x00_AF_07FF:  bus.gpu0->write(size, addr, addr - 0x00_AF_0000, val, .MAIN_A     )
    case 0x00_AF_1803 ..= 0x00_AF_1807:  bus.ps2->write (size, addr, addr - 0x00_AF_1800, val)
    case 0x00_AF_1F40 ..= 0x00_AF_1F7F:  bus.gpu0->write(size, addr, addr - 0x00_AF_1F40, val, .TEXT_FG_LUT)
    case 0x00_AF_1F80 ..= 0x00_AF_1FFF:  bus.gpu0->write(size, addr, addr - 0x00_AF_1F80, val, .TEXT_BG_LUT)
    case 0x00_AF_2000 ..= 0x00_AF_3FFF:  bus.gpu0->write(size, addr, addr - 0x00_AF_2000, val, .LUT        )
    case 0x00_AF_8000 ..= 0x00_AF_87FF:  bus.gpu0->write(size, addr, addr - 0x00_AF_8000, val, .FONT_BANK0 )
    case 0x00_AF_8800 ..= 0x00_AF_9FFF:  emu.write_not_implemented(#procedure, "empty0", size, addr, val               )
    case 0x00_AF_A000 ..= 0x00_AF_BFFF:  bus.gpu0->write(size, addr, addr - 0x00_AF_A000, val, .TEXT       )
    case 0x00_AF_C000 ..= 0x00_AF_DFFF:  bus.gpu0->write(size, addr, addr - 0x00_AF_C000, val, .TEXT_COLOR )
    case 0x00_AF_E400 ..= 0x00_AF_E41F:  // SID0
    case 0x00_AF_E000 ..= 0x00_AF_FFFF:  emu.write_not_implemented(#procedure, "io", size, addr, val                   )
    case 0x00_B0_0000 ..= 0x00_CF_FFFF:  bus.gpu0->write(size, addr, addr - 0x00_B0_0000, val, .VRAM0      )
    case 0x00_F0_0000 ..= 0x00_F7_FFFF:  emu.write_not_implemented(#procedure, "flash0", size, addr, val               )
    case 0x00_F8_0000 ..= 0x00_FF_FFFF:  emu.write_not_implemented(#procedure, "flash1", size, addr, val               )
    case                              :  c256_bus_error(bus, "write", size, addr)
    }

    return
}

c256_bus_error :: proc(d: ^Bus, op: string, size: emu.Request_Size, addr: u32) {
    log.errorf("%s err %5s%d    at 0x %04X:%04X - c256 unknown segment", 
                d.name, 
                op, 
                size, 
                u16(addr >> 16), 
                u16(addr & 0x0000_ffff))
    return
}

// workaround for compile-time problems
c256dummy_read :: proc(bus: ^Bus, size: emu.Request_Size, addr: u32) -> (val: u32) {
    emu.read_not_implemented(#procedure, "ANY", size, addr)
    return
}

c256dummy_write :: proc(bus: ^Bus, size: emu.Request_Size, addr, val: u32) {
    emu.write_not_implemented(#procedure, "ANY", size, addr, val)
    return
}

