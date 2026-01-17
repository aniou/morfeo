package timer

import "lib:emu"

import "emulator:pic"

MODE  :: emu.OpMode
TIMER :: struct {
    name:       string,
    id:         int,

    read:       proc(^TIMER, MODE, u32, u32) -> u32,
    write:      proc(^TIMER, MODE, u32, u32,    u32),
    delete:     proc(^TIMER),
    tick:       proc(^TIMER, int),

    model: union {TIMER_F256, TIMER_C256, TIMER_A2560X}
}
