package platform

import "core:fmt"
import "core:log"

import "emulator:bus"
import "emulator:cpu"
import "emulator:pic"
import "emulator:ram"

make_mini816   :: proc() -> ^Platform {
    p          := new(Platform)
    p.bus       = bus.make_mini816  ("bus0")
    p.bus.pic0  = pic.make_pic_fake ("pic0")
    p.bus.ram0  = ram.make_ram      ("ram0", 256 * 65536)   // 16 megabytes
    p.cpu       = cpu.make_w65c816  ("cpu0", p.bus)

    p.init      =   init_mini816
    p.delete    = delete_mini816

    return p
}

delete_mini816   :: proc(p: ^Platform) {

         p.cpu->delete()
    p.bus.ram0->delete()
    p.bus.pic0->delete()
         p.bus->delete()

    free(p);
    return
}

init_mini816 :: proc(p: ^Platform) {
    log.errorf("%s not implemented", #procedure)
}

