package cpu

import "base:runtime"
import "emulator:bus"

localbus: ^bus.Bus               // global bus pointer, needed by external CPU implemntation (musashi)
ctx:      runtime.Context

CPU :: struct {
    setpc:  proc(^CPU, u32),
    reset:  proc(^CPU),
    exec: proc(^CPU, u32),
    clear_irq: proc(^CPU),

    cycles: u32,

    // tick etc. proc
    name:   string,
    bus:    ^bus.Bus,
    model: union {CPU_65c816, CPU_m68k}
}
