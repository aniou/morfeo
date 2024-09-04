
package cpu

import "base:runtime"
import "core:fmt"
import "core:log"
import "emulator:bus"

// The Bit Manipulation Instructions have been added to the standard W65C02S.
// The designation for this updated device is W65C02SB. [...] The W65C02S will
// continued to be produced for a period of time. The W65C02SB will eventually
// become the only W65C02S device available.
//
// http://forum.6502.org/viewtopic.php?f=1&t=4913


// Rockwell's changes added more bit manipulation instructions for directly
// setting and testing any bit, and combining the test, clear and branch into a
// single opcode. The new instructions were available from the start in Rockwell's
// R65C00 family,[17] but was not part of the original 65C02 specification and not
// found in versions made by WDC or its other licensees. These were later copied
// back into the baseline design, and were available in later WDC versions.  
//
// https://archive.org/details/softalkv3n10jun1983/page/198/mode/2up
// https://en.wikipedia.org/wiki/WDC_65C02#Bit_manipulation_instructions


// GTE Microcircuits, which later became California Micro Devices (CMD, not to
// be confused with Creative Micro Designs which designed and sold software and
// hardware for C64), used "SC" in their part numbers; so their CMOS 6502 was the
// G65SC02. They had 17 other similar numbers in my Jan '87 data book for
// variations on the CMOS 6502. These do not have BBR, BBS, SMB, RMB, STP, or WAI.
// Through some range of time that I'm not sure of, WDC put a "B" in their part
// numbers for the ones having the bit instructions, so the number was W65C02SB,
// but then I remember Deb Lamoree (sp?) at WDC telling me on the phone that they
// were dropping the "B" and all the 65c02's will automatically have the bit
// instructions. The bit instructions and STP and WAI are in my Aug '92 W65C02S
// data sheet though.
// 
// [garthwilson] http://forum.6502.org/viewtopic.php?f=4&t=1383&start=15

make_w65c02s :: proc (name: string, bus: ^bus.Bus) -> ^CPU {
    cpu           := new(CPU)
    cpu.name       = name
    cpu.setpc      = setpc_w65c02s
    cpu.reset      = reset_w65c02s
    cpu.run        = run_w65c02s
    cpu.clear_irq  = clear_irq_w65c02s      // XXX not finished yet
    cpu.delete     = delete_w65c02s
    cpu.bus        = bus
    cpu.all_cycles = 0

    c             := CPU_65xxx{cpu = cpu, type = CPU_65xxx_type.W65C02S}
    c.real65c02    = true
    c.a            = DataRegister_65xxx{size = byte}
    c.x            = DataRegister_65xxx{size = byte}
    c.y            = DataRegister_65xxx{size = byte}
    c.t            = DataRegister_65xxx{size = byte}
    c.tb           = DataRegister_65xxx{size = byte}
    c.tw           = DataRegister_65xxx{size = word}
    c.pc           = AddressRegister_65xxx{bwrap = true}
    c.sp           = AddressRegister_65xxx{bwrap = true}
    c.ab           = AddressRegister_65xxx{bwrap = true}
    c.ta           = AddressRegister_65xxx{bwrap = true}
    c.f.E          = true                                   // force 65x02 mode
    c.state        = .FETCH
    cpu.model      = c

    // we need global because of external musashi
    localbus   = bus
    return cpu
}

clear_irq_w65c02s :: proc(cpu: ^CPU) {
    c            := &cpu.model.(CPU_65xxx)
    c.irq         = {}
    c.irq_pending = false
}

setpc_w65c02s :: proc(cpu: ^CPU, address: u32) {
    c         := &cpu.model.(CPU_65xxx)
    c.pc.addr  = u16( address & 0x0000_FFFF       )
    c.pc.bank  = u16((address & 0x00FF_0000) >> 16)
    c.state    = .FETCH
    c.stall    = 0
    c.cycles   = 0
    return
}

delete_w65c02s :: proc(cpu: ^CPU) {
    free(cpu)
    return
}

run_w65c02s :: proc(cpu: ^CPU, ticks: u32 = 1000) {
    c := &cpu.model.(CPU_65xxx)
    current_ticks : u32 = 0

    for current_ticks <= ticks {
        step_w65c02s(c)
        current_ticks += c.cycles
        if c.abort do break
    }

    return
}

reset_w65c02s :: proc(cpu: ^CPU) {
    c         := &cpu.model.(CPU_65xxx)
    oper_RST(c)
}

step_w65c02s :: proc(cpu: ^CPU_65xxx) {
    switch {
    case cpu.irq_pending:
          cpu.irq_pending = false
          switch {
          case .RESB   in cpu.irq:
            cpu.irq -= {.RESB}
            oper_RST(cpu)
          case .NMIB   in cpu.irq:
            cpu.irq -= {.NMIB}
            oper_NMI(cpu)
          case .IRQB   in cpu.irq:
            cpu.irq -= {.IRQB}
            if cpu.f.I { return }       // that makes "empty" call to _execute, but code is simpler
            oper_IRQ(cpu)
          }
    case:
          cpu.px          = false
          cpu.ir          = u8(read_m(cpu.pc, byte)) // XXX: u16?
          cpu.ab.index    = 0
          cpu.ab.bwrap    = true
          cpu.ab.pwrap    = false
          cpu.ppc         = cpu.pc

          cpu.cycles      = cycles_w65c02s[cpu.ir]
          cpu.cycles     += inc_flag_d_w65c02s[cpu.ir] if cpu.f.D else 0
          execute_w65c02s(cpu)
          cpu.cycles     += inc_px_w65c02s[cpu.ir] if cpu.px else 0
    }
    cpu.all_cycles += cpu.cycles

    // interrupts are triggered at end of current command with exception in ABORT
    // that is triggered early and causes command to be no-op with the same cycles
    // as original - but ABORT is not implemented propelry in that variant of exec
    if cpu.irq != nil {
        cpu.irq_pending = true
    }
    return
}

// eof
