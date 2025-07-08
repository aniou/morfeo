package cpu

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

    // tick etc. proc
    name:   string,
    bus:    ^bus.Bus,
    debug:  bool,
    model: union {CPU_65xxx, CPU_m68k}
}
