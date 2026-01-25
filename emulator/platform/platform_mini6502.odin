package platform

import "core:fmt"
import "core:log"

import "lib:emu"

import "emulator:bus"
import "emulator:cpu"
import "emulator:pic"
import "emulator:ram"

make_mini6502   :: proc(config: ^emu.Config) -> ^Platform {
    p           := new(Platform)
    p.bus        = bus.make_mini6502 ("bus0")
    p.cpu        = cpu.make_w65c02s  ("cpu0",  p.bus)

    dcb         := new(emu.DeviceConfig)
    dcb.cfg      = config                                                                                                         
    dcb.req      = &p.bus.req
	defer free(dcb)

    p.bus.pic0   = pic.make_pic_fake ("pic0",  dcb)
    p.bus.ram0   = ram.make_ram      ("ram0",  dcb,  size = 65536)

    p.init       =   init_mini6502
    p.delete     = delete_mini6502

    return p
}

delete_mini6502   :: proc(p: ^Platform) {
         p.cpu->delete()
    p.bus.ram0->delete()
    p.bus.pic0->delete()
         p.bus->delete()

    free(p);
    return
}

init_mini6502 :: proc(p: ^Platform) {
    log.errorf("%s not implemented", #procedure)
}

