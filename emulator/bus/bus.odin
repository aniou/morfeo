package bus

import "lib:emu"

import "emulator:ata"
import "emulator:gpu"
import "emulator:inu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:rtc"
import "emulator:ram"
import "emulator:timer"

import "core:prof/spall"

spall_ctx: spall.Context
spall_buffer: spall.Buffer

BITS :: emu.Bitsize

Bus :: struct {
    name:    string,
      id:    int,
    peek:    proc(^Bus, BITS, u32) -> u32,
    read:    proc(^Bus, BITS, u32) -> u32,
   write:    proc(^Bus, BITS, u32,    u32),
  delete:    proc(^Bus),

    pic0:     ^pic.PIC,
    ps20:     ^ps2.PS2,     // looks weird, but in future... multiple ps2?
    gpu0:     ^gpu.GPU,
    gpu1:     ^gpu.GPU,
    rtc0:     ^rtc.RTC,
    ata0:     ^ata.PATA,
    ram0:     ^ram.RAM,	   // first slot (ram/sram/flash...)
    ram1:     ^ram.RAM,     // second...
    ram2:     ^ram.RAM,     // third...
    inu0:     ^inu.INU,
    timer0: ^timer.TIMER,
    timer1: ^timer.TIMER,
    timer2: ^timer.TIMER,

    dip_user: u32,          // switches 3 to 5
    dip_boot: u32,          // switches 1, 2 and 8

    debug:     bool,          // enable/disable debug

    model: union {BUS_C256, BUS_F256}
}
