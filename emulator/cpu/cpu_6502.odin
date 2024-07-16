
package cpu

import "base:runtime"
import "core:fmt"
import "core:log"
import "emulator:bus"
import "emulator:pic"

import "lib:emu"

import "core:prof/spall"

CPU_6502_type :: enum {
    W65C02
}

CPU_m6502 :: struct {
    using cpu: ^CPU, 

    type: CPU_6502_type,
    pc: u16,             // Program Counter
    sp: u8,              // Stack Pointer

    a:  u8,
    x:  u8,
    y:  u8,

    N:  bool,
    V:  bool,
    U:  bool,          // unused bit5, always true
    B:  bool,
    D:  bool,
    I:  bool,
    Z:  bool,
    C:  bool,

    ab:     u16,       // address bus address
    ir:     u8,        // instruction register
    wdm:    bool,      // denotes support for non-standard WDM (0x42) command
    abort:  bool,      // emulator should abort?
    ppc:    u16,       // previous PC - for debug purposes
   step:    u8,        // step for processing current opcode 
  steps:    int,       // total number of steps from reset
    px:     bool,        // page was crossed?

    f0:    bool,      // temporary flag
    b0:    u8,        // temporary register
    b1:    u8,        // secondary temporary register
    w0:    u16,       // temporary register
    w1:    u16,       // temporary register (2)

    wdm_mode:   bool
}

// XXX - parametrize CPU type!
m6502_make :: proc (name: string, bus: ^bus.Bus) -> ^CPU {

    cpu           := new(CPU)
    cpu.name       = name
    cpu.setpc      = m6502_setpc
    cpu.reset      = m6502_reset
    cpu.exec       = m6502_exec
    cpu.clear_irq  = m6502_clear_irq
    cpu.bus        = bus
    cpu.cycles     = 0
    c             := CPU_m6502{cpu = cpu, type = CPU_6502_type.W65C02}
    cpu.model      = c

    // we need global because of external musashi (XXX - maybe whole CPU?)
    localbus   = bus

    //m6502_init();
    return cpu
}

m6502_setpc :: proc(cpu: ^CPU, address: u32) {
    c    := &cpu.model.(CPU_m6502)
    c.pc  = u16(address)
    return 
}

m6502_reset :: proc(cpu: ^CPU) {
    return
}

m6502_clear_irq :: proc(cpu: ^CPU) {
    //if localbus.pic.irq_clear {
    //    log.debugf("%s IRQ clear", cpu.name)
    //    localbus.pic.irq_clear  = false
    //    localbus.pic.irq_active = false
    //    localbus.pic.current    = pic.IRQ.NONE
    //    m68k_set_irq(uint(pic.IRQ.NONE))
    //}
}

m6502_exec :: proc(cpu: ^CPU, ticks: u32 = 1000) {
    c := &cpu.model.(CPU_m6502)
    current_ticks : u32 = 0

    for current_ticks < ticks {
        // 1. check if there is irq to clear
        //if localbus.pic.irq_clear {
        //    log.debugf("%s IRQ clear", cpu.name)
        //    localbus.pic.irq_clear  = false
        //    localbus.pic.irq_active = false
        //    localbus.pic.current    = pic.IRQ.NONE
        //    m68k_set_irq(uint(pic.IRQ.NONE))
        //}

        // 2. recalculate interupts
        // XXX: implement it

        // 3. check if there is a pending irq?
        //if localbus.pic.irq_active == false && localbus.pic.current != pic.IRQ.NONE {
        //    log.debugf("%s IRQ should be set!", cpu.name)
        //    localbus.pic.irq_active = true
        //    log.debugf("IRQ active from exec %v irq %v", localbus.pic.irq_active, localbus.pic.irq)
        //    m68k_set_irq(localbus.pic.irq)
        //}

        cycles        := m6502_execute(c)
        c.cycles      += cycles
        current_ticks += cycles
        //log.debugf("%s execute %d cycles", cpu.name, current_ticks)
    }
    //log.debugf("%s execute %d cycles", cpu.name, cpu.cycles)
    return
}

m6502_execute :: proc(cpu: ^CPU_m6502) -> (cycles: u32) {
    cpu.px    = false
    cpu.ir    = read_b(cpu.pc)

    m6502_run_opcode(cpu)

    // XXX: create OP table!
    //cycles    = op_table[cpu.ir].cycles
    //cycles   += op_table[cpu.ir].p         if px else 0
    return cycles
}

// --------------------------------------------------------------------
// procedures for memory transfer - there are two
// of any kind, addresed by 16 a 8-bit addresses
// XXX: maybe such conversion should be made on bus
// level?

// read byte and return it as low part of word
read_lw :: #force_inline proc (addr: u16) -> u16 {
    return u16(localbus->read(.bits_8, u32(addr)))
}

read_lb :: #force_inline proc (addr:  u8) -> u16 {
    return u16(localbus->read(.bits_8, u32(addr)))
}

read_l  :: proc {read_lw, read_lb}

// read byte and return it as high part of word
read_hw :: #force_inline proc (addr: u16) -> u16 {
    return u16(localbus->read(.bits_8, u32(addr))) << 8
}

read_hb :: #force_inline proc (addr:  u8) -> u16 {
    return u16(localbus->read(.bits_8, u32(addr))) << 8
}

read_h  :: proc {read_hw, read_hb}

// just read read byte and return it...
read_bw :: #force_inline proc (addr: u16) ->  u8 {
    return u8(localbus->read(.bits_8, u32(addr)))
}

read_bb :: #force_inline proc (addr:  u8) ->  u8 {
    return u8(localbus->read(.bits_8, u32(addr)))
}

read_b  :: proc {read_bw, read_bb}

// add unsigned byte to word or byte
addu_w :: #force_inline proc (a: u16, b: u8) ->  u16 {
    return a + u16(b)
}

addu_b :: #force_inline proc (a: u8, b: u8) ->  u8 {
    return a + b
}


// add signed byte to word
adds_w :: #force_inline proc (a: u16, b: u8) ->  u16 {
    if b >= 0x80 {
        return a + u16(b) - 0x100
    } else {
        return a + u16(b)
    }
}

set_px :: #force_inline proc (a: u16, b: u16) ->  bool {
    return ((a & 0xFF00) != (b & 0xFF00))
}

//             LDA $0800
mode_Absolute               :: #force_inline proc (using c: ^CPU_m6502) { 
    ab    = read_l( pc+1 )
    ab   |= read_h( pc+2 )
    pc   += 2
}

//             JMP ($1234,X)
mode_Absolute_X_Indirect    :: #force_inline proc (using c: ^CPU_m6502) {
    w0    = read_l( pc+1   )
    w0   |= read_h( pc+2   )
    w0   += addu_w( w0,  x )
    ab    = read_l( w0     )
    ab   |= read_h( w0+1   )
    pc   += 2
}

//              ORA $1234,X
mode_Absolute_X                :: #force_inline proc (using c: ^CPU_m6502) {
    ab    = read_l( pc+1   )
    ab   |= read_h( pc+2   )
    w0    = ab
    ab   += addu_w( ab,  x )
    px    = set_px( ab, w0 )
    pc   += 2
}

//              ORA $1234,Y
mode_Absolute_Y             :: #force_inline proc (using c: ^CPU_m6502) {
    ab    = read_l( pc+1   )
    ab   |= read_h( pc+2   )
    w0    = ab
    ab   += addu_w( ab,  y )
    px    = set_px( ab, w0 )
    pc   += 2
}

//              JMP ($1234)
mode_Absolute_Indirect      :: #force_inline proc (using c: ^CPU_m6502) { 
    w0    = read_l( pc+1   )
    w0   |= read_h( pc+2   )
    ab    = read_l( w0     )
    ab   |= read_h( w0+1   )
    pc   += 2
}

//              INC
mode_Accumulator            :: #force_inline proc (using c: ^CPU_m6502) {
}

//              LDX #$12
mode_Immediate              :: #force_inline proc (using c: ^CPU_m6502) {
    pc   += 1
    ab    = pc
}

//              SEC
@private
mode_Implied                :: #force_inline proc (using c: ^CPU_m6502) {
}

//              BBR 0,$12,$34       - Rockwell 65C02 and WDC 65C02
@private
mode_ZP_and_Relative        :: #force_inline proc (using c: ^CPU_m6502) {
    pc   += 1
    w0    = read_l( pc     )        // ZP address to read
    b0    = read_b( w0     )        // preserve for oper_ processing

    pc   += 1
    b1    = read_b( pc     )        // relative jump size
    ab    = adds_w( pc, b1 )        // calculate jump - add signed byte
    px    = set_px( ab, pc )
}

//              BNE $10
@private
mode_PC_Relative            :: #force_inline proc (using c: ^CPU_m6502) {
    pc   += 1
    b1    = read_b( pc     )        // relative jump size
    ab    = adds_w( pc, b1 )        // calculate jump - add signed byte
    px    = set_px( ab, pc )
}

//              LDA $10
@private
mode_ZP                     :: #force_inline proc (using c: ^CPU_m6502) {
    pc   += 1
    ab    = read_l( pc     )
}

//              STA ($12,X)
@private
mode_ZP_X_Indirect          :: #force_inline proc (using c: ^CPU_m6502) {
    pc   += 1
    b0    = read_b( pc     )  
    b0    = addu_b( b0,  x )
    ab    = read_l( b0     )
    b0   += 1
    ab   |= read_h( b0     )
}

//              ASL $12,X
@private
mode_ZP_X                   :: #force_inline proc (using c: ^CPU_m6502) {
    pc   += 1
    ab    = read_l( pc     )  
    ab    = addu_w( ab,  x )
    ab   &= 0x00ff              // ZP wrap
}

//              ASL $12,Y
@private
mode_ZP_Y                   :: #force_inline proc (using c: ^CPU_m6502) {
    pc   += 1
    ab    = read_l( pc     )  
    ab    = addu_w( ab,  y )
    ab   &= 0x00ff              // ZP wrap
}

//              AND ($12)
@private
mode_ZP_Indirect            :: #force_inline proc (using c: ^CPU_m6502) {
    pc   += 1
    w0    = read_l( pc     )  
    ab    = read_l( w0     )  
    ab   |= read_h( w0+1   )  
}

//              AND ($12),Y
@private
mode_ZP_Indirect_Y          :: #force_inline proc (using c: ^CPU_m6502) {
    pc   += 1
    w0    = read_l( pc     )  
    ab    = read_l( w0     )  
    ab   |= read_h( w0+1   )  
    w0    = ab
    ab    = addu_w( ab,  y )
    px    = set_px( ab, w0 )
}


@private
oper_ADC                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_AND                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_ASL                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_ASL_A                  :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBR0                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBR1                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBR2                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBR3                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBR4                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBR5                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBR6                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBR7                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBS0                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBS1                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBS2                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBS3                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBS4                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBS5                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBS6                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BBS7                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BCC                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BCS                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BEQ                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BIT                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BIT_IMM                :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BMI                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BNE                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BPL                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BRA                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BRK                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BVC                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_BVS                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_CLC                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_CLD                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_CLI                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_CLV                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_CMP                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_CPX                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_CPY                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_DEC                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_DEC_A                  :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_DEX                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_DEY                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_EOR                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_ILL1                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_ILL2                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_ILL3                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_INC                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_INC_A                  :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_INX                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_INY                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_JMP                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_JSR                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_LDA                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_LDX                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_LDY                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_LSR                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_LSR_A                  :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_NOP                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_ORA                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_PHA                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_PHP                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_PHX                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_PHY                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_PLA                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_PLP                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_PLX                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_PLY                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_RMB0                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_RMB1                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_RMB2                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_RMB3                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_RMB4                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_RMB5                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_RMB6                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_RMB7                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_ROL                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_ROL_A                  :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_ROR                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_ROR_A                  :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_RTI                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_RTS                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_SBC                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_SEC                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_SED                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_SEI                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_SMB0                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_SMB1                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_SMB2                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_SMB3                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_SMB4                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_SMB5                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_SMB6                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_SMB7                   :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_STA                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_STP                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_STX                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_STY                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_STZ                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_TAX                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_TAY                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_TRB                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_TSB                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_TSX                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_TXA                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_TXS                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_TYA                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_WAI                    :: #force_inline proc (using c: ^CPU_m6502) { }
@private
oper_WDM                    :: #force_inline proc (using c: ^CPU_m6502) { }



m6502_run_opcode :: proc(cpu: ^CPU_m6502) {
    switch (cpu.ir) {
    case 0x00:                                 // BRK Break       7
       mode_Implied             (cpu)
       oper_BRK                 (cpu)
  
    case 0x01:                                 // ORA ($12,X)     6
       mode_ZP_X_Indirect       (cpu)
       oper_ORA                 (cpu)
  
    case 0x02:                                 // ILL             2
       mode_Implied             (cpu)
       oper_ILL2                (cpu)
  
    case 0x03:                                 // ILL W65C02      1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x04:                                 // TSB $12         5
       mode_ZP                  (cpu)
       oper_TSB                 (cpu)
  
    case 0x05:                                 // ORA $12         3
       mode_ZP                  (cpu)
       oper_ORA                 (cpu)
  
    case 0x06:                                 // ASL $12         5
       mode_ZP                  (cpu)
       oper_ASL                 (cpu)
  
    case 0x07:                                 // RMB 0,$12       5
       mode_ZP                  (cpu)
       oper_RMB0                (cpu)
  
    case 0x08:                                 // PHP SR          3
       mode_Implied             (cpu)
       oper_PHP                 (cpu)
  
    case 0x09:                                 // ORA #$12        2
       mode_Immediate           (cpu)
       oper_ORA                 (cpu)
  
    case 0x0A:                                 // ASL A           2
       mode_Accumulator         (cpu)
       oper_ASL_A               (cpu)
  
    case 0x0B:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x0C:                                 // TSB $1234       6
       mode_Absolute            (cpu)
       oper_TSB                 (cpu)
  
    case 0x0D:                                 // ORA $1234       4
       mode_Absolute            (cpu)
       oper_ORA                 (cpu)
  
    case 0x0E:                                 // ASL $1234       6
       mode_Absolute            (cpu)
       oper_ASL                 (cpu)
  
    case 0x0F:                                 // BBR 0,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBR0                (cpu)
  
    case 0x10:                                 // BPL $12         2+t+t*p
       mode_PC_Relative         (cpu)
       oper_BPL                 (cpu)
  
    case 0x11:                                 // ORA ($12),Y     5+p
       mode_ZP_Indirect_Y       (cpu)
       oper_ORA                 (cpu)
  
    case 0x12:                                 // ORA ($12)       5
       mode_ZP_Indirect         (cpu)
       oper_ORA                 (cpu)
  
    case 0x13:                                 // ILL NOPs.       1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x14:                                 // TRB $12         5
       mode_ZP                  (cpu)
       oper_TRB                 (cpu)
  
    case 0x15:                                 // ORA $12,X       4
       mode_ZP_X                (cpu)
       oper_ORA                 (cpu)
  
    case 0x16:                                 // ASL $12,X       6
       mode_ZP_X                (cpu)
       oper_ASL                 (cpu)
  
    case 0x17:                                 // RMB 1,$12       5
       mode_ZP                  (cpu)
       oper_RMB1                (cpu)
  
    case 0x18:                                 // CLC 0           2
       mode_Implied             (cpu)
       oper_CLC                 (cpu)
  
    case 0x19:                                 // ORA $1234,Y     4+p
       mode_Absolute_Y          (cpu)
       oper_ORA                 (cpu)
  
    case 0x1A:                                 // INC A           2
       mode_Accumulator         (cpu)
       oper_INC_A               (cpu)
  
    case 0x1B:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x1C:                                 // TRB $1234       6
       mode_Absolute            (cpu)
       oper_TRB                 (cpu)
  
    case 0x1D:                                 // ORA $1234,X     4+p
       mode_Absolute_X          (cpu)
       oper_ORA                 (cpu)
  
    case 0x1E:                                 // ASL $1234,X     6+p
       mode_Absolute_X          (cpu)
       oper_ASL                 (cpu)
  
    case 0x1F:                                 // BBR 1,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBR1                (cpu)
  
    case 0x20:                                 // JSR $1234       6
       mode_Absolute            (cpu)
       oper_JSR                 (cpu)
  
    case 0x21:                                 // AND ($12,X)     6
       mode_ZP_X_Indirect       (cpu)
       oper_AND                 (cpu)
  
    case 0x22:                                 // ILL             2
       mode_Implied             (cpu)
       oper_ILL2                (cpu)
  
    case 0x23:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x24:                                 // BIT $12         3
       mode_ZP                  (cpu)
       oper_BIT                 (cpu)
  
    case 0x25:                                 // AND $12         3
       mode_ZP                  (cpu)
       oper_AND                 (cpu)
  
    case 0x26:                                 // ROL $12         5
       mode_ZP                  (cpu)
       oper_ROL                 (cpu)
  
    case 0x27:                                 // RMB 2,$12       5
       mode_ZP                  (cpu)
       oper_RMB2                (cpu)
  
    case 0x28:                                 // PLP SP          4
       mode_Implied             (cpu)
       oper_PLP                 (cpu)
  
    case 0x29:                                 // AND #$12        2
       mode_Immediate           (cpu)
       oper_AND                 (cpu)
  
    case 0x2A:                                 // ROL A           2
       mode_Accumulator         (cpu)
       oper_ROL_A               (cpu)
  
    case 0x2B:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x2C:                                 // BIT $1234       4
       mode_Absolute            (cpu)
       oper_BIT                 (cpu)
  
    case 0x2D:                                 // AND $1234       4
       mode_Absolute            (cpu)
       oper_AND                 (cpu)
  
    case 0x2E:                                 // ROL $1234       6
       mode_Absolute            (cpu)
       oper_ROL                 (cpu)
  
    case 0x2F:                                 // BBR 2,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBR2                (cpu)
  
    case 0x30:                                 // BMI $12         2+t+t*p
       mode_PC_Relative         (cpu)
       oper_BMI                 (cpu)
  
    case 0x31:                                 // AND ($12),Y     5+p
       mode_ZP_Indirect_Y       (cpu)
       oper_AND                 (cpu)
  
    case 0x32:                                 // AND ($12)       5
       mode_ZP_Indirect         (cpu)
       oper_AND                 (cpu)
  
    case 0x33:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x34:                                 // BIT $12,X       4
       mode_ZP_X                (cpu)
       oper_BIT                 (cpu)
  
    case 0x35:                                 // AND $12,X       4
       mode_ZP_X                (cpu)
       oper_AND                 (cpu)
  
    case 0x36:                                 // ROL $12,X       6
       mode_ZP_X                (cpu)
       oper_ROL                 (cpu)
  
    case 0x37:                                 // RMB 3,$12       5
       mode_ZP                  (cpu)
       oper_RMB3                (cpu)
  
    case 0x38:                                 // SEC 1           2
       mode_Implied             (cpu)
       oper_SEC                 (cpu)
  
    case 0x39:                                 // AND $1234,Y     4+p
       mode_Absolute_Y          (cpu)
       oper_AND                 (cpu)
  
    case 0x3A:                                 // DEC A           2
       mode_Accumulator         (cpu)
       oper_DEC_A               (cpu)
  
    case 0x3B:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x3C:                                 // BIT $1234,X     4+p
       mode_Absolute_X          (cpu)
       oper_BIT                 (cpu)
  
    case 0x3D:                                 // AND $1234,X     4+p
       mode_Absolute_X          (cpu)
       oper_AND                 (cpu)
  
    case 0x3E:                                 // ROL $1234,X     6+p
       mode_Absolute_X          (cpu)
       oper_ROL                 (cpu)
  
    case 0x3F:                                 // BBR 3,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBR3                (cpu)
  
    case 0x40:                                 // RTI Return      6
       mode_Implied             (cpu)
       oper_RTI                 (cpu)
  
    case 0x41:                                 // EOR ($12,X)     6
       mode_ZP_X_Indirect       (cpu)
       oper_EOR                 (cpu)
  
    // WARNING: there is no WDM opcode on W65C02S
    //          it is a non-standard extension for debug purposes
    case 0x42:
        if cpu.wdm_mode {
            mode_Immediate      (cpu)
            oper_WDM            (cpu)              // WDM #$12
        }  else {
            oper_ILL2           (cpu)              // ILL             2
        }
  
    case 0x43:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x44:                                 // ILL             3
       mode_Implied             (cpu)
       oper_ILL2                (cpu)
  
    case 0x45:                                 // EOR $12         3
       mode_ZP                  (cpu)
       oper_EOR                 (cpu)
  
    case 0x46:                                 // LSR $12         5
       mode_ZP                  (cpu)
       oper_LSR                 (cpu)
  
    case 0x47:                                 // RMB 4,$12       5
       mode_ZP                  (cpu)
       oper_RMB4                (cpu)
  
    case 0x48:                                 // PHA A           3
       mode_Implied             (cpu)
       oper_PHA                 (cpu)
  
    case 0x49:                                 // EOR #$12        2
       mode_Immediate           (cpu)
       oper_EOR                 (cpu)
  
    case 0x4A:                                 // LSR A           2
       mode_Accumulator         (cpu)
       oper_LSR_A               (cpu)
  
    case 0x4B:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x4C:                                 // JMP $1234       3
       mode_Absolute            (cpu)
       oper_JMP                 (cpu)
  
    case 0x4D:                                 // EOR $1234       4
       mode_Absolute            (cpu)
       oper_EOR                 (cpu)
  
    case 0x4E:                                 // LSR $1234       6
       mode_Absolute            (cpu)
       oper_LSR                 (cpu)
  
    case 0x4F:                                 // BBR 4,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBR4                (cpu)
  
    case 0x50:                                 // BVC $12         2+t+t*p
       mode_PC_Relative         (cpu)
       oper_BVC                 (cpu)
  
    case 0x51:                                 // EOR ($12),Y     5+p
       mode_ZP_Indirect_Y       (cpu)
       oper_EOR                 (cpu)
  
    case 0x52:                                 // EOR ($12)       5
       mode_ZP_Indirect         (cpu)
       oper_EOR                 (cpu)
  
    case 0x53:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x54:                                 // ILL             4
       mode_Implied             (cpu)
       oper_ILL2                (cpu)
  
    case 0x55:                                 // EOR $12,X       4
       mode_ZP_X                (cpu)
       oper_EOR                 (cpu)
  
    case 0x56:                                 // LSR $12,X       6
       mode_ZP_X                (cpu)
       oper_LSR                 (cpu)
  
    case 0x57:                                 // RMB 5,$12       5
       mode_ZP                  (cpu)
       oper_RMB5                (cpu)
  
    case 0x58:                                 // CLI 0           2
       mode_Implied             (cpu)
       oper_CLI                 (cpu)
  
    case 0x59:                                 // EOR $1234,Y     4+p
       mode_Absolute_Y          (cpu)
       oper_EOR                 (cpu)
  
    case 0x5A:                                 // PHY Y           3
       mode_Implied             (cpu)
       oper_PHY                 (cpu)
  
    case 0x5B:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x5C:                                 // ILL             8
       mode_Implied             (cpu)
       oper_ILL3                (cpu)
  
    case 0x5D:                                 // EOR $1234,X     4+p
       mode_Absolute_X          (cpu)
       oper_EOR                 (cpu)
  
    case 0x5E:                                 // LSR $1234,X     6+p
       mode_Absolute_X          (cpu)
       oper_LSR                 (cpu)
  
    case 0x5F:                                 // BBR 5,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBR5                (cpu)
  
    case 0x60:                                 // RTS Return      6
       mode_Implied             (cpu)
       oper_RTS                 (cpu)
  
    case 0x61:                                 // ADC ($12,X)     6+d
       mode_ZP_X_Indirect       (cpu)
       oper_ADC                 (cpu)
  
    case 0x62:                                 // ILL             2
       mode_Implied             (cpu)
       oper_ILL2                (cpu)
  
    case 0x63:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x64:                                 // STZ $12         3
       mode_ZP                  (cpu)
       oper_STZ                 (cpu)
  
    case 0x65:                                 // ADC $12         3+d
       mode_ZP                  (cpu)
       oper_ADC                 (cpu)
  
    case 0x66:                                 // ROR $12         5
       mode_ZP                  (cpu)
       oper_ROR                 (cpu)
  
    case 0x67:                                 // RMB 6,$12       5
       mode_ZP                  (cpu)
       oper_RMB6                (cpu)
  
    case 0x68:                                 // PLA SP          4
       mode_Implied             (cpu)
       oper_PLA                 (cpu)
  
    case 0x69:                                 // ADC #$12        2+d
       mode_Immediate           (cpu)
       oper_ADC                 (cpu)
  
    case 0x6A:                                 // ROR A           2
       mode_Accumulator         (cpu)
       oper_ROR_A               (cpu)
  
    case 0x6B:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x6C:                                 // JMP ($1234)     5
       mode_Absolute_Indirect   (cpu)
       oper_JMP                 (cpu)
  
    case 0x6D:                                 // ADC $1234       4+d
       mode_Absolute            (cpu)
       oper_ADC                 (cpu)
  
    case 0x6E:                                 // ROR $1234       6
       mode_Absolute            (cpu)
       oper_ROR                 (cpu)
  
    case 0x6F:                                 // BBR 6,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBR6                (cpu)
  
    case 0x70:                                 // BVS $12         2+t+t*p
       mode_PC_Relative         (cpu)
       oper_BVS                 (cpu)
  
    case 0x71:                                 // ADC ($12),Y     5+d+p
       mode_ZP_Indirect_Y       (cpu)
       oper_ADC                 (cpu)
  
    case 0x72:                                 // ADC ($12)       5+d
       mode_ZP_Indirect         (cpu)
       oper_ADC                 (cpu)
  
    case 0x73:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x74:                                 // STZ $12,X       4
       mode_ZP_X                (cpu)
       oper_STZ                 (cpu)
  
    case 0x75:                                 // ADC $12,X       4+d
       mode_ZP_X                (cpu)
       oper_ADC                 (cpu)
  
    case 0x76:                                 // ROR $12,X       6
       mode_ZP_X                (cpu)
       oper_ROR                 (cpu)
  
    case 0x77:                                 // RMB 7,$12       5
       mode_ZP                  (cpu)
       oper_RMB7                (cpu)
  
    case 0x78:                                 // SEI 1           2
       mode_Implied             (cpu)
       oper_SEI                 (cpu)
  
    case 0x79:                                 // ADC $1234,Y     4+d+p
       mode_Absolute_Y          (cpu)
       oper_ADC                 (cpu)
  
    case 0x7A:                                 // PLY SP          4
       mode_Implied             (cpu)
       oper_PLY                 (cpu)
  
    case 0x7B:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x7C:                                 // JMP ($1234,X)   6
       mode_Absolute_X_Indirect (cpu)
       oper_JMP                 (cpu)
  
    case 0x7D:                                 // ADC $1234,X     4+d+p
       mode_Absolute_X          (cpu)
       oper_ADC                 (cpu)
  
    case 0x7E:                                 // ROR $1234,X     6+p
       mode_Absolute_X          (cpu)
       oper_ROR                 (cpu)
  
    case 0x7F:                                 // BBR 7,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBR7                (cpu)
  
    case 0x80:                                 // BRA $12         3
       mode_PC_Relative         (cpu)
       oper_BRA                 (cpu)
  
    case 0x81:                                 // STA ($12,X)     6
       mode_ZP_X_Indirect       (cpu)
       oper_STA                 (cpu)
  
    case 0x82:                                 // ILL             2
       mode_Implied             (cpu)
       oper_ILL2                (cpu)
  
    case 0x83:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x84:                                 // STY $12         3
       mode_ZP                  (cpu)
       oper_STY                 (cpu)
  
    case 0x85:                                 // STA $12         3
       mode_ZP                  (cpu)
       oper_STA                 (cpu)
  
    case 0x86:                                 // STX $12         3
       mode_ZP                  (cpu)
       oper_STX                 (cpu)
  
    case 0x87:                                 // SMB 0,$12       5
       mode_ZP                  (cpu)
       oper_SMB0                (cpu)
  
    case 0x88:                                 // DEY Y           2
       mode_Implied             (cpu)
       oper_DEY                 (cpu)
  
    case 0x89:                                 // BIT #$12        2
       mode_Immediate           (cpu)
       oper_BIT_IMM             (cpu)
  
    case 0x8A:                                 // TXA X           2
       mode_Implied             (cpu)
       oper_TXA                 (cpu)
  
    case 0x8B:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x8C:                                 // STY $1234       4
       mode_Absolute            (cpu)
       oper_STY                 (cpu)
  
    case 0x8D:                                 // STA $1234       4
       mode_Absolute            (cpu)
       oper_STA                 (cpu)
  
    case 0x8E:                                 // STX $1234       4
       mode_Absolute            (cpu)
       oper_STX                 (cpu)
  
    case 0x8F:                                 // BBS 0,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBS0                (cpu)
  
    case 0x90:                                 // BCC $12         2+t+t*p
       mode_PC_Relative         (cpu)
       oper_BCC                 (cpu)
  
    case 0x91:                                 // STA ($12),Y     6
       mode_ZP_Indirect_Y       (cpu)
       oper_STA                 (cpu)
  
    case 0x92:                                 // STA ($12)       5
       mode_ZP_Indirect         (cpu)
       oper_STA                 (cpu)
  
    case 0x93:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x94:                                 // STY $12,X       4
       mode_ZP_X                (cpu)
       oper_STY                 (cpu)
  
    case 0x95:                                 // STA $12,X       4
       mode_ZP_X                (cpu)
       oper_STA                 (cpu)
  
    case 0x96:                                 // STX $12,Y       4
       mode_ZP_Y                (cpu)
       oper_STX                 (cpu)
  
    case 0x97:                                 // SMB 1,$12       5
       mode_ZP                  (cpu)
       oper_SMB1                (cpu)
  
    case 0x98:                                 // TYA Y           2
       mode_Implied             (cpu)
       oper_TYA                 (cpu)
  
    case 0x99:                                 // STA $1234,Y     5
       mode_Absolute_Y          (cpu)
       oper_STA                 (cpu)
  
    case 0x9A:                                 // TXS X           2
       mode_Implied             (cpu)
       oper_TXS                 (cpu)
  
    case 0x9B:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0x9C:                                 // STZ $1234       4
       mode_Absolute            (cpu)
       oper_STZ                 (cpu)
  
    case 0x9D:                                 // STA $1234,X     5
       mode_Absolute_X          (cpu)
       oper_STA                 (cpu)
  
    case 0x9E:                                 // STZ $1234,X     5
       mode_Absolute_X          (cpu)
       oper_STZ                 (cpu)
  
    case 0x9F:                                 // BBS 1,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBS1                (cpu)
  
    case 0xA0:                                 // LDY #$12        2
       mode_Immediate           (cpu)
       oper_LDY                 (cpu)
  
    case 0xA1:                                 // LDA ($12,X)     6
       mode_ZP_X_Indirect       (cpu)
       oper_LDA                 (cpu)
  
    case 0xA2:                                 // LDX #$12        2
       mode_Immediate           (cpu)
       oper_LDX                 (cpu)
  
    case 0xA3:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0xA4:                                 // LDY $12         3
       mode_ZP                  (cpu)
       oper_LDY                 (cpu)
  
    case 0xA5:                                 // LDA $12         3
       mode_ZP                  (cpu)
       oper_LDA                 (cpu)
  
    case 0xA6:                                 // LDX $12         3
       mode_ZP                  (cpu)
       oper_LDX                 (cpu)
  
    case 0xA7:                                 // SMB 2,$12       5
       mode_ZP                  (cpu)
       oper_SMB2                (cpu)
  
    case 0xA8:                                 // TAY A           2
       mode_Implied             (cpu)
       oper_TAY                 (cpu)
  
    case 0xA9:                                 // LDA #$12        2
       mode_Immediate           (cpu)
       oper_LDA                 (cpu)
  
    case 0xAA:                                 // TAX A           2
       mode_Implied             (cpu)
       oper_TAX                 (cpu)
  
    case 0xAB:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0xAC:                                 // LDY $1234       4
       mode_Absolute            (cpu)
       oper_LDY                 (cpu)
  
    case 0xAD:                                 // LDA $1234       4
       mode_Absolute            (cpu)
       oper_LDA                 (cpu)
  
    case 0xAE:                                 // LDX $1234       4
       mode_Absolute            (cpu)
       oper_LDX                 (cpu)
  
    case 0xAF:                                 // BBS 2,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBS2                (cpu)
  
    case 0xB0:                                 // BCS $12         2+t+t*p
       mode_PC_Relative         (cpu)
       oper_BCS                 (cpu)
  
    case 0xB1:                                 // LDA ($12),Y     5+p
       mode_ZP_Indirect_Y       (cpu)
       oper_LDA                 (cpu)
  
    case 0xB2:                                 // LDA ($12)       5
       mode_ZP_Indirect         (cpu)
       oper_LDA                 (cpu)
  
    case 0xB3:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0xB4:                                 // LDY $12,X       4
       mode_ZP_X                (cpu)
       oper_LDY                 (cpu)
  
    case 0xB5:                                 // LDA $12,X       4
       mode_ZP_X                (cpu)
       oper_LDA                 (cpu)
  
    case 0xB6:                                 // LDX $12,Y       4
       mode_ZP_Y                (cpu)
       oper_LDX                 (cpu)
  
    case 0xB7:                                 // SMB 3,$12       5
       mode_ZP                  (cpu)
       oper_SMB3                (cpu)
  
    case 0xB8:                                 // CLV 0           2
       mode_Implied             (cpu)
       oper_CLV                 (cpu)
  
    case 0xB9:                                 // LDA $1234,Y     4+p
       mode_Absolute_Y          (cpu)
       oper_LDA                 (cpu)
  
    case 0xBA:                                 // TSX SP          2
       mode_Implied             (cpu)
       oper_TSX                 (cpu)
  
    case 0xBB:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0xBC:                                 // LDY $1234,X     4+p
       mode_Absolute_X          (cpu)
       oper_LDY                 (cpu)
  
    case 0xBD:                                 // LDA $1234,X     4+p
       mode_Absolute_X          (cpu)
       oper_LDA                 (cpu)
  
    case 0xBE:                                 // LDX $1234,Y     4+p
       mode_Absolute_Y          (cpu)
       oper_LDX                 (cpu)
  
    case 0xBF:                                 // BBS 3,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBS3                (cpu)
  
    case 0xC0:                                 // CPY #$12        2
       mode_Immediate           (cpu)
       oper_CPY                 (cpu)
  
    case 0xC1:                                 // CMP ($12,X)     6
       mode_ZP_X_Indirect       (cpu)
       oper_CMP                 (cpu)
  
    case 0xC2:                                 // ILL             2
       mode_Implied             (cpu)
       oper_ILL2                (cpu)
  
    case 0xC3:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0xC4:                                 // CPY $12         3
       mode_ZP                  (cpu)
       oper_CPY                 (cpu)
  
    case 0xC5:                                 // CMP $12         3
       mode_ZP                  (cpu)
       oper_CMP                 (cpu)
  
    case 0xC6:                                 // DEC $12         5
       mode_ZP                  (cpu)
       oper_DEC                 (cpu)
  
    case 0xC7:                                 // SMB 4,$12       5
       mode_ZP                  (cpu)
       oper_SMB4                (cpu)
  
    case 0xC8:                                 // INY Y           2
       mode_Implied             (cpu)
       oper_INY                 (cpu)
  
    case 0xC9:                                 // CMP #$12        2
       mode_Immediate           (cpu)
       oper_CMP                 (cpu)
  
    case 0xCA:                                 // DEX X           2
       mode_Implied             (cpu)
       oper_DEX                 (cpu)
  
    case 0xCB:                                 // WAI Wait        2
       mode_Implied             (cpu)
       oper_WAI                 (cpu)
  
    case 0xCC:                                 // CPY $1234       4
       mode_Absolute            (cpu)
       oper_CPY                 (cpu)
  
    case 0xCD:                                 // CMP $1234       4
       mode_Absolute            (cpu)
       oper_CMP                 (cpu)
  
    case 0xCE:                                 // DEC $1234       6
       mode_Absolute            (cpu)
       oper_DEC                 (cpu)
  
    case 0xCF:                                 // BBS 4,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBS4                (cpu)
  
    case 0xD0:                                 // BNE $12         2+t+t*p
       mode_PC_Relative         (cpu)
       oper_BNE                 (cpu)
  
    case 0xD1:                                 // CMP ($12),Y     5+p
       mode_ZP_Indirect_Y       (cpu)
       oper_CMP                 (cpu)
  
    case 0xD2:                                 // CMP ($12)       5
       mode_ZP_Indirect         (cpu)
       oper_CMP                 (cpu)
  
    case 0xD3:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0xD4:                                 // ILL             4
       mode_Implied             (cpu)
       oper_ILL2                (cpu)
  
    case 0xD5:                                 // CMP $12,X       4
       mode_ZP_X                (cpu)
       oper_CMP                 (cpu)
  
    case 0xD6:                                 // DEC $12,X       6
       mode_ZP_X                (cpu)
       oper_DEC                 (cpu)
  
    case 0xD7:                                 // SMB 5,$12       5
       mode_ZP                  (cpu)
       oper_SMB5                (cpu)
  
    case 0xD8:                                 // CLD 0           2
       mode_Implied             (cpu)
       oper_CLD                 (cpu)
  
    case 0xD9:                                 // CMP $1234,Y     4+p
       mode_Absolute_Y          (cpu)
       oper_CMP                 (cpu)
  
    case 0xDA:                                 // PHX X           3
       mode_Implied             (cpu)
       oper_PHX                 (cpu)
  
    case 0xDB:                                 // STP Stop        3
       mode_Implied             (cpu)
       oper_STP                 (cpu)
  
    case 0xDC:                                 // ILL             4
       mode_Implied             (cpu)
       oper_ILL3                (cpu)
  
    case 0xDD:                                 // CMP $1234,X     4+p
       mode_Absolute_X          (cpu)
       oper_CMP                 (cpu)
  
    case 0xDE:                                 // DEC $1234,X     7
       mode_Absolute_X          (cpu)
       oper_DEC                 (cpu)
  
    case 0xDF:                                 // BBS 5,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBS5                (cpu)
  
    case 0xE0:                                 // CPX #$12        2
       mode_Immediate           (cpu)
       oper_CPX                 (cpu)
  
    case 0xE1:                                 // SBC ($12,X)     6+d
       mode_ZP_X_Indirect       (cpu)
       oper_SBC                 (cpu)
  
    case 0xE2:                                 // ILL             2
       mode_Implied             (cpu)
       oper_ILL2                (cpu)
  
    case 0xE3:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0xE4:                                 // CPX $12         3
       mode_ZP                  (cpu)
       oper_CPX                 (cpu)
  
    case 0xE5:                                 // SBC $12         3+d
       mode_ZP                  (cpu)
       oper_SBC                 (cpu)
  
    case 0xE6:                                 // INC $12         5
       mode_ZP                  (cpu)
       oper_INC                 (cpu)
  
    case 0xE7:                                 // SMB 6,$12       5
       mode_ZP                  (cpu)
       oper_SMB6                (cpu)
  
    case 0xE8:                                 // INX X           2
       mode_Implied             (cpu)
       oper_INX                 (cpu)
  
    case 0xE9:                                 // SBC #$12        2+d
       mode_Immediate           (cpu)
       oper_SBC                 (cpu)
  
    case 0xEA:                                 // NOP No          2
       mode_Implied             (cpu)
       oper_NOP                 (cpu)
  
    case 0xEB:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0xEC:                                 // CPX $1234       4
       mode_Absolute            (cpu)
       oper_CPX                 (cpu)
  
    case 0xED:                                 // SBC $1234       4+d
       mode_Absolute            (cpu)
       oper_SBC                 (cpu)
  
    case 0xEE:                                 // INC $1234       6
       mode_Absolute            (cpu)
       oper_INC                 (cpu)
  
    case 0xEF:                                 // BBS 6,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBS6                (cpu)
  
    case 0xF0:                                 // BEQ $12         2+t+t*p
       mode_PC_Relative         (cpu)
       oper_BEQ                 (cpu)
  
    case 0xF1:                                 // SBC ($12),Y     5+d+p
       mode_ZP_Indirect_Y       (cpu)
       oper_SBC                 (cpu)
  
    case 0xF2:                                 // SBC ($12)       5+d
       mode_ZP_Indirect         (cpu)
       oper_SBC                 (cpu)
  
    case 0xF3:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0xF4:                                 // ILL             4
       mode_Implied             (cpu)
       oper_ILL2                (cpu)
  
    case 0xF5:                                 // SBC $12,X       4+d
       mode_ZP_X                (cpu)
       oper_SBC                 (cpu)
  
    case 0xF6:                                 // INC $12,X       6
       mode_ZP_X                (cpu)
       oper_INC                 (cpu)
  
    case 0xF7:                                 // SMB 7,$12       5
       mode_ZP                  (cpu)
       oper_SMB7                (cpu)
  
    case 0xF8:                                 // SED 1           2
       mode_Implied             (cpu)
       oper_SED                 (cpu)
  
    case 0xF9:                                 // SBC $1234,Y     4+d+p
       mode_Absolute_Y          (cpu)
       oper_SBC                 (cpu)
  
    case 0xFA:                                 // PLX SP          4
       mode_Implied             (cpu)
       oper_PLX                 (cpu)
  
    case 0xFB:                                 // ILL             1
       mode_Implied             (cpu)
       oper_ILL1                (cpu)
  
    case 0xFC:                                 // ILL             4
       mode_Implied             (cpu)
       oper_ILL3                (cpu)
  
    case 0xFD:                                 // SBC $1234,X     4+d+p
       mode_Absolute_X          (cpu)
       oper_SBC                 (cpu)
  
    case 0xFE:                                 // INC $1234,X     7
       mode_Absolute_X          (cpu)
       oper_INC                 (cpu)
  
    case 0xFF:                                 // BBS 7,$12,$34   5+t+t*p
       mode_ZP_and_Relative     (cpu)
       oper_BBS7                (cpu)
    }
}

m6502_cpu_irq_ack :: proc (level: uint) -> uint { return 0 }

