package platform

import "core:fmt"
import "core:log"

import "emulator:bus"
import "emulator:cpu"
import "emulator:pic"
import "emulator:ram"

make_alt816   :: proc() -> ^Platform {
    p          := new(Platform)
    p.bus       = bus.make_alt816  ("bus0")
    p.bus.pic0  = pic.make_pic_fake ("pic0")
    p.bus.aram0 = ram.make_alt_ram  ("ram0", &p.bus.req, 256 * 65536)   // 16 megabytes
    p.cpu       = cpu.make_w65c816  ("cpu0", p.bus)

    p.init      =   init_alt816
    p.delete    = delete_alt816

    return p
}

delete_alt816   :: proc(p: ^Platform) {
         p.cpu->delete()
    p.bus.aram0->delete()
    p.bus.pic0->delete()
         p.bus->delete()

    free(p);
    return
}

init_alt816 :: proc(p: ^Platform) {
    log.errorf("%s not implemented", #procedure)
}

