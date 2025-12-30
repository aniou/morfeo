package platform

import "emulator:ata"
import "emulator:bus"
import "emulator:cpu"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:rtc"
import "emulator:ram"
import "emulator:timer"

import "lib:emu"

import "core:fmt"
import "core:log"

f256_make :: proc(config: ^emu.Config) -> (p: ^Platform, ok: bool = true)  {
    p            =   new(Platform)
    pic         :=   pic.pic_c256_make    ("pic0")          // XXX: dummy, so far
    p.bus        =   bus.f256_make   ("bus0",   pic, config)
    p.bus.ps20   =   ps2.ps2_make       ("ps2",    pic)     // XXX: dummy
    p.bus.ram0   =   ram.ram_make    ("ram0",   0x08_0000) 
    p.bus.ram1   =   ram.ram_make    ("ram1",   0x08_0000) 
    p.bus.ram2   =   ram.ram_make    ("ram2",   0x08_0000) 
    p.bus.ram3   =   ram.ram_make    ("ram3",   0x08_0000) 
    p.bus.cart0  =   ram.ram_make    ("cart0",  0x04_0000) 
    p.bus.flash0 =   ram.ram_make    ("flash0", 0x08_0000) 
    p.bus.gpu0   =   gpu.make_tvicky ("gpu0",   p.bus.ram0)
    p.bus.timer2 = timer.timer_c256_make("timer2", pic, 2)  // XXX: dummy
    //p.bus.rtc    =   rtc.bq4802_make ("rtc0",   pic)
    p.cpu        =   cpu.make_w65c816("cpu0",   p.bus)

    p.cfg        = config

    p.delete    = f256_delete
    p.init      = f256_init
    return
}

f256_delete :: proc(p: ^Platform) {
    p.bus.gpu0->delete()
    // p.bus.pic->delete()
    p.bus.ram0->delete()
    // p.bus.rtc->delete()
         p.cpu->delete()
         p.bus->delete()

    free(p);
    return
}

f256_init :: proc(p: ^Platform) {
}

