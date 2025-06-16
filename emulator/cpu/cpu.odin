package cpu

import "core:thread"
import "base:runtime"
import "emulator:bus"

localbus: ^bus.Bus               // global bus pointer, needed by external CPU implemntation (musashi)
ctx:      runtime.Context

CPU :: struct {
    delete: proc(^CPU),
    setpc:  proc(^CPU, u32),
    reset:  proc(^CPU),
    run: proc(^CPU, u32),
    clear_irq: proc(^CPU),

    all_cycles: u32,

    // for thread management
    active:   bool,
    shutdown: bool,
    thread:   ^thread.Thread,

    // tick etc. proc
    name:   string,
    bus:    ^bus.Bus,
    model: union {CPU_65xxx, CPU_m68k}

}
