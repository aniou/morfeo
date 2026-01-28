package platform

import "lib:emu"

import "emulator:ata"
import "emulator:bus"
import "emulator:cpu"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:rtc"
import "emulator:ram"
import "emulator:timer"
import "emulator:tty"

import "core:fmt"
import "core:log"

// XXX: take a look at sys_general.h at Foenix MCP
//
// MACHINE_SUBID - denotes subtype
// 00 - pizza box
// 01 - lunch box
// 02 - cube
when        emu.TARGET == "a2560x"  { MACHINE_ID        : u32 : 0x08           // MODEL_RESERVED
                                      MACHINE_SUBID     : u32 : 0x02           // box type: CUBE
                                      CLOCK_SPEED       : u32 : 0x03   <<  5   // SYSCLK_33MHZ
                                      CPU_ID            : u32 : 0x06   << 12   // CPU_M68040V
                                      FPGA_SUBVER       : u32 : 0x01   << 16
                                      FPGA_MODEL        : u32 : 20857  << 16
                                      FPGA_VERSION      : u32 : 873
                                      GABE_BASE         : u32 : 0xFE_C0_0000
                                      GABE_SUBVER_ID    : u32 : 0xFE_C0_000C
                                      GABE_CHIP_VERSION : u32 : 0xFE_C0_0010   // Number[31:16], Version[15:0]
                                    }
else                                { MACHINE_ID        : u32 : 0xFF           // silly workaround
                                      MACHINE_SUBID     : u32 : 0xFF           // box type: CUBE
                                      CLOCK_SPEED       : u32 : 0xFF   <<  5   // SYSCLK_33MHZ
                                      CPU_ID            : u32 : 0xFF   << 12   // CPU_M68040V
                                      FPGA_SUBVER       : u32 : 0xFF   << 16
                                      FPGA_MODEL        : u32 : 65535  << 16
                                      FPGA_VERSION      : u32 : 65535
                                      GABE_BASE         : u32 : 0xFE_FF_FFFF
                                      GABE_SUBVER_ID    : u32 : 0xFE_FF_FFFF
                                      GABE_CHIP_VERSION : u32 : 0xFE_FF_FFFF   // Number[31:16], Version[15:0]
                                    }


make_a2560x :: proc(config: ^emu.Config) -> ^Platform {
    p           := new(Platform)
    p.cfg        = config
    p.bus        = bus.make_a2560x    ("bus0", config)
    p.cpu        = cpu.m68k_make      ("cpu0", p.bus)

    // temporary block, used for passing parameters
    dcb         := new(emu.DeviceConfig)
    dcb.cfg      = config
    dcb.req      = &p.bus.req
    defer free(dcb)

    pic0        :=   pic.make_pic_m68k    ("pic0",   dcb)
	p.bus.pic0   =   pic0
    p.bus.ata0   =   ata.make_pata        ("pata0",  dcb)                   // XXX - update to PIC
    p.bus.gpu0   =   gpu.make_vicky3      ("gpu0",   dcb,  pic0,  0)        // XXX - no DIP switch support
    p.bus.gpu1   =   gpu.make_vicky3      ("gpu1",   dcb,  pic0,  1)        // XXX - no DIP switch support
    p.bus.ps20   =   ps2.make_ps2         ("ps20",   dcb,  pic0)
    p.bus.rtc0   =   rtc.make_bq4802      ("rtc0",   dcb,  pic0)
    p.bus.ram0   =   ram.make_ram         ("ram0",   dcb,         size =  0x40_0000)
    p.bus.rom0   =   ram.make_ram         ("rom0",   dcb,         size =  0x02_0000)      // for GAVIN backend
    p.bus.ram1   =   ram.make_ram         ("ram1",   dcb,         size = 0x400_0000)      // SDRAM
    p.bus.timer0 = timer.timer_a2560x_make("timer0", dcb,  pic0,  id= 0)

    p.delete     = delete_a2560x
    p.init       = init_a2560x
    return p
}

delete_a2560x :: proc(p: ^Platform) {
         p.cpu->delete()
    p.bus.ata0->delete()
    p.bus.gpu0->delete()
    p.bus.gpu1->delete()
    p.bus.pic0->delete()
    p.bus.ps20->delete()
    p.bus.ram0->delete()
    p.bus.ram1->delete()
    p.bus.rom0->delete()
    p.bus.rtc0->delete()
  p.bus.timer0->delete()
         p.bus->delete()

    free(p);
    return
}

init_a2560x :: proc(p: ^Platform) {
    // A2560X and GenX have different ID system 
    p.bus.rom0->write(.mode_32be, GABE_SUBVER_ID - 0xFE_C0_0000,    0x05 | CLOCK_SPEED | CPU_ID | FPGA_SUBVER)
    p.bus.rom0->write(.mode_32be, GABE_CHIP_VERSION - 0xFE_C0_0000, FPGA_MODEL| FPGA_VERSION)

    GABE_SUB_MODEL_FF_ID : u32 : 0xFE_C0_0514
    GABE_SUB_MODEL_ID    : u32 : 0xFE_C0_0516
    p.bus.rom0->write(.mode_16be, GABE_SUB_MODEL_FF_ID - 0xFE_C0_0000, MACHINE_SUBID)
    p.bus.rom0->write(.mode_16be, GABE_SUB_MODEL_ID - 0xFE_C0_0000,    MACHINE_ID)

}

