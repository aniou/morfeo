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


a2560x_make :: proc() -> ^Platform {
    p          := new(Platform)
    pic        := pic.pic_m68k_make("pic0")
    p.bus       = bus.a2560x_make  ("bus0", pic)
    p.bus.ata0  = ata.pata_make    ("pata0")               // XXX - update to PIC
    p.bus.gpu0  = gpu.vicky3_make  ("A", pic, 0, 0)        // XXX - no DIP switch support
    p.bus.gpu1  = gpu.vicky3_make  ("B", pic, 1, 0)        // XXX - no DIP switch support
    p.bus.ps20  = ps2.ps2_make     ("ps20", pic)
    p.bus.rtc0  = rtc.bq4802_make  ("rtc0", pic)
    p.bus.ram0  = ram.ram_make     ("ram0",  0x40_0000)
    p.bus.rom0  = ram.ram_make     ("rom0",  0x02_0000)      // for GAVIN backend
    p.bus.ram1  = ram.ram_make     ("ram1", 0x400_0000)      // SDRAM
    //p.bus.tty0  = tty.tty_make     ("tty0")
    p.cpu       = cpu.m68k_make    ("cpu0", p.bus)

    p.delete    = a2560x_delete
    p.init      = a2560x_init
    return p
}

a2560x_delete :: proc(p: ^Platform) {
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
    //p.bus.tty0->delete()
         p.bus->delete()

    free(p);
    return
}

a2560x_init :: proc(p: ^Platform) {
    // A2560X and GenX have different ID system 
    p.bus.rom0->write(.bits_32, GABE_BASE, GABE_SUBVER_ID,     0x05 | CLOCK_SPEED | CPU_ID | FPGA_SUBVER)
    p.bus.rom0->write(.bits_32, GABE_BASE, GABE_CHIP_VERSION,  FPGA_MODEL| FPGA_VERSION)

    GABE_SUB_MODEL_FF_ID : u32 : 0xFE_C0_0514
    GABE_SUB_MODEL_ID    : u32 : 0xFE_C0_0516
    p.bus.rom0->write(.bits_16, GABE_BASE, GABE_SUB_MODEL_FF_ID,  MACHINE_SUBID)
    p.bus.rom0->write(.bits_16, GABE_BASE, GABE_SUB_MODEL_ID,     MACHINE_ID)

}

