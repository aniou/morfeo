package platform

import "emulator:bus"
import "emulator:cpu"
import "emulator:pic"
import "emulator:ram"

import "core:fmt"
import "core:log"

test816_make :: proc() -> ^Platform {
    p          := new(Platform)
    pic        := pic.pic_c256_make ("pic0")
    p.bus       = bus.test816_make  ("bus0", pic)
    p.bus.ram0  = ram.ram_make      ("ram0", 256 * 65536)      // 16 megabytes
    p.cpu       = cpu.make_w65c816  ("cpu0", p.bus)

    p.delete    = test816_delete
    return p
}

test816_delete :: proc(p: ^Platform) {
         p.cpu->delete()
    p.bus.ram0->delete()
     p.bus.pic->delete()
         p.bus->delete()

    free(p);
    return
}


