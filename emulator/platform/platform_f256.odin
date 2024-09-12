package platform

import "emulator:ata"
import "emulator:bus"
import "emulator:cpu"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:rtc"
import "emulator:memory"

import "core:fmt"
import "core:log"

make_f256 :: proc() -> ^Platform {
    p          := new(Platform)
    pic        := pic.pic_make("pic0")          // XXX: dummy, so far
    p.bus       = bus.make_f256("bus0", pic)
    p.bus.ram0  = memory.make_ram("ram0", 0x40_0000) // XXX check it
    p.bus.ram1  = memory.make_ram("ram0", 0x40_0000) // XXX check it
    p.bus.gpu0  = gpu.make_tvicky("gpu0", ram0)
    p.bus.ps2   = ps2.ps2_make("ps2", pic)
    p.bus.rtc   = rtc.bq4802_make("rtc0", pic)
    p.cpu       = cpu.make_w65c02("cpu0", p.bus)

    p.delete    = delete_f256
    return p
}

delete_f256 :: proc(p: ^Platform) {
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


