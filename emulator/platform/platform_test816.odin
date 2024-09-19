package platform

import "emulator:ata"
import "emulator:bus"
import "emulator:cpu"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:rtc"
import "emulator:ram"

import "core:fmt"
import "core:log"

test816_make :: proc() -> ^Platform {
    p          := new(Platform)
    p.bus       = bus.test816_make("bus0", nil)
    p.bus.ram0  = ram.make_ram    ("ram0", 256 * 65536)      // 16 megabytes
    p.cpu       = cpu.make_w65c816("cpu0", p.bus)

    p.delete    = test816_delete
    return p
}

test816_delete :: proc(p: ^Platform) {
    p.bus.ram0->delete()
         p.cpu->delete()
         p.bus->delete()

    free(p);
    return
}


