package platform

import "core:fmt"
import "core:log"

import "lib:emu"

import "emulator:bus"
import "emulator:cpu"
import "emulator:pic"
import "emulator:ram"

make_alt816   :: proc(config: ^emu.Config) -> ^Platform {
    p           := new(Platform)
    p.bus        = bus.make_alt816   ("bus0")
    p.cpu        = cpu.make_w65c816  ("cpu0", p.bus)

    dcb         := new(emu.DeviceConfig)
    dcb.cfg      = config                                                                                                         
    dcb.req      = &p.bus.req
    defer free(dcb)

    p.bus.pic0   = pic.make_pic_fake ("pic0", dcb)
    p.bus.aram0  = ram.make_alt_ram  ("ram0", dcb, 256 * 65536)   // 16 megabytes

    p.init       =   init_alt816
    p.delete     = delete_alt816

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

