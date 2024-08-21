
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

    c             := CPU_65C816{cpu = cpu, type = CPU_65C816_type.W65C02S}
    c.a            = DataRegister_65C816{size = byte}
    c.x            = DataRegister_65C816{size = byte}
    c.y            = DataRegister_65C816{size = byte}
    c.t            = DataRegister_65C816{size = byte}
    c.tb           = DataRegister_65C816{size = byte}
    c.tw           = DataRegister_65C816{size = word}
    c.pc           = AddressRegister_65C816{bwrap = true}
    c.sp           = AddressRegister_65C816{bwrap = true}
    c.ab           = AddressRegister_65C816{bwrap = true}
    c.ta           = AddressRegister_65C816{bwrap = true}
    c.state        = .FETCH
    cpu.model      = c

    // we need global because of external musashi
    localbus   = bus
    return cpu
}

clear_irq_w65c02s :: proc(cpu: ^CPU) {
    c            := &cpu.model.(CPU_65C816)
    c.irq         = {}
    c.irq_pending = false
}

setpc_w65c02s :: proc(cpu: ^CPU, address: u32) {
    c         := &cpu.model.(CPU_65C816)
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
    c := &cpu.model.(CPU_65C816)
    current_ticks : u32 = 0

    for current_ticks <= ticks {
        step_w65c02s(c)
        current_ticks += c.cycles
    }

    return
}

reset_w65c02s :: proc(cpu: ^CPU) {
    c         := &cpu.model.(CPU_65C816)
    oper_RST(c)
}

step_w65c02s :: proc(cpu: ^CPU_65C816) {
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
          cpu.ab.index    = 0                        // XXX: move to addressing modes?
          cpu.ab.pwrap    = false                    // XXX: move to addressing modes?

          //cpu.cycles      = cycles_w65c02s[cpu.ir]
          execute_w65c02s(cpu)
          cpu.cycles     += 1 if cpu.px  else 0
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


// autogenerated by convert-6502.py from w65c02s_commands-ordered.txt file
execute_w65c02s :: proc(cpu: ^CPU_65C816) {
    switch (cpu.ir) {

    case 0x00:                                  // BRK            1  7
        mode_PC_Relative              (cpu)
        oper_BRK                      (cpu)

    case 0x01:                                  // ORA ($12,X)    2  6
        mode_DP_X_Indirect            (cpu)
        oper_ORA                      (cpu)

    case 0x02:                                  // -              2  2
        mode_Illegal2                 (cpu)
        oper_ILL                      (cpu)

    case 0x03:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x04:                                  // TSB $12        2  5
        mode_DP                       (cpu)
        oper_TSB                      (cpu)

    case 0x05:                                  // ORA $12        2  3
        mode_DP                       (cpu)
        oper_ORA                      (cpu)

    case 0x06:                                  // ASL $12        2  5
        mode_DP                       (cpu)
        oper_ASL                      (cpu)

    case 0x07:                                  // RMB 0,$12      2  5
        mode_DP                       (cpu)
        oper_RMB0                     (cpu)

    case 0x08:                                  // PHP            1  3
        mode_Implied                  (cpu)
        oper_PHP                      (cpu)

    case 0x09:                                  // ORA #$12       2  2
        mode_Immediate                (cpu)
        oper_ORA                      (cpu)

    case 0x0a:                                  // ASL A          1  2
        mode_Accumulator              (cpu)
        oper_ASL_A                    (cpu)

    case 0x0b:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x0c:                                  // TSB $1234      3  6
        mode_Absolute_DBR             (cpu)
        oper_TSB                      (cpu)

    case 0x0d:                                  // ORA $1234      3  4
        mode_Absolute_DBR             (cpu)
        oper_ORA                      (cpu)

    case 0x0e:                                  // ASL $1234      3  6
        mode_Absolute_DBR             (cpu)
        oper_ASL                      (cpu)

    case 0x0f:                                  // BBR 0,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBR0                     (cpu)

    case 0x10:                                  // BPL $12        2  2+t+t*p
        mode_PC_Relative              (cpu)
        oper_BPL                      (cpu)

    case 0x11:                                  // ORA ($12),Y    2  5+p
        mode_DP_Indirect_Y            (cpu)
        oper_ORA                      (cpu)

    case 0x12:                                  // ORA ($12)      2  5
        mode_DP_Indirect              (cpu)
        oper_ORA                      (cpu)

    case 0x13:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x14:                                  // TRB $12        2  5
        mode_DP                       (cpu)
        oper_TRB                      (cpu)

    case 0x15:                                  // ORA $12,X      2  4
        mode_DP_X                     (cpu)
        oper_ORA                      (cpu)

    case 0x16:                                  // ASL $12,X      2  6
        mode_DP_X                     (cpu)
        oper_ASL                      (cpu)

    case 0x17:                                  // RMB 1,$12      2  5
        mode_DP                       (cpu)
        oper_RMB1                     (cpu)

    case 0x18:                                  // CLC            1  2
        mode_Implied                  (cpu)
        oper_CLC                      (cpu)

    case 0x19:                                  // ORA $1234,Y    3  4+p
        mode_Absolute_Y               (cpu)
        oper_ORA                      (cpu)

    case 0x1a:                                  // INC A          1  2
        mode_Implied                  (cpu)
        oper_INC                      (cpu)

    case 0x1b:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x1c:                                  // TRB $1234      3  6
        mode_Absolute_DBR             (cpu)
        oper_TRB                      (cpu)

    case 0x1d:                                  // ORA $1234,X    3  4+p
        mode_Absolute_X               (cpu)
        oper_ORA                      (cpu)

    case 0x1e:                                  // ASL $1234,X    3  6+p
        mode_Absolute_X               (cpu)
        oper_ASL                      (cpu)

    case 0x1f:                                  // BBR 1,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBR1                     (cpu)

    case 0x20:                                  // JSR $1234      3  6
        mode_Absolute_PBR             (cpu)
        oper_JSR                      (cpu)

    case 0x21:                                  // AND ($12,X)    2  6
        mode_DP_X_Indirect            (cpu)
        oper_AND                      (cpu)

    case 0x22:                                  // -              2  2
        mode_Illegal2                 (cpu)
        oper_ILL                      (cpu)

    case 0x23:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x24:                                  // BIT $12        2  3
        mode_DP                       (cpu)
        oper_BIT                      (cpu)

    case 0x25:                                  // AND $12        2  3
        mode_DP                       (cpu)
        oper_AND                      (cpu)

    case 0x26:                                  // ROL $12        2  5
        mode_DP                       (cpu)
        oper_ROL                      (cpu)

    case 0x27:                                  // RMB 2,$12      2  5
        mode_DP                       (cpu)
        oper_RMB2                     (cpu)

    case 0x28:                                  // PLP            1  4
        mode_Implied                  (cpu)
        oper_PLP                      (cpu)

    case 0x29:                                  // AND #$12       2  2
        mode_Immediate                (cpu)
        oper_AND                      (cpu)

    case 0x2a:                                  // ROL A          1  2
        mode_Accumulator              (cpu)
        oper_ROL_A                    (cpu)

    case 0x2b:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x2c:                                  // BIT $1234      3  4
        mode_Absolute_DBR             (cpu)
        oper_BIT                      (cpu)

    case 0x2d:                                  // AND $1234      3  4
        mode_Absolute_DBR             (cpu)
        oper_AND                      (cpu)

    case 0x2e:                                  // ROL $1234      3  6
        mode_Absolute_DBR             (cpu)
        oper_ROL                      (cpu)

    case 0x2f:                                  // BBR 2,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBR2                     (cpu)

    case 0x30:                                  // BMI $12        2  2+t+t*p
        mode_PC_Relative              (cpu)
        oper_BMI                      (cpu)

    case 0x31:                                  // AND ($12),Y    2  5+p
        mode_DP_Indirect_Y            (cpu)
        oper_AND                      (cpu)

    case 0x32:                                  // AND ($12)      2  5
        mode_DP_Indirect              (cpu)
        oper_AND                      (cpu)

    case 0x33:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x34:                                  // BIT $12,X      2  4
        mode_DP_X                     (cpu)
        oper_BIT                      (cpu)

    case 0x35:                                  // AND $12,X      2  4
        mode_DP_X                     (cpu)
        oper_AND                      (cpu)

    case 0x36:                                  // ROL $12,X      2  6
        mode_DP_X                     (cpu)
        oper_ROL                      (cpu)

    case 0x37:                                  // RMB 3,$12      2  5
        mode_DP                       (cpu)
        oper_RMB3                     (cpu)

    case 0x38:                                  // SEC            1  2
        mode_Implied                  (cpu)
        oper_SEC                      (cpu)

    case 0x39:                                  // AND $1234,Y    3  4+p
        mode_Absolute_Y               (cpu)
        oper_AND                      (cpu)

    case 0x3a:                                  // DEC A          1  2
        mode_Implied                  (cpu)
        oper_DEC                      (cpu)

    case 0x3b:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x3c:                                  // BIT $1234,X    3  4+p
        mode_Absolute_X               (cpu)
        oper_BIT                      (cpu)

    case 0x3d:                                  // AND $1234,X    3  4+p
        mode_Absolute_X               (cpu)
        oper_AND                      (cpu)

    case 0x3e:                                  // ROL $1234,X    3  6+p
        mode_Absolute_X               (cpu)
        oper_ROL                      (cpu)

    case 0x3f:                                  // BBR 3,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBR3                     (cpu)

    case 0x40:                                  // RTI            1  6
        mode_Implied                  (cpu)
        oper_RTI                      (cpu)

    case 0x41:                                  // EOR ($12,X)    2  6
        mode_DP_X_Indirect            (cpu)
        oper_EOR                      (cpu)

    case 0x42:                                  // -              2  2
        mode_Illegal2                 (cpu)
        oper_ILL                      (cpu)

    case 0x43:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x44:                                  // -              2  3
        mode_Illegal3                 (cpu)
        oper_ILL                      (cpu)

    case 0x45:                                  // EOR $12        2  3
        mode_DP                       (cpu)
        oper_EOR                      (cpu)

    case 0x46:                                  // LSR $12        2  5
        mode_DP                       (cpu)
        oper_LSR                      (cpu)

    case 0x47:                                  // RMB 4,$12      2  5
        mode_DP                       (cpu)
        oper_RMB4                     (cpu)

    case 0x48:                                  // PHA            1  3
        mode_Implied                  (cpu)
        oper_PHA                      (cpu)

    case 0x49:                                  // EOR #$12       2  2
        mode_Immediate                (cpu)
        oper_EOR                      (cpu)

    case 0x4a:                                  // LSR A          1  2
        mode_Accumulator              (cpu)
        oper_LSR_A                    (cpu)

    case 0x4b:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x4c:                                  // JMP $1234      3  3
        mode_Absolute_PBR             (cpu)
        oper_JMP                      (cpu)

    case 0x4d:                                  // EOR $1234      3  4
        mode_Absolute_DBR             (cpu)
        oper_EOR                      (cpu)

    case 0x4e:                                  // LSR $1234      3  6
        mode_Absolute_DBR             (cpu)
        oper_LSR                      (cpu)

    case 0x4f:                                  // BBR 4,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBR4                     (cpu)

    case 0x50:                                  // BVC $12        2  2+t+t*p
        mode_PC_Relative              (cpu)
        oper_BVC                      (cpu)

    case 0x51:                                  // EOR ($12),Y    2  5+p
        mode_DP_Indirect_Y            (cpu)
        oper_EOR                      (cpu)

    case 0x52:                                  // EOR ($12)      2  5
        mode_DP_Indirect              (cpu)
        oper_EOR                      (cpu)

    case 0x53:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x54:                                  // -              2  4
        mode_Illegal4                 (cpu)
        oper_ILL                      (cpu)

    case 0x55:                                  // EOR $12,X      2  4
        mode_DP_X                     (cpu)
        oper_EOR                      (cpu)

    case 0x56:                                  // LSR $12,X      2  6
        mode_DP_X                     (cpu)
        oper_LSR                      (cpu)

    case 0x57:                                  // RMB 5,$12      2  5
        mode_DP                       (cpu)
        oper_RMB5                     (cpu)

    case 0x58:                                  // CLI            1  2
        mode_Implied                  (cpu)
        oper_CLI                      (cpu)

    case 0x59:                                  // EOR $1234,Y    3  4+p
        mode_Absolute_Y               (cpu)
        oper_EOR                      (cpu)

    case 0x5a:                                  // PHY            1  3
        mode_Implied                  (cpu)
        oper_PHY                      (cpu)

    case 0x5b:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x5c:                                  // -              3  8
        mode_Illegal8                 (cpu)
        oper_ILL                      (cpu)

    case 0x5d:                                  // EOR $1234,X    3  4+p
        mode_Absolute_X               (cpu)
        oper_EOR                      (cpu)

    case 0x5e:                                  // LSR $1234,X    3  6+p
        mode_Absolute_X               (cpu)
        oper_LSR                      (cpu)

    case 0x5f:                                  // BBR 5,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBR5                     (cpu)

    case 0x60:                                  // RTS            1  6
        mode_Implied                  (cpu)
        oper_RTS                      (cpu)

    case 0x61:                                  // ADC ($12,X)    2  6+d
        mode_DP_X_Indirect            (cpu)
        oper_ADC                      (cpu)

    case 0x62:                                  // -              2  2
        mode_Illegal2                 (cpu)
        oper_ILL                      (cpu)

    case 0x63:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x64:                                  // STZ $12        2  3
        mode_DP                       (cpu)
        oper_STZ                      (cpu)

    case 0x65:                                  // ADC $12        2  3+d
        mode_DP                       (cpu)
        oper_ADC                      (cpu)

    case 0x66:                                  // ROR $12        2  5
        mode_DP                       (cpu)
        oper_ROR                      (cpu)

    case 0x67:                                  // RMB 6,$12      2  5
        mode_DP                       (cpu)
        oper_RMB6                     (cpu)

    case 0x68:                                  // PLA            1  4
        mode_Implied                  (cpu)
        oper_PLA                      (cpu)

    case 0x69:                                  // ADC #$12       2  2+d
        mode_Immediate                (cpu)
        oper_ADC                      (cpu)

    case 0x6a:                                  // ROR A          1  2
        mode_Accumulator              (cpu)
        oper_ROR_A                    (cpu)

    case 0x6b:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x6c:                                  // JMP ($1234)    3  5
        mode_Absolute_Indirect        (cpu)
        oper_JMP                      (cpu)

    case 0x6d:                                  // ADC $1234      3  4+d
        mode_Absolute_DBR             (cpu)
        oper_ADC                      (cpu)

    case 0x6e:                                  // ROR $1234      3  6
        mode_Absolute_DBR             (cpu)
        oper_ROR                      (cpu)

    case 0x6f:                                  // BBR 6,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBR6                     (cpu)

    case 0x70:                                  // BVS $12        2  2+t+t*p
        mode_PC_Relative              (cpu)
        oper_BVS                      (cpu)

    case 0x71:                                  // ADC ($12),Y    2  5+d+p
        mode_DP_Indirect_Y            (cpu)
        oper_ADC                      (cpu)

    case 0x72:                                  // ADC ($12)      2  5+d
        mode_DP_Indirect              (cpu)
        oper_ADC                      (cpu)

    case 0x73:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x74:                                  // STZ $12,X      2  4
        mode_DP_X                     (cpu)
        oper_STZ                      (cpu)

    case 0x75:                                  // ADC $12,X      2  4+d
        mode_DP_X                     (cpu)
        oper_ADC                      (cpu)

    case 0x76:                                  // ROR $12,X      2  6
        mode_DP_X                     (cpu)
        oper_ROR                      (cpu)

    case 0x77:                                  // RMB 7,$12      2  5
        mode_DP                       (cpu)
        oper_RMB7                     (cpu)

    case 0x78:                                  // SEI            1  2
        mode_Implied                  (cpu)
        oper_SEI                      (cpu)

    case 0x79:                                  // ADC $1234,Y    3  4+d+p
        mode_Absolute_Y               (cpu)
        oper_ADC                      (cpu)

    case 0x7a:                                  // PLY            1  4
        mode_Implied                  (cpu)
        oper_PLY                      (cpu)

    case 0x7b:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x7c:                                  // JMP ($1234,X)  3  6
        mode_Absolute_X_Indirect      (cpu)
        oper_JMP                      (cpu)

    case 0x7d:                                  // ADC $1234,X    3  4+d+p
        mode_Absolute_X               (cpu)
        oper_ADC                      (cpu)

    case 0x7e:                                  // ROR $1234,X    3  6+p
        mode_Absolute_X               (cpu)
        oper_ROR                      (cpu)

    case 0x7f:                                  // BBR 7,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBR7                     (cpu)

    case 0x80:                                  // BRA $12        2  3
        mode_Implied                  (cpu)
        oper_BRA                      (cpu)

    case 0x81:                                  // STA ($12,X)    2  6
        mode_DP_X_Indirect            (cpu)
        oper_STA                      (cpu)

    case 0x82:                                  // -              2  2
        mode_Illegal2                 (cpu)
        oper_ILL                      (cpu)

    case 0x83:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x84:                                  // STY $12        2  3
        mode_DP                       (cpu)
        oper_STY                      (cpu)

    case 0x85:                                  // STA $12        2  3
        mode_DP                       (cpu)
        oper_STA                      (cpu)

    case 0x86:                                  // STX $12        2  3
        mode_DP                       (cpu)
        oper_STX                      (cpu)

    case 0x87:                                  // SMB 0,$12      2  5
        mode_DP                       (cpu)
        oper_SMB0                     (cpu)

    case 0x88:                                  // DEY            1  2
        mode_Implied                  (cpu)
        oper_DEY                      (cpu)

    case 0x89:                                  // BIT #$12       2  2
        mode_Immediate                (cpu)
        oper_BIT                      (cpu)

    case 0x8a:                                  // TXA            1  2
        mode_Implied                  (cpu)
        oper_TXA                      (cpu)

    case 0x8b:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x8c:                                  // STY $1234      3  4
        mode_Absolute_DBR             (cpu)
        oper_STY                      (cpu)

    case 0x8d:                                  // STA $1234      3  4
        mode_Absolute_DBR             (cpu)
        oper_STA                      (cpu)

    case 0x8e:                                  // STX $1234      3  4
        mode_Absolute_DBR             (cpu)
        oper_STX                      (cpu)

    case 0x8f:                                  // BBS 0,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBS0                     (cpu)

    case 0x90:                                  // BCC $12        2  2+t+t*p
        mode_PC_Relative              (cpu)
        oper_BCC                      (cpu)

    case 0x91:                                  // STA ($12),Y    2  6
        mode_DP_Indirect_Y            (cpu)
        oper_STA                      (cpu)

    case 0x92:                                  // STA ($12)      2  5
        mode_DP_Indirect              (cpu)
        oper_STA                      (cpu)

    case 0x93:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x94:                                  // STY $12,X      2  4
        mode_DP_X                     (cpu)
        oper_STY                      (cpu)

    case 0x95:                                  // STA $12,X      2  4
        mode_DP_X                     (cpu)
        oper_STA                      (cpu)

    case 0x96:                                  // STX $12,Y      2  4
        mode_DP_Y                     (cpu)
        oper_STX                      (cpu)

    case 0x97:                                  // SMB 1,$12      2  5
        mode_DP                       (cpu)
        oper_SMB1                     (cpu)

    case 0x98:                                  // TYA            1  2
        mode_Implied                  (cpu)
        oper_TYA                      (cpu)

    case 0x99:                                  // STA $1234,Y    3  5
        mode_Absolute_Y               (cpu)
        oper_STA                      (cpu)

    case 0x9a:                                  // TXS            1  2
        mode_Implied                  (cpu)
        oper_TXS                      (cpu)

    case 0x9b:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0x9c:                                  // STZ $1234      3  4
        mode_Absolute_DBR             (cpu)
        oper_STZ                      (cpu)

    case 0x9d:                                  // STA $1234,X    3  5
        mode_Absolute_X               (cpu)
        oper_STA                      (cpu)

    case 0x9e:                                  // STZ $1234,X    3  5
        mode_Absolute_X               (cpu)
        oper_STZ                      (cpu)

    case 0x9f:                                  // BBS 1,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBS1                     (cpu)

    case 0xa0:                                  // LDY #$12       2  2
        mode_Immediate                (cpu)
        oper_LDY                      (cpu)

    case 0xa1:                                  // LDA ($12,X)    2  6
        mode_DP_X_Indirect            (cpu)
        oper_LDA                      (cpu)

    case 0xa2:                                  // LDX #$12       2  2
        mode_Immediate                (cpu)
        oper_LDX                      (cpu)

    case 0xa3:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0xa4:                                  // LDY $12        2  3
        mode_DP                       (cpu)
        oper_LDY                      (cpu)

    case 0xa5:                                  // LDA $12        2  3
        mode_DP                       (cpu)
        oper_LDA                      (cpu)

    case 0xa6:                                  // LDX $12        2  3
        mode_DP                       (cpu)
        oper_LDX                      (cpu)

    case 0xa7:                                  // SMB 2,$12      2  5
        mode_DP                       (cpu)
        oper_SMB2                     (cpu)

    case 0xa8:                                  // TAY            1  2
        mode_Implied                  (cpu)
        oper_TAY                      (cpu)

    case 0xa9:                                  // LDA #$12       2  2
        mode_Immediate                (cpu)
        oper_LDA                      (cpu)

    case 0xaa:                                  // TAX            1  2
        mode_Implied                  (cpu)
        oper_TAX                      (cpu)

    case 0xab:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0xac:                                  // LDY $1234      3  4
        mode_Absolute_DBR             (cpu)
        oper_LDY                      (cpu)

    case 0xad:                                  // LDA $1234      3  4
        mode_Absolute_DBR             (cpu)
        oper_LDA                      (cpu)

    case 0xae:                                  // LDX $1234      3  4
        mode_Absolute_DBR             (cpu)
        oper_LDX                      (cpu)

    case 0xaf:                                  // BBS 2,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBS2                     (cpu)

    case 0xb0:                                  // BCS $12        2  2+t+t*p
        mode_PC_Relative              (cpu)
        oper_BCS                      (cpu)

    case 0xb1:                                  // LDA ($12),Y    2  5+p
        mode_DP_Indirect_Y            (cpu)
        oper_LDA                      (cpu)

    case 0xb2:                                  // LDA ($12)      2  5
        mode_DP_Indirect              (cpu)
        oper_LDA                      (cpu)

    case 0xb3:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0xb4:                                  // LDY $12,X      2  4
        mode_DP_X                     (cpu)
        oper_LDY                      (cpu)

    case 0xb5:                                  // LDA $12,X      2  4
        mode_DP_X                     (cpu)
        oper_LDA                      (cpu)

    case 0xb6:                                  // LDX $12,Y      2  4
        mode_DP_Y                     (cpu)
        oper_LDX                      (cpu)

    case 0xb7:                                  // SMB 3,$12      2  5
        mode_DP                       (cpu)
        oper_SMB3                     (cpu)

    case 0xb8:                                  // CLV            1  2
        mode_Implied                  (cpu)
        oper_CLV                      (cpu)

    case 0xb9:                                  // LDA $1234,Y    3  4+p
        mode_Absolute_Y               (cpu)
        oper_LDA                      (cpu)

    case 0xba:                                  // TSX            1  2
        mode_Implied                  (cpu)
        oper_TSX                      (cpu)

    case 0xbb:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0xbc:                                  // LDY $1234,X    3  4+p
        mode_Absolute_X               (cpu)
        oper_LDY                      (cpu)

    case 0xbd:                                  // LDA $1234,X    3  4+p
        mode_Absolute_X               (cpu)
        oper_LDA                      (cpu)

    case 0xbe:                                  // LDX $1234,Y    3  4+p
        mode_Absolute_Y               (cpu)
        oper_LDX                      (cpu)

    case 0xbf:                                  // BBS 3,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBS3                     (cpu)

    case 0xc0:                                  // CPY #$12       2  2
        mode_Immediate                (cpu)
        oper_CPY                      (cpu)

    case 0xc1:                                  // CMP ($12,X)    2  6
        mode_DP_X_Indirect            (cpu)
        oper_CMP                      (cpu)

    case 0xc2:                                  // -              2  2
        mode_Illegal2                 (cpu)
        oper_ILL                      (cpu)

    case 0xc3:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0xc4:                                  // CPY $12        2  3
        mode_DP                       (cpu)
        oper_CPY                      (cpu)

    case 0xc5:                                  // CMP $12        2  3
        mode_DP                       (cpu)
        oper_CMP                      (cpu)

    case 0xc6:                                  // DEC $12        2  5
        mode_DP                       (cpu)
        oper_DEC                      (cpu)

    case 0xc7:                                  // SMB 4,$12      2  5
        mode_DP                       (cpu)
        oper_SMB4                     (cpu)

    case 0xc8:                                  // INY            1  2
        mode_Implied                  (cpu)
        oper_INY                      (cpu)

    case 0xc9:                                  // CMP #$12       2  2
        mode_Immediate                (cpu)
        oper_CMP                      (cpu)

    case 0xca:                                  // DEX            1  2
        mode_Implied                  (cpu)
        oper_DEX                      (cpu)

    case 0xcb:                                  // WAI            1  2
        mode_Implied                  (cpu)
        oper_WAI                      (cpu)

    case 0xcc:                                  // CPY $1234      3  4
        mode_Absolute_DBR             (cpu)
        oper_CPY                      (cpu)

    case 0xcd:                                  // CMP $1234      3  4
        mode_Absolute_DBR             (cpu)
        oper_CMP                      (cpu)

    case 0xce:                                  // DEC $1234      3  6
        mode_Absolute_DBR             (cpu)
        oper_DEC                      (cpu)

    case 0xcf:                                  // BBS 4,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBS4                     (cpu)

    case 0xd0:                                  // BNE $12        2  2+t+t*p
        mode_PC_Relative              (cpu)
        oper_BNE                      (cpu)

    case 0xd1:                                  // CMP ($12),Y    2  5+p
        mode_DP_Indirect_Y            (cpu)
        oper_CMP                      (cpu)

    case 0xd2:                                  // CMP ($12)      2  5
        mode_DP_Indirect              (cpu)
        oper_CMP                      (cpu)

    case 0xd3:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0xd4:                                  // -              2  4
        mode_Illegal4                 (cpu)
        oper_ILL                      (cpu)

    case 0xd5:                                  // CMP $12,X      2  4
        mode_DP_X                     (cpu)
        oper_CMP                      (cpu)

    case 0xd6:                                  // DEC $12,X      2  6
        mode_DP_X                     (cpu)
        oper_DEC                      (cpu)

    case 0xd7:                                  // SMB 5,$12      2  5
        mode_DP                       (cpu)
        oper_SMB5                     (cpu)

    case 0xd8:                                  // CLD            1  2
        mode_Implied                  (cpu)
        oper_CLD                      (cpu)

    case 0xd9:                                  // CMP $1234,Y    3  4+p
        mode_Absolute_Y               (cpu)
        oper_CMP                      (cpu)

    case 0xda:                                  // PHX            1  3
        mode_Implied                  (cpu)
        oper_PHX                      (cpu)

    case 0xdb:                                  // STP            1  3
        mode_Implied                  (cpu)
        oper_STP                      (cpu)

    case 0xdc:                                  // -              3  4
        mode_Illegal4                 (cpu)
        oper_ILL                      (cpu)

    case 0xdd:                                  // CMP $1234,X    3  4+p
        mode_Absolute_X               (cpu)
        oper_CMP                      (cpu)

    case 0xde:                                  // DEC $1234,X    3  7
        mode_Absolute_X               (cpu)
        oper_DEC                      (cpu)

    case 0xdf:                                  // BBS 5,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBS5                     (cpu)

    case 0xe0:                                  // CPX #$12       2  2
        mode_Immediate                (cpu)
        oper_CPX                      (cpu)

    case 0xe1:                                  // SBC ($12,X)    2  6+d
        mode_DP_X_Indirect            (cpu)
        oper_SBC                      (cpu)

    case 0xe2:                                  // -              2  2
        mode_Illegal2                 (cpu)
        oper_ILL                      (cpu)

    case 0xe3:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0xe4:                                  // CPX $12        2  3
        mode_DP                       (cpu)
        oper_CPX                      (cpu)

    case 0xe5:                                  // SBC $12        2  3+d
        mode_DP                       (cpu)
        oper_SBC                      (cpu)

    case 0xe6:                                  // INC $12        2  5
        mode_DP                       (cpu)
        oper_INC                      (cpu)

    case 0xe7:                                  // SMB 6,$12      2  5
        mode_DP                       (cpu)
        oper_SMB6                     (cpu)

    case 0xe8:                                  // INX            1  2
        mode_Implied                  (cpu)
        oper_INX                      (cpu)

    case 0xe9:                                  // SBC #$12       2  2+d
        mode_Immediate                (cpu)
        oper_SBC                      (cpu)

    case 0xea:                                  // NOP            1  2
        mode_Implied                  (cpu)
        oper_NOP                      (cpu)

    case 0xeb:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0xec:                                  // CPX $1234      3  4
        mode_Absolute_DBR             (cpu)
        oper_CPX                      (cpu)

    case 0xed:                                  // SBC $1234      3  4+d
        mode_Absolute_DBR             (cpu)
        oper_SBC                      (cpu)

    case 0xee:                                  // INC $1234      3  6
        mode_Absolute_DBR             (cpu)
        oper_INC                      (cpu)

    case 0xef:                                  // BBS 6,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBS6                     (cpu)

    case 0xf0:                                  // BEQ $12        2  2+t+t*p
        mode_PC_Relative              (cpu)
        oper_BEQ                      (cpu)

    case 0xf1:                                  // SBC ($12),Y    2  5+d+p
        mode_DP_Indirect_Y            (cpu)
        oper_SBC                      (cpu)

    case 0xf2:                                  // SBC ($12)      2  5+d
        mode_DP_Indirect              (cpu)
        oper_SBC                      (cpu)

    case 0xf3:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0xf4:                                  // -              2  4
        mode_Illegal4                 (cpu)
        oper_ILL                      (cpu)

    case 0xf5:                                  // SBC $12,X      2  4+d
        mode_DP_X                     (cpu)
        oper_SBC                      (cpu)

    case 0xf6:                                  // INC $12,X      2  6
        mode_DP_X                     (cpu)
        oper_INC                      (cpu)

    case 0xf7:                                  // SMB 7,$12      2  5
        mode_DP                       (cpu)
        oper_SMB7                     (cpu)

    case 0xf8:                                  // SED            1  2
        mode_Implied                  (cpu)
        oper_SED                      (cpu)

    case 0xf9:                                  // SBC $1234,Y    3  4+d+p
        mode_Absolute_Y               (cpu)
        oper_SBC                      (cpu)

    case 0xfa:                                  // PLX            1  4
        mode_Implied                  (cpu)
        oper_PLX                      (cpu)

    case 0xfb:                                  // -              1  1
        mode_Illegal1                 (cpu)
        oper_ILL                      (cpu)

    case 0xfc:                                  // -              3  4
        mode_Illegal4                 (cpu)
        oper_ILL                      (cpu)

    case 0xfd:                                  // SBC $1234,X    3  4+d+p
        mode_Absolute_X               (cpu)
        oper_SBC                      (cpu)

    case 0xfe:                                  // INC $1234,X    3  7
        mode_Absolute_X               (cpu)
        oper_INC                      (cpu)

    case 0xff:                                  // BBS 7,$12,$34  3  5+t+t*p
        mode_ZP_and_Relative          (cpu)
        oper_BBS7                     (cpu)


    }
}

