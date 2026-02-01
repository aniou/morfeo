package platform

import "core:fmt"
import "core:log"

import "lib:emu"

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

make_f256 :: proc(config: ^emu.Config) -> ^Platform {
    p           :=   new(Platform)
    p.cfg        =   config
    p.bus        =   bus.make_f256      ("bus0",   config)
    p.cpu        =   cpu.make_w65c816   ("cpu0",   p.bus)

    dcb         := new(emu.DeviceConfig)
    dcb.cfg      = config
    dcb.req      = &p.bus.req
    defer free(dcb)

    pic0        :=   pic.make_pic_f256  ("pic0",   dcb) 
    p.bus.pic0   =   pic0
    p.bus.kbd0   =   kbd.make_kbd       ("kbd0",   dcb,  pic0                  )
    p.bus.ram0   =   ram.make_ram       ("ram0",   dcb,        size = 0x08_0000) 
    p.bus.ram1   =   ram.make_ram       ("ram1",   dcb,        size = 0x08_0000) 
    p.bus.ram2   =   ram.make_ram       ("ram2",   dcb,        size = 0x08_0000) 
    p.bus.ram3   =   ram.make_ram       ("ram3",   dcb,        size = 0x08_0000) 
    p.bus.cart0  =   ram.make_ram       ("cart0",  dcb,        size = 0x04_0000) 
    p.bus.flash0 =   ram.make_ram       ("flash0", dcb,        size = 0x08_0000) 
    p.bus.gpu0   =   gpu.make_tvicky    ("gpu0",   dcb,  pic0                  )
    p.bus.inu0   =   inu.make_inu_f256  ("inu0",   dcb                         )
    p.bus.timer0 = timer.make_timer_f256("timer0", dcb,  pic0,  id   = 0       )
    p.bus.timer1 = timer.make_timer_f256("timer1", dcb,  pic0,  id   = 1       )
    p.bus.rtc0   =   rtc.make_bq4802    ("rtc0",   dcb,  pic0                  )


    p.delete    = delete_f256
    p.init      =   init_f256
    return p
}

delete_f256 :: proc(p: ^Platform) {
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

init_f256 :: proc(p: ^Platform) {
}

// eof
