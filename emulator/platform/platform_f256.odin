package platform

import "emulator:ata"
import "emulator:bus"
import "emulator:cpu"
import "emulator:gpu"
import "emulator:kbd"
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
    pic         :=   pic.pic_f256_make  ("pic0")
    p.bus        =   bus.f256_make      ("bus0",   pic, config)
    p.bus.kbd0   =   kbd.kbd_make       ("kbd0",   pic)
    p.bus.ram0   =   ram.ram_make       ("ram0",   0x08_0000) 
    p.bus.ram1   =   ram.ram_make       ("ram1",   0x08_0000) 
    p.bus.ram2   =   ram.ram_make       ("ram2",   0x08_0000) 
    p.bus.ram3   =   ram.ram_make       ("ram3",   0x08_0000) 
    p.bus.cart0  =   ram.ram_make       ("cart0",  0x04_0000) 
    p.bus.flash0 =   ram.ram_make       ("flash0", 0x08_0000) 
    p.bus.gpu0   =   gpu.tvicky_make    ("gpu0")
    p.bus.timer0 = timer.timer_f256_make("timer0", pic, 0)
    p.bus.timer1 = timer.timer_f256_make("timer1", pic, 1)
    p.cpu        =   cpu.make_w65c816   ("cpu0",   p.bus)
    //p.bus.rtc    =   rtc.bq4802_make ("rtc0",   pic)

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

