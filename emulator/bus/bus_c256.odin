package bus

import "core:log"
import "core:fmt"
import "emulator:gpu"
import "emulator:inu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:ram"
import "emulator:timer"

import "lib:emu"

import "core:prof/spall"

when        emu.TARGET == "c256fmx" { PLATFORM_ID :: 0x00 
                                      SRAM_END    :: 0x3F_FFFF
                                      VRAM_END    :: 0xEF_FFFF 
                                      PS2_START   :: 0x00_AF_1060
                                      PS2_END     :: 0x00_AF_1064 } 
else when   emu.TARGET == "c256u"   { PLATFORM_ID :: 0x01 
                                      SRAM_END    :: 0x1F_FFFF
                                      VRAM_END    :: 0xCF_FFFF 
                                      PS2_START   :: 0x00_AF_1803
                                      PS2_END     :: 0x00_AF_1807 }
else when   emu.TARGET == "c256u+"  { PLATFORM_ID :: 0x05 
                                      SRAM_END    :: 0x3F_FFFF
                                      VRAM_END    :: 0xCF_FFFF 
                                      PS2_START   :: 0x00_AF_1803
                                      PS2_END     :: 0x00_AF_1807 }
else                                { PLATFORM_ID :: 0xFF             // silly workaround for compiler deficiencies
                                      SRAM_END    :: 0x01 
                                      VRAM_END    :: 0x02
                                      PS2_START   :: 0x03
                                      PS2_END     :: 0x04 }

BUS_C256 :: struct {
    using bus: ^Bus,
    vdma:       DMA,
    sdma:       DMA,
    sys_stat:   u32,   // GABE_SYS_STAT
}

c256_make :: proc(name: string, pic: ^pic.PIC, config: ^emu.Config) -> ^Bus {
    d         := new(Bus)
    d.name     = name
    d.pic0     = pic
    d.delete   = c256_delete
    d.debug    = false
    d.read     = c256_read
    d.write    = c256_write
    d.dip_boot = (transmute(u32)config.dipoff & 0b1000_0011)       // only boot and hdd switches here
    d.dip_user = (transmute(u32)config.dipoff & 0b0001_1100) >> 2  // user: 3-5

    b            := BUS_C256{sdma = DMA{}, vdma = DMA{}}
    b.sys_stat    = PLATFORM_ID | 0x10 // 0x10 for expansion card present - XXX - parametrize that

    d.model       = b
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

c256_read :: proc(bus: ^Bus, size: BITS, addr: u32) -> (val: u32) {
    b  := &bus.model.(BUS_C256) // silly workaround

    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    //log.debugf("%s read     from 0x %04X:%04X", bus.name, u16(addr >> 16), u16(addr & 0x0000_ffff))

    switch addr {
    case 0x00_0100 ..= 0x00_012B:  val =   bus.inu0->read(size, 0x00_0100, addr)
    case 0x00_0140 ..= 0x00_014F:  val =   bus.pic0->read(size, 0x00_0140, addr)
    case 0x00_0160 ..= 0x00_0167:  val = bus.timer0->read(size, 0x00_0160, addr)
    case 0x00_0168 ..= 0x00_016F:  val = bus.timer1->read(size, 0x00_0168, addr)
    case 0x00_0170 ..= 0x00_0177:  val = bus.timer2->read(size, 0x00_0170, addr)
    case 0x00_0000 ..= SRAM_END :  val =   bus.ram0->read(size, 0x00_0000, addr)  // 2 or 4 MB
    case PS2_START ..= PS2_END  :  val =   bus.ps20->read(size, PS2_START, addr)  // AF_1803-7 or AF_1060-4

    case 0xAE_0000 ..= 0xAE_001F:  val =   bus.gpu1->read(size, 0xAE_0000, addr, .ID_CARD    )
    case 0xAE_1000 ..= 0xAE_17FF:  val =   bus.gpu1->read(size, 0xAE_1000, addr, .FONT_BANK0 )
    case 0xAE_1B00 ..= 0xAE_1B3F:  val =   bus.gpu1->read(size, 0xAE_1B00, addr, .TEXT_FG_LUT)
    case 0xAE_1B40 ..= 0xAE_1B7F:  val =   bus.gpu1->read(size, 0xAE_1B40, addr, .TEXT_BG_LUT)
    case 0xAE_1E00 ..= 0xAE_1E1F:  val =   bus.gpu1->read(size, 0xAE_1E00, addr, .MAIN       )
    case 0xAE_2000 ..= 0xAE_3FFF:  val =   bus.gpu1->read(size, 0xAE_2000, addr, .TEXT       )
    case 0xAE_4000 ..= 0xAE_5FFF:  val =   bus.gpu1->read(size, 0xAE_4000, addr, .TEXT_COLOR )

    case 0xAF_0200 ..= 0xAF_022F:  val =   bus.gpu0->read(size, 0xAF_0200, addr, .TILEMAP    )
    case 0xAF_0280 ..= 0xAF_029F:  val =   bus.gpu0->read(size, 0xAF_0280, addr, .TILESET    )
    case 0xAF_0400 ..= 0xAF_040F:  val =    c256_dma_read(bus, size, addr)
    case 0xAF_0420 ..= 0xAF_0430:  val =    c256_dma_read(bus, size, addr)
    case 0xAF_0500 ..= 0xAF_05FF:  val =   bus.gpu0->read(size, 0xAF_0500, addr, .MOUSEPTR0  )
    case 0xAF_0600 ..= 0xAF_06FF:  val =   bus.gpu0->read(size, 0xAF_0600, addr, .MOUSEPTR1  )
    case 0xAF_0000 ..= 0xAF_07FF:  val =   bus.gpu0->read(size, 0xAF_0000, addr, .MAIN_A     )
    case 0xAF_1F40 ..= 0xAF_1F7F:  val =   bus.gpu0->read(size, 0xAF_1F40, addr, .TEXT_FG_LUT)
    case 0xAF_1F80 ..= 0xAF_1FFF:  val =   bus.gpu0->read(size, 0xAF_1F80, addr, .TEXT_BG_LUT)
    case 0xAF_2000 ..= 0xAF_3FFF:  val =   bus.gpu0->read(size, 0xAF_1F80, addr, .LUT        )
    case 0xAF_8000 ..= 0xAF_87FF:  val =   bus.gpu0->read(size, 0xAF_8000, addr, .FONT_BANK0 )
    case 0xAF_A000 ..= 0xAF_BFFF:  val =   bus.gpu0->read(size, 0xAF_A000, addr, .TEXT       )
    case 0xAF_C000 ..= 0xAF_DFFF:  val =   bus.gpu0->read(size, 0xAF_C000, addr, .TEXT_COLOR )
    case 0xAF_E400 ..= 0xAF_E41f:  val =   0    // SID0 - silence it for a while
    case 0xAF_E80D              :  val =   bus.dip_user
    case 0xAF_E80E              :  val =   bus.dip_boot
    case 0xAF_E830 ..= 0xAF_E839:  val =   bus.ata0->read(size, 0xAF_E830, addr)
    case 0xAF_E887              :  val =   b.sys_stat
    case 0xAF_E000 ..= 0xAF_FFFF:  emu.read_not_implemented(#procedure, "io",     size, addr)
    case 0xB0_0000 ..= VRAM_END :  val =   bus.gpu0->read(size, 0xB0_0000, addr, .VRAM0      ) // 2 or 4MB
    case 0xF0_0000 ..= 0xF7_FFFF:  emu.read_not_implemented(#procedure, "flash0", size, addr)
    case 0xF8_0000 ..= 0xFF_FFFF:  emu.read_not_implemented(#procedure, "flash1", size, addr)
    case                        :  c256_bus_error(bus, "read", size, addr)
    }

    if bus.debug {
        log.debugf("%s read%d  %08x from 0x %04X:%04X", bus.name, size, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    }
    return
}

c256_write :: proc(bus: ^Bus, size: BITS, addr, val: u32) {
    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
    if bus.debug {
        log.debugf("%s write%d %08x   to 0x %04X:%04X", bus.name, size, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    }

    switch addr {
    case 0x00_0100 ..= 0x00_012B:    bus.inu0->write(size, 0x00_0100, addr, val)
    case 0x00_0140 ..= 0x00_014F:    bus.pic0->write(size, 0x00_0140, addr, val)
    case 0x00_0160 ..= 0x00_0167:  bus.timer0->write(size, 0x00_0160, addr, val)
    case 0x00_0168 ..= 0x00_016F:  bus.timer1->write(size, 0x00_0168, addr, val)
    case 0x00_0170 ..= 0x00_0177:  bus.timer2->write(size, 0x00_0170, addr, val)
    case 0x00_0000 ..= SRAM_END :    bus.ram0->write(size, 0x00_0000, addr, val)
    case PS2_START ..= PS2_END  :    bus.ps20->write(size, PS2_START, addr, val)

    case 0xAE_1000 ..= 0xAE_17FF:    bus.gpu1->write(size, 0xAE_1000, addr, val, .FONT_BANK0 )
    case 0xAE_1B00 ..= 0xAE_1B3F:    bus.gpu1->write(size, 0xAE_1B00, addr, val, .TEXT_FG_LUT)
    case 0xAE_1B40 ..= 0xAE_1B7F:    bus.gpu1->write(size, 0xAE_1B40, addr, val, .TEXT_BG_LUT)
    case 0xAE_1E00 ..= 0xAE_1E1F:    bus.gpu1->write(size, 0xAE_1E00, addr, val, .MAIN       )
    case 0xAE_2000 ..= 0xAE_3FFF:    bus.gpu1->write(size, 0xAE_2000, addr, val, .TEXT       )
    case 0xAE_4000 ..= 0xAE_5FFF:    bus.gpu1->write(size, 0xAE_4000, addr, val, .TEXT_COLOR )

    case 0xAF_0200 ..= 0xAF_022F:    bus.gpu0->write(size, 0xAF_0200, addr, val, .TILEMAP    )
    case 0xAF_0280 ..= 0xAF_029F:    bus.gpu0->write(size, 0xAF_0280, addr, val, .TILESET    )
    case 0xAF_0400 ..= 0xAF_040F:    c256_dma_write(bus, size, addr, val)
    case 0xAF_0420 ..= 0xAF_0430:    c256_dma_write(bus, size, addr, val)
    case 0xAF_0500 ..= 0xAF_05FF:    bus.gpu0->write(size, 0xAF_0500, addr, val, .MOUSEPTR0  )
    case 0xAF_0600 ..= 0xAF_06FF:    bus.gpu0->write(size, 0xAF_0600, addr, val, .MOUSEPTR1  )
    case 0xAF_0000 ..= 0xAF_07FF:    bus.gpu0->write(size, 0xAF_0000, addr, val, .MAIN_A     )
    case 0xAF_1F40 ..= 0xAF_1F7F:    bus.gpu0->write(size, 0xAF_1F40, addr, val, .TEXT_FG_LUT)
    case 0xAF_1F80 ..= 0xAF_1FFF:    bus.gpu0->write(size, 0xAF_1F80, addr, val, .TEXT_BG_LUT)
    case 0xAF_2000 ..= 0xAF_3FFF:    bus.gpu0->write(size, 0xAF_2000, addr, val, .LUT        )
    case 0xAF_8000 ..= 0xAF_87FF:    bus.gpu0->write(size, 0xAF_8000, addr, val, .FONT_BANK0 )
    case 0xAF_A000 ..= 0xAF_BFFF:    bus.gpu0->write(size, 0xAF_A000, addr, val, .TEXT       )
    case 0xAF_C000 ..= 0xAF_DFFF:    bus.gpu0->write(size, 0xAF_C000, addr, val, .TEXT_COLOR )
    case 0xAF_E400 ..= 0xAF_E41F:    // SID0
    case 0xAF_E830 ..= 0xAF_E839:    bus.ata0->write(size, 0xAF_E830, addr, val)
    case 0xAF_E000 ..= 0xAF_FFFF:    emu.write_not_implemented(#procedure, "io", size, addr, val)
    case 0xB0_0000 ..= VRAM_END :    bus.gpu0->write(size, 0xB0_0000, addr, val, .VRAM0      )
    case 0xF0_0000 ..= 0xF7_FFFF:    emu.write_not_implemented(#procedure, "flash0", size, addr, val)
    case 0xF8_0000 ..= 0xFF_FFFF:    emu.write_not_implemented(#procedure, "flash1", size, addr, val)
    case                        :    c256_bus_error(bus, "write", size, addr)
    }

    return
}

c256_bus_error :: proc(d: ^Bus, op: string, size: emu.Bitsize, addr: u32) {
    log.errorf("%s err %5s%d    at 0x %04X:%04X - c256 not implemented", 
                d.name, 
                op, 
                size, 
                u16(addr >> 16), 
                u16(addr & 0x0000_ffff))
    return
}

