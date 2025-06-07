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

import "lib:emu"

c256_make :: proc(type: emu.Type) -> ^Platform {
    mem        := 0x40_0000 if type == .C256Uplus else 0x20_0000

    p          := new(Platform)
    pic        := pic.pic_make    ("pic0")         // XXX: dummy, so far
    p.bus       = bus.c256_make   ("bus0", pic, type)
    p.bus.ram0  = ram.make_ram    ("ram0", mem)
    p.bus.gpu0  = gpu.vicky2_make ("gpu0", 0, 0)   // XXX: fake DIP switch
    p.bus.ps2   = ps2.ps2_make    ("ps2",  pic)
    p.bus.rtc   = rtc.bq4802_make ("rtc0", pic)
    p.cpu       = cpu.make_w65c816("cpu0", p.bus)
    p.delete    = c256_delete

    p.bus.ram0->write(.bits_8, 0xFFFC, 0x00)         // initial vector for this platform
    p.bus.ram0->write(.bits_8, 0xFFFD, 0x10)

    return p
}

c256_delete :: proc(p: ^Platform) {
    p.bus.gpu0->delete()
     p.bus.pic->delete()
     p.bus.ps2->delete()
    p.bus.ram0->delete()
     p.bus.rtc->delete()
         p.cpu->delete()
         p.bus->delete()

    free(p);
    return
}


