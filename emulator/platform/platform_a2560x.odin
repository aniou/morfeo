package platform

import "emulator:ata"
import "emulator:bus"
import "emulator:cpu"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:rtc"
import "emulator:ram"

import "core:fmt"
import "core:log"

a2560x_make :: proc() -> ^Platform {
    p          := new(Platform)
    pic        := pic.pic_m68k_make("pic0")
    p.bus       = bus.a2560x_make  ("bus0", pic)
    p.bus.ata0  = ata.pata_make    ("pata0")          // XXX - update to PIC
    p.bus.gpu0  = gpu.vicky3_make  ("A", pic, 0, 0)        // XXX - no DIP switch support
    p.bus.gpu1  = gpu.vicky3_make  ("B", pic, 1, 0)        // XXX - no DIP switch support
    p.bus.ps2   = ps2.ps2_make     ("ps2", pic, .C256FMX)    // XXX - change to proper id
    p.bus.rtc   = rtc.bq4802_make  ("rtc0", pic)
    p.bus.ram0  = ram.make_ram     ("ram0", 0x40_0000)
    p.cpu       = cpu.m68k_make    ("cpu0", p.bus)

    p.delete    = a2560x_delete
    return p
}

a2560x_delete :: proc(p: ^Platform) {
    p.bus.ata0->delete()
    p.bus.gpu0->delete()
    p.bus.gpu1->delete()
     p.bus.pic->delete()
     p.bus.ps2->delete()
    p.bus.ram0->delete()
     p.bus.rtc->delete()
         p.cpu->delete()
         p.bus->delete()

    free(p);
    return
}


