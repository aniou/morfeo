package bus

import "lib:emu"

import "emulator:ata"
import "emulator:gpu"
import "emulator:inu"
import "emulator:joy"
import "emulator:kbd"
import "emulator:pic"
import "emulator:ps2"
import "emulator:rtc"
import "emulator:ram"
import "emulator:rng"
import "emulator:sdc"
import "emulator:timer"
import "emulator:tty"

MODE :: emu.OpMode // operation mode (8 bit, 16 bit le, etc)

Bus :: struct {
    name:     string,
    debug:      bool,          // enable/disable debug

  delete:    proc(^Bus),
    read:    proc(^Bus, MODE, u32) -> u32,
   write:    proc(^Bus, MODE, u32,    u32),

    ata0:     ^ata.PATA,
    cart0:    ^ram.RAM,     // f256: cart: sram/flash
    flash0:   ^ram.RAM,     // f256:       flash
    gpu0:     ^gpu.GPU,
    gpu1:     ^gpu.GPU,
    inu0:     ^inu.INU,
    joy0:     ^joy.JOY,
    joy1:     ^joy.JOY,     // not supported yet
    joy2:     ^joy.JOY,     // not supported yet
    joy3:     ^joy.JOY,     // not supported yet
    kbd0:     ^kbd.KBD,     // built-in, non-PS2 keyboard
    pic0:     ^pic.PIC,
    ps20:     ^ps2.PS2,     // looks weird, but in future... multiple ps2?
    aram0:    ^ram.ALTRAM,  // for testing purposes
    ram0:     ^ram.RAM,	    // first slot (ram/sram/flash...)
    ram1:     ^ram.RAM,     // second...
    ram2:     ^ram.RAM,     // third...
    ram3:     ^ram.RAM,     // fourth... 
    rng:      ^rng.RNG,
    rom0:     ^ram.RAM,	    // first slot, yes - the same backend here
    rtc0:     ^rtc.RTC,
    sdc0:     ^sdc.SDC,
    timer0: ^timer.TIMER,
    timer1: ^timer.TIMER,
    timer2: ^timer.TIMER,
    tty0:     ^tty.TTY,

    dip_user: u32,          // switches 3 to 5
    dip_boot: u32,          // switches 1, 2 and 8

    req:    emu.BusRequest,

    model: union {BUS_C256, BUS_F256, BUS_A2560X}
}

