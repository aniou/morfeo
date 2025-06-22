package platform

import "emulator:ata"
import "emulator:bus"
import "emulator:cpu"
import "emulator:gpu"
import "emulator:inu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:rtc"
import "emulator:ram"

import "lib:emu"

import "core:fmt"
import "core:log"

Platform   :: struct { 
    delete: proc(^Platform),
    init:   proc(^Platform),

    cpu:     ^cpu.CPU,
    bus:     ^bus.Bus,

}
