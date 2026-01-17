package platform

import "emulator:bus"
import "emulator:cpu"

import "lib:emu"

import "core:fmt"
import "core:log"

Platform   :: struct { 
    delete: proc(^Platform),
    init:   proc(^Platform),

    cfg:     ^emu.Config,
    cpu:     ^cpu.CPU,
    bus:     ^bus.Bus,
}
