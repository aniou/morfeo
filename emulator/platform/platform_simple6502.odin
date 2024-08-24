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

make_simple6502 :: proc() -> ^Platform {
    p          := new(Platform)
    p.bus       = bus.make_simple6502("bus0", nil)
    p.bus.ram0  = memory.make_ram("ram0", 65536)
    p.cpu       = cpu.make_w65c02s("cpu0", p.bus)

    p.delete    = delete_simple6502
    return p
}

delete_simple6502 :: proc(p: ^Platform) {
    p.bus.ram0->delete()
         p.cpu->delete()
         p.bus->delete()

    free(p);
    return
}


