package bus

import "lib:emu"

import "emulator:ata"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:rtc"
import "emulator:ram"

import "core:prof/spall"

ebus:   ^Bus        // test global XXX: remove it?
spall_ctx: spall.Context
spall_buffer: spall.Buffer

Bus :: struct {
    name:    string,
      id:    int,
    read:    proc(^Bus, emu.Request_Size, u32) -> u32,
   write:    proc(^Bus, emu.Request_Size, u32,     u32),
  delete:    proc(^Bus),
     pic:    ^pic.PIC,
     ps2:    ^ps2.PS2,
    gpu0:    ^gpu.GPU,
    gpu1:    ^gpu.GPU,
     rtc:    ^rtc.RTC,
    ata0:    ^ata.PATA,
    ram0:    ^ram.RAM,	   // first slot (ram/sram/flash...)
    ram1:    ^ram.RAM,     // second...
    ram2:    ^ram.RAM,     // third...

    model: union {Bus_F256}
}
