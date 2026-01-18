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
    using entity: ^Bus,
    vdma:          DMA,
    sdma:          DMA,
    sys_stat:      u32,   // GABE_SYS_STAT
}

c256_make :: proc(name: string, pic: ^pic.PIC, config: ^emu.Config) -> ^Bus {
    bus         := new(Bus)
    bus.name     = name
    bus.pic0     = pic
    bus.debug    = false
    bus.dip_boot = (transmute(u32)config.dipoff & 0b1000_0011)       // only boot and hdd switches here
    bus.dip_user = (transmute(u32)config.dipoff & 0b0001_1100) >> 2  // user: 3-5
    bus.model    = BUS_C256{
        sdma     = DMA{},
        vdma     = DMA{},
        sys_stat = PLATFORM_ID | 0x10 // 0x10 for expansion card present - XXX - parametrize that
    }

    return bus
}

delete_c256 :: proc(b: ^Bus) {
    //delete(b)
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

c256_read :: proc(bus: ^Bus, mode: MODE, ra: u32) -> (out: u32) {
    b  := &bus.model.(BUS_C256)  // temporary workaround
    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer)
    //log.debugf("%s read     from 0x %04X:%04X", bus.name, u16(addr >> 16), u16(addr & 0x0000_ffff))

    switch ra {
    case 0x00_0100 ..= 0x00_012B:  out =   bus.inu0->read(mode, ra - 0x00_0100, ra)
    case 0x00_0140 ..= 0x00_014F:  out =   bus.pic0->read(mode, ra - 0x00_0140, ra)
    case 0x00_0160 ..= 0x00_0167:  out = bus.timer0->read(mode, ra - 0x00_0160, ra)
    case 0x00_0168 ..= 0x00_016F:  out = bus.timer1->read(mode, ra - 0x00_0168, ra)
    case 0x00_0170 ..= 0x00_0177:  out = bus.timer2->read(mode, ra - 0x00_0170, ra)
    case 0x00_0000 ..= SRAM_END :  out =   bus.ram0->read(mode, ra - 0x00_0000, ra)  // 2 or 4 MB
    case PS2_START ..= PS2_END  :  out =   bus.ps20->read(mode, ra - PS2_START, ra)  // AF_1803-7 or AF_1060-4

    case 0xAE_0000 ..= 0xAE_001F:  out =   bus.gpu1->read(mode, ra - 0xAE_0000, ra, .ID_CARD    )
    case 0xAE_1000 ..= 0xAE_17FF:  out =   bus.gpu1->read(mode, ra - 0xAE_1000, ra, .FONT_BANK0 )
    case 0xAE_1B00 ..= 0xAE_1B3F:  out =   bus.gpu1->read(mode, ra - 0xAE_1B00, ra, .TEXT_FG_LUT)
    case 0xAE_1B40 ..= 0xAE_1B7F:  out =   bus.gpu1->read(mode, ra - 0xAE_1B40, ra, .TEXT_BG_LUT)
    case 0xAE_1E00 ..= 0xAE_1E1F:  out =   bus.gpu1->read(mode, ra - 0xAE_1E00, ra, .MAIN       )
    case 0xAE_2000 ..= 0xAE_3FFF:  out =   bus.gpu1->read(mode, ra - 0xAE_2000, ra, .TEXT       )
    case 0xAE_4000 ..= 0xAE_5FFF:  out =   bus.gpu1->read(mode, ra - 0xAE_4000, ra, .TEXT_COLOR )

    case 0xAF_0200 ..= 0xAF_022F:  out =   bus.gpu0->read(mode, ra - 0xAF_0200, ra, .TILEMAP    )
    case 0xAF_0280 ..= 0xAF_029F:  out =   bus.gpu0->read(mode, ra - 0xAF_0280, ra, .TILESET    )
    case 0xAF_0400 ..= 0xAF_040F:  out =    c256_dma_read(b, mode, ra - 0xAF_0400)
    case 0xAF_0420 ..= 0xAF_0430:  out =    c256_dma_read(b, mode, ra - 0xAF_0420)
    case 0xAF_0500 ..= 0xAF_05FF:  out =   bus.gpu0->read(mode, ra - 0xAF_0500, ra, .MOUSEPTR0  )
    case 0xAF_0600 ..= 0xAF_06FF:  out =   bus.gpu0->read(mode, ra - 0xAF_0600, ra, .MOUSEPTR1  )
    case 0xAF_0000 ..= 0xAF_07FF:  out =   bus.gpu0->read(mode, ra - 0xAF_0000, ra, .MAIN_A     )
    case 0xAF_0800 ..= 0xAF_080F:  out =   bus.rtc0->read(mode, ra - 0xAF_0800, ra)
    case 0xAF_1F40 ..= 0xAF_1F7F:  out =   bus.gpu0->read(mode, ra - 0xAF_1F40, ra, .TEXT_FG_LUT)
    case 0xAF_1F80 ..= 0xAF_1FFF:  out =   bus.gpu0->read(mode, ra - 0xAF_1F80, ra, .TEXT_BG_LUT)
    case 0xAF_2000 ..= 0xAF_3FFF:  out =   bus.gpu0->read(mode, ra - 0xAF_1F80, ra, .LUT        )
    case 0xAF_8000 ..= 0xAF_87FF:  out =   bus.gpu0->read(mode, ra - 0xAF_8000, ra, .FONT_BANK0 )
    case 0xAF_A000 ..= 0xAF_BFFF:  out =   bus.gpu0->read(mode, ra - 0xAF_A000, ra, .TEXT       )
    case 0xAF_C000 ..= 0xAF_DFFF:  out =   bus.gpu0->read(mode, ra - 0xAF_C000, ra, .TEXT_COLOR )
    case 0xAF_E400 ..= 0xAF_E41f:  out =   0    // SID0 - silence it for a while
    case 0xAF_E800              :  out =   bus.joy0->read(mode, ra - 0xAF_E800, ra)
    case 0xAF_E80D              :  out =   b.dip_user
    case 0xAF_E80E              :  out =   b.dip_boot
    case 0xAF_E830 ..= 0xAF_E839:  out =   bus.ata0->read(mode, ra - 0xAF_E830, ra)
    case 0xAF_E884 ..= 0xAF_E885:  out =    bus.rng->read(mode, ra - 0xAF_E884, ra)
    case 0xAF_E887              :  out =   b.sys_stat
    case 0xAF_E000 ..= 0xAF_FFFF:  emu.error_read(bus.name, .NOT_IMPL, mode, ra - 0xAF_E000, ra, .IO)
    case 0xB0_0000 ..= VRAM_END :  out =   bus.gpu0->read(mode, ra - 0xB0_0000, ra, .VRAM0      ) // 2 or 4MB
    case 0xF0_0000 ..= 0xF7_FFFF:  emu.error_read(bus.name, .NOT_IMPL, mode, ra - 0xF0_0000, ra, .FLASH0)
    case 0xF8_0000 ..= 0xFF_FFFF:  emu.error_read(bus.name, .NOT_IMPL, mode, ra - 0xF8_0000, ra, .FLASH1)
    case                        :  emu.error_read(bus.name, .NOT_IMPL, mode, ra            , ra)
    }

    if bus.debug {
        log.debugf("%s read%d  %08x from 0x %04X:%04X", bus.name, mode, out, u16(ra >> 16), u16(ra & 0x0000_ffff))
    }
    return
}

c256_write :: proc(bus: ^Bus, mode: MODE, ra, val: u32) {
    b  := &bus.model.(BUS_C256)  // temporary workaround
    //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer)
    if bus.debug {
        log.debugf("%s write%d %08x   to 0x %04X:%04X", bus.name, mode, val, u16(ra >> 16), u16(ra & 0x0000_ffff))
    }

    switch ra {
    case 0x00_0100 ..= 0x00_012B:    bus.inu0->write(mode, ra - 0x00_0100, ra, val)
    case 0x00_0140 ..= 0x00_014F:    bus.pic0->write(mode, ra - 0x00_0140, ra, val)
    case 0x00_0160 ..= 0x00_0167:  bus.timer0->write(mode, ra - 0x00_0160, ra, val)
    case 0x00_0168 ..= 0x00_016F:  bus.timer1->write(mode, ra - 0x00_0168, ra, val)
    case 0x00_0170 ..= 0x00_0177:  bus.timer2->write(mode, ra - 0x00_0170, ra, val)
    case 0x00_0000 ..= SRAM_END :    bus.ram0->write(mode, ra - 0x00_0000, ra, val)
    case PS2_START ..= PS2_END  :    bus.ps20->write(mode, ra - PS2_START, ra, val)

    case 0xAE_1000 ..= 0xAE_17FF:    bus.gpu1->write(mode, ra - 0xAE_1000, ra, val, .FONT_BANK0 )
    case 0xAE_1B00 ..= 0xAE_1B3F:    bus.gpu1->write(mode, ra - 0xAE_1B00, ra, val, .TEXT_FG_LUT)
    case 0xAE_1B40 ..= 0xAE_1B7F:    bus.gpu1->write(mode, ra - 0xAE_1B40, ra, val, .TEXT_BG_LUT)
    case 0xAE_1E00 ..= 0xAE_1E1F:    bus.gpu1->write(mode, ra - 0xAE_1E00, ra, val, .MAIN       )
    case 0xAE_2000 ..= 0xAE_3FFF:    bus.gpu1->write(mode, ra - 0xAE_2000, ra, val, .TEXT       )
    case 0xAE_4000 ..= 0xAE_5FFF:    bus.gpu1->write(mode, ra - 0xAE_4000, ra, val, .TEXT_COLOR )

    case 0xAF_0200 ..= 0xAF_022F:    bus.gpu0->write(mode, ra - 0xAF_0200, ra, val, .TILEMAP    )
    case 0xAF_0280 ..= 0xAF_029F:    bus.gpu0->write(mode, ra - 0xAF_0280, ra, val, .TILESET    )
    case 0xAF_0400 ..= 0xAF_040F:    c256_dma_write(b, mode, ra - 0xAF_0400, val)
    case 0xAF_0420 ..= 0xAF_0430:    c256_dma_write(b, mode, ra - 0xAF_0420, val)
    case 0xAF_0500 ..= 0xAF_05FF:    bus.gpu0->write(mode, ra - 0xAF_0500, ra, val, .MOUSEPTR0  )
    case 0xAF_0600 ..= 0xAF_06FF:    bus.gpu0->write(mode, ra - 0xAF_0600, ra, val, .MOUSEPTR1  )
    case 0xAF_0000 ..= 0xAF_07FF:    bus.gpu0->write(mode, ra - 0xAF_0000, ra, val, .MAIN_A     )
    case 0xAF_0800 ..= 0xAF_080F:    bus.rtc0->write(mode, ra - 0xAF_0800, ra, val)
    case 0xAF_1F40 ..= 0xAF_1F7F:    bus.gpu0->write(mode, ra - 0xAF_1F40, ra, val, .TEXT_FG_LUT)
    case 0xAF_1F80 ..= 0xAF_1FFF:    bus.gpu0->write(mode, ra - 0xAF_1F80, ra, val, .TEXT_BG_LUT)
    case 0xAF_2000 ..= 0xAF_3FFF:    bus.gpu0->write(mode, ra - 0xAF_2000, ra, val, .LUT        )
    case 0xAF_8000 ..= 0xAF_87FF:    bus.gpu0->write(mode, ra - 0xAF_8000, ra, val, .FONT_BANK0 )
    case 0xAF_A000 ..= 0xAF_BFFF:    bus.gpu0->write(mode, ra - 0xAF_A000, ra, val, .TEXT       )
    case 0xAF_C000 ..= 0xAF_DFFF:    bus.gpu0->write(mode, ra - 0xAF_C000, ra, val, .TEXT_COLOR )
    case 0xAF_E400 ..= 0xAF_E41F:    // SID0
    case 0xAF_E830 ..= 0xAF_E839:    bus.ata0->write(mode, ra - 0xAF_E830, ra, val)
    case 0xAF_E000 ..= 0xAF_FFFF:  emu.error_write(bus.name, .NOT_IMPL, mode, ra - 0xAF_E000, ra, val, .IO)
    case 0xB0_0000 ..= VRAM_END :    bus.gpu0->write(mode, ra - 0xB0_0000, ra, val, .VRAM0      )
    case 0xF0_0000 ..= 0xF7_FFFF:  emu.error_write(bus.name, .NOT_IMPL, mode, ra - 0xF0_0000, ra, val, .FLASH0)
    case 0xF8_0000 ..= 0xFF_FFFF:  emu.error_write(bus.name, .NOT_IMPL, mode, ra - 0xF8_0000, ra, val, .FLASH1)
    case                        :  emu.error_write(bus.name, .NOT_IMPL, mode, ra            , ra, val)
    }

    return
}
