package timer

import "lib:emu"

import "emulator:pic"

BITS  :: emu.Bitsize
TIMER :: struct {
    name:       string,
    id:         int,

    read:       proc(^TIMER, BITS, u32, u32) -> u32,
    write:      proc(^TIMER, BITS, u32, u32,    u32),
    delete:     proc(^TIMER),
    tick:       proc(^TIMER, int),

    model: union {TIMER_C256, TIMER_A2560X}
}
