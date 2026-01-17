package platform

import "emulator:ata"
import "emulator:bus"
import "emulator:cpu"
import "emulator:gpu"
import "emulator:kbd"
import "emulator:inu"
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
    pic         :=   pic.make_pic_f256  ("pic0")
    p.bus        =   bus.make_f256      ("bus0",   pic, config)
    p.bus.kbd0   =   kbd.make_kbd       ("kbd0",   pic)
    p.bus.ram0   =   ram.make_ram       ("ram0",   0x08_0000) 
    p.bus.ram1   =   ram.make_ram       ("ram1",   0x08_0000) 
    p.bus.ram2   =   ram.make_ram       ("ram2",   0x08_0000) 
    p.bus.ram3   =   ram.make_ram       ("ram3",   0x08_0000) 
    p.bus.cart0  =   ram.make_ram       ("cart0",  0x04_0000) 
    p.bus.flash0 =   ram.make_ram       ("flash0", 0x08_0000) 
    p.bus.gpu0   =   gpu.make_tvicky    ("gpu0",   pic)
    p.bus.inu0   =   inu.make_inu_f256  ("inu0")
    p.bus.timer0 = timer.make_timer_f256("timer0", pic, 0)
    p.bus.timer1 = timer.make_timer_f256("timer1", pic, 1)
    p.cpu        =   cpu.make_w65c816   ("cpu0",   p.bus)
    p.bus.rtc0   =   rtc.bq4802_make    ("rtc0",   pic)

    p.cfg        = config

    p.delete    = f256_delete
    p.init      = f256_init
    return
}

f256_delete :: proc(p: ^Platform) {
    p.bus.gpu0->delete()
    // p.bus.pic->delete()
    p.bus.ram0->delete()
    p.bus.ram1->delete()
    p.bus.ram2->delete()
    p.bus.ram3->delete()
    p.bus.inu0->delete()
    // p.bus.rtc->delete()
         p.cpu->delete()
         p.bus->delete()

    free(p);
    return
}

f256_init :: proc(p: ^Platform) {
}

