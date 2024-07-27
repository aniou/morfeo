
package cpu

import "base:runtime"
import "core:fmt"
import "core:log"
import "emulator:bus"
import "emulator:pic"

import "lib:emu"

import "core:prof/spall"

byte :: true
word :: false

DataRegister_65C816 :: struct {
     val:    u16,    // register value
    high:    u16,    // high byte of register value
    size:    bool,   // 0 == 16 bit, 1 == 8 bit
}

AddresRegister_65C816 :: struct {
    bank:      u16,                  // data bank (u8)
    addr:      u16,                  // address within bank
     idx:      u16,                  // for indexed operations
    wrap:      bool,                 // does read wrap on bank boundary?
}

CPU_65C816_type :: enum {
    W65C816S,
}

CPU_65C816 :: struct {
    using cpu: ^CPU,

    type: 	CPU_65C816_type,

    pc:     AddresRegister_65C816,
    sp:     AddresRegister_65C816,      // XXX: check it should be Data or Address?
    ab:     AddresRegister_65C816,
    ta:     AddresRegister_65C816,      // temporary, internal register

    a:      DataRegister_65C816,
    x:      DataRegister_65C816,
    y:      DataRegister_65C816,
    t:      DataRegister_65C816,        // temporary, internal register

    dbr:    u16,      // Data    Bank Register  (u8)
    k:      u16,      // Program Bank Register  (u8)
    d:      u16,      // Direct registera       (u16)

                      // flag set for 65C816:  nvmxdizc e
                      // flag set for 65xx     nv1bdizc
    f : struct {	  // flags
        N:    bool,   // Negative
        V:    bool,   // oVerflow
        M:    bool,   // accumulator and Memory width : 65C816 only
        X:    bool,   // indeX register width         : 65C816 only
        B:    bool,   // Break                        : 65xx or emulation mode
        D:    bool,   // Decimal mode
        I:    bool,   // Interrupt disable
        Z:    bool,   // Zero
        C:    bool,   // Carry
        E:    bool,   // (no direct access) Emulation : 65C816 only
    },

                       // misc variables
    ir:     u8,        // instruction register
    px:     bool,      // page was crossed?

    wdm:    bool,      // support for non-standard WDM (0x42) command
    abort:  bool,      // emulator should abort?
    ppc:    u16,       // previous PC - for debug purposes
    cycle:  int,       // number of cycless for this command

    f0:     bool,      // temporary flag
    b0:     u8,        // temporary register
    b1:     u8,        // secondary temporary register
    w0:     u16,       // temporary register
    w1:     u16,       // temporary register (2)
}

// XXX - parametrize CPU type!
w65C816_make :: proc (name: string, bus: ^bus.Bus) -> ^CPU {

    cpu           := new(CPU)
    cpu.name       = name
    cpu.setpc      = w65C816_setpc
    cpu.reset      = w65C816_reset
    cpu.exec       = w65C816_exec
    cpu.clear_irq  = w65C816_clear_irq
    cpu.bus        = bus
    cpu.cycles     = 0
    c             := CPU_65C816{cpu = cpu, type = CPU_65C816_type.W65C816S}
    c.a            = DataRegister_65C816{}
    c.x            = DataRegister_65C816{}
    c.y            = DataRegister_65C816{}
    c.pc           = AddresRegister_65C816{wrap = true}
    c.sp           = AddresRegister_65C816{wrap = true}
    c.ab           = AddresRegister_65C816{wrap = true}
    c.ta           = AddresRegister_65C816{wrap = true}
    cpu.model      = c


    // we need global because of external musashi (XXX - maybe whole CPU?)
    localbus   = bus

    //w65C816_init();
    return cpu
}

w65C816_setpc :: proc(cpu: ^CPU, address: u32) {
    c         := &cpu.model.(CPU_65C816)
    c.pc.addr  = u16(address)
    return
}

w65C816_reset :: proc(cpu: ^CPU) {
    return
}

w65C816_clear_irq :: proc(cpu: ^CPU) {
    //if localbus.pic.irq_clear {
    //    log.debugf("%s IRQ clear", cpu.name)
    //    localbus.pic.irq_clear  = false
    //    localbus.pic.irq_active = false
    //    localbus.pic.current    = pic.IRQ.NONE
    //    m68k_set_irq(uint(pic.IRQ.NONE))
    //}
}

w65C816_exec :: proc(cpu: ^CPU, ticks: u32 = 1000) {
    c := &cpu.model.(CPU_65C816)
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

        cycles        := w65C816_execute(c)
        c.cycles      += cycles
        current_ticks += cycles
        //log.debugf("%s execute %d cycles", cpu.name, current_ticks)
    }
    //log.debugf("%s execute %d cycles", cpu.name, cpu.cycles)
    return
}

w65C816_execute :: proc(cpu: ^CPU_65C816) -> (cycles: u32) {
    cpu.px    = false
    cpu.ir    = u8(load_m(byte, cpu.pc)) // XXX: u16?

    //w65C816_run_opcode(cpu)

    // XXX: create OP table!
    //cycles    = op_table[cpu.ir].cycles
    //cycles   += op_table[cpu.ir].p         if px else 0
    return cycles
}

// special form of unsigned add, "low part only": adding without carry,
// - ZP, X
// - ZP, Y
// - buggy behaviour of NMOS JMP ($1234)
xaddu_l :: #force_inline proc (a: u16, b: u8) -> (result: u16) {
    result  = a & 0xff00   // preserve high byte
      arg1 := a
      arg1 += u16(b)
      arg1  = arg1 & 0x00ff   // wrapped, sum w/o carry
    result |= arg1
    return result
}

add__u :: #force_inline proc (dr: DataRegister_65C816, a: u16)     -> (result: u16) {
    result = dr.val + a
    if dr.size {
        result &= 0xff
    }
    return
}

sub__u :: #force_inline proc (dr: DataRegister_65C816, a: u16)     -> (result: u16) {
    result = dr.val - a
    if dr.size {
        result &= 0xff
    }
    return
}

load_m :: #force_inline proc (size: bool, ar: AddresRegister_65C816) -> (result: u16) {
    ea     := u32(ar.addr) + u32(ar.idx)
    ea     &= 0x0000_ffff if ar.wrap else 0xffff_ffff
    ea     |= u32(ar.bank) << 16
    result  = u16(localbus->read(.bits_8, ea))

    if size == word {
        ea      = u32(ar.addr) + u32(ar.idx) + 1
        ea     &= 0x0000_ffff if ar.wrap else 0xffff_ffff
        ea     |= u32(ar.bank) << 16
        result |= u16(localbus->read(.bits_8, ea)) << 8
    }
    return
}

stor_m :: #force_inline proc (size: bool, ar: AddresRegister_65C816, value: u16) -> bool {
    ea     := u32(ar.addr) + u32(ar.idx)
    ea     &= 0x0000_FFFF if ar.wrap else 0xFFFF_FFFF
    ea     |= u32(ar.bank) << 16
    u16(localbus->write(.bits_8, ea, u32(value & 0xFF)))

    if size == word {
        ea      = u32(ar.addr) + u32(ar.idx) + 1
        ea     &= 0x0000_FFFF if ar.wrap else 0xFFFF_FFFF
        ea     |= u32(ar.bank) << 16
        u16(localbus->read(.bits_8, ea, u32(value & 0xFF00) >> 8)
    }

    return false
}

// add signed value to word
// XXX - double-check relative addressing mode
add__s :: #force_inline proc (size: bool, a, b: u16) -> (result: u16) {
    switch {
    case size == byte && b >= 0x80:
        result  = a + b - 0x100
    case size == word && b >= 0x8000:
        result  = a + b - 0xffff    // because not -0x10000 for u16
        result -= 1
    case:
        result  = a + b
    }
    return
}

// detection of page crossing, used for cycle cost calculations
test_p :: #force_inline proc (ar: AddresRegister_65C816) ->  bool {
    return ((ar.addr & 0xFF00) != ((ar.addr+ar.idx) & 0xFF00))
}

// negative flag test
test_n :: #force_inline proc (dr: DataRegister_65C816)    -> (result: bool) {
    switch dr.size {
    case byte:
        result = (dr.val &   0x80) ==   0x80
    case word:
        result = (dr.val & 0x8000) == 0x8000
    }
    return result
}

// zero value test
test_z :: #force_inline proc (dr: DataRegister_65C816)    -> bool {
    return dr.val == 0
}

// bit 0 test - for LSR, ROR...
test_0 :: #force_inline proc (dr: DataRegister_65C816)    -> bool {
    return (dr.val & 1) == 1
}         

// special case for single command, BIT - testing second highest
testsh :: #force_inline proc (dr: DataRegister_65C816)    -> (result: bool) {
    switch dr.size {
    case byte:
        result          = dr.val &   0x40 ==   0x40
    case word:
        result          = dr.val & 0x4000 == 0x4000
    }
    return result
}

// "the overflow flag is set when the sign of the addends
//  is the same and differs from the sign of the sum"
//
// XXX - check if we really need to pass sum
test_v :: #force_inline proc(size: bool, a, b, s: u16) -> (result: bool) {
    switch size {
    case byte:
        arg_sign_eq    := ((a ~ b )  &   0x80) == 0
        prod_sign_neq  := ((a ~ s )  &   0x80) != 0
        result          = arg_sign_eq && prod_sign_neq
    case word:
        arg_sign_eq    := ((a ~ b )  & 0x8000) == 0
        prod_sign_neq  := ((a ~ s )  & 0x8000) != 0
        result          = arg_sign_eq && prod_sign_neq
    }
    return result
}

// addressing modes
// references:
// man65816: "Programming the 65816" / WDC 2007
// 2 - http://6502.org/tutorials/65C816opcodes.html
// 3 - http://datasheets.chipdb.org/Western%20Design/w65C816s.pdf


//
// CPU: all
// OPC $LLHH      operand is address $HHLL
//                only 16bit part of address is be loaded to AB because
//                that mode is used both by data instructions, affected
//                by DBR and program control JMP/SRC, affected by PBR
//
//                [man65816: pp. 288 or 5.2]
//
mode_Absolute_DBR           :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = load_m( word, pc )
    ab.bank   = dbr
    ab.wrap   = false
    pc.addr  += 1
}

// jesli pc będzie register
//          to ustawimy mu od razu bank na k
//          i wrap na true - i wtedy zawsze to się uda!
// pc.b = k    // always bank K for pc
// pc.w = true   // always wrap for   PC
//
mode_Absolute_PBR           :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = load_m( word, pc )
    ab.bank   = k
    ab.wrap   = false
    pc.addr  += 1
}

// CPU: all
// OPC $LLHH,X    operand is address;
//                effective address is address incremented by X with carry [2]
//
// MOS 6502: The value at the specified address, ignoring the addressing
// mode's X offset, is read (and discarded) before the final address is read.
// This may cause side effects in I/O registers
//
// XXX - implement that variant
//
mode_Absolute_X                :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = load_m( word, pc )
    ab.bank   = dbr
    ab.wrap   = false
    ab.idx    = x.val
    px        = test_p( ab )
    pc.addr  += 1
}

//
// CPU: all
// OPC $LLHH,Y    operand is address;
//                effective address is address incremented by Y with carry [2]
//
// MOS 6502: The value at the specified address, ignoring the addressing
// mode's X offset, is read (and discarded) before the final address is read.
// This may cause side effects in I/O registers: XXX - implement that variant
mode_Absolute_Y                :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = load_m( word, pc )
    ab.bank   = dbr
    ab.wrap   = false
    ab.idx    = y.val
    px        = test_p( ab )
    pc.addr  += 1
}

//
// CPU:           all
// OPC ($LL,X)    operand is zeropage address; effective address is word
//                $00LL+X    data lo
//                $00LL+X+1  data hi
mode_DP_X_Indirect          :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = load_m( byte, pc   )  // 0 | D + LL + X
    ab.addr  += d
    ab.bank   = 0
    ab.idx    = x.val
    ab.wrap   = true

    ab.addr   = load_m( word, ab   )  // dbr hh ll
    ab.bank   = dbr
    ab.idx    = 0
    ab.wrap   = false
}

//
// CPU: all, except MOS 6502
// OPC ($LL)      operand is zeropage address;
//                effective address is word in (LL):  C.w($00LL)
mode_DP_Indirect            :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = load_m( byte, pc   )  // 0 | D + LL
    ab.addr  += d
    ab.bank   = 0
    ab.wrap   = true

    ab.addr   = load_m( word, ab   )  // dbr hh ll
    ab.bank   = dbr
    ab.wrap   = false
}

//
// CPU: all
// OPC ($LL),Y    operand is zeropage address;
//                effective address is word in (LL, LL + 1)
//                incremented by Y with carry: C.w($00LL) + Y
mode_DP_Indirect_Y          :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = load_m( byte, pc   )  // 0 | D + LL
    ab.addr  += d
    ab.bank   = 0
    ab.wrap   = true

    ab.addr   = load_m( word, ab   )  // dbr hh ll + Y
    ab.bank   = dbr
    ab.idx    = y.val
    ab.wrap   = false
    px        = test_p( ab )
}

mode_S_Relative_Indirect_Y  :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = load_m( byte, pc   )  // 0 | S + LL
    ab.addr  += sp.addr
    ab.bank   = 0
    ab.wrap   = true

    ab.addr   = load_m( word, ab   )  // dbr hh ll + Y
    ab.bank   = dbr
    ab.idx    = y.val
    ab.wrap   = false
}

//
// CPU: 
// OPC [$LL]      operand is zeropage address;
//                effective address is word in (LL):  C.w($00LL)
mode_DP_Indirect_Long       :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1 
    ta.addr   = load_m( byte, pc   )  // 0 | D + LL
    ta.addr  += d
    ta.bank   = 0
    ta.wrap   = true

    ab.addr   = load_m( word, ta   )  // hh ll
    ta.addr  += 2
    ab.bank   = load_m( byte, ta   )  // top
    ab.wrap   = false
}

// OPC $BBHHLL
mode_Absolute_Long          :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1 
    ab.addr   = load_m( word, pc   )  // HH LL
    pc.addr  += 2
    ab.bank   = load_m( byte, pc   )  // BB
    ab.wrap   = true
}

// OPC $BBHHLL, X
mode_Absolute_Long_X        :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1 
    ab.addr   = load_m( word, pc   )  // HH LL
    pc.addr  += 2
    ab.bank   = load_m( byte, pc   )  // BB
    ab.wrap   = true
    ab.idx    = x.val
}

// PC relative mode: value is added to PC that already points at NEXT OP
// OPC $LL
mode_PC_Relative            :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1 
    ab.addr   = load_m( byte, pc              )
    ab.addr   = add__s( byte, pc.addr, ab.addr)
    ab.bank   = k
}

mode_PC_Relative_Long       :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1 
    ab.addr   = load_m( word, pc              )
    ab.addr   = add__s( word, pc.addr, ab.addr)
    ab.bank   = k
    pc.addr  += 1 
}

//
// CPU: all
// OPC $LL        operand is zeropage address, hi-byte is zero address
//                $00LL      data
mode_DP                     :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr   += 1
    ab.addr    = load_m( byte, pc )
    ab.addr   += d
    ab.bank    = 0
    ab.idx     = 0
    ab.wrap    = true
}
//
// CPU: all
// OPC $LL,X     operand is zeropage address;
//               effective address is address incremented by X without carry [2]
mode_DP_X                   :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr   += 1
    ab.addr    = load_m( byte, pc )
    ab.addr   += d
    ab.bank    = 0
    ab.idx     = x.val
    ab.wrap    = true
}

//
// CPU: all
// OPC $LL,Y      operand is zeropage address;
//                effective address is address incremented by Y without carry [2]
mode_DP_Y                   :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr   += 1
    ab.addr    = load_m( byte, pc )
    ab.addr   += d
    ab.bank    = 0
    ab.idx     = y.val
    ab.wrap    = true
}

mode_S_Relative             :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr   += 1
    ab.addr    = load_m( byte, pc )
    ab.bank    = 0
    ab.idx     = sp.addr         // XXX after change to DataRegister move to .val
    ab.wrap    = true
}


//
// CPU: all, except MOS 6502
// OPC ($LLHH,X)  operand is address;
//                effective address is word in (HHLL+X), inc. with carry: C.w($HHLL+X)
mode_Absolute_X_Indirect       :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = load_m( word, pc   )  // K | D + HH + LL + X
    ab.bank   = k
    ab.idx    = x.val
    ab.wrap   = true

    ab.addr   = load_m( word, ab   )  // k hh ll
    ab.idx    = 0
    pc.addr  += 1
}

mode_Absolute_Indirect         :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = load_m( word, pc   )  // 0 | D + HH + LL 
    ab.bank   = 0
    ab.wrap   = true

    ab.addr   = load_m( word, ab   )  // k hh ll
    ab.bank   = k
    pc.addr  += 1
}


//
// CPU: all, except MOS 6502
// OPC ($LLHH)    operand is address;
//                effective address is contents of word at address: C.w($HHLL)
//
// Note that on the 65C816, as on the 65C02, (absolute) addressing does not
// wrap at a page boundary, i.e. for a JMP ($12FF) the low byte of the
// destination address is taken from $12FF and the high byte of the destination
// address is taken from $1300. On the NMOS 6502, (absolute) addressing did
// wrap on a page boundary, which was unintentional (i.e. a bug); there, a JMP
// ($12FF) took the low byte of the destination address from $12FF but took the
// high byte of the destination address from $1200 (rather than $1300)
// [65C816opcodes]
//
/*
mode_Absolute_Indirect      :: #force_inline proc (using c: ^CPU_65C816) {
    pc   += 1
    w0    = read_l( pc     )
    pc   += 1
    w0   |= read_h( pc     )

    ab    = read_l( w0     )
    ab   |= read_h( w0+1   )
}

*/
//
// CPU: only MOS 6502
// OPC ($LLHH)    operand is address;
//                effective address is contents of word at address: C.w($HHLL)
//                BUT LL is incremented without carry set,
//                C.w($12ff) and C.w($1200) not C.w($1300)
//
//                It is a known bug in MOS 6502 family
mode_Absolute_Indirect_MOS  :: #force_inline proc (using c: ^CPU_65C816) {
/*
    pc   += 1
    w0    = read_l( pc     )
    pc   += 1
    w0   |= read_h( pc     )

    ab    = read_l( w0     )
    w0    = addu_l( w0,  1 )        // special case - page wrap
    ab   |= read_h( w0     )
*/
}

mode_Absolute_Indirect_Long  :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1 
    ta.addr   = load_m( word, pc   )  // 0 | HH LL
    ta.bank   = 0
    ta.wrap   = true
    pc.addr  += 1 

    ab.addr   = load_m( word, ta   )  // hh ll
    ta.addr  += 2
    ab.bank   = load_m( byte, ta   )  // top
    ab.wrap   = false
}

//
// CPU: all
// OPC A          operand is AC (implied single byte instruction)
mode_Accumulator            :: #force_inline proc (using c: ^CPU_65C816) {
}


//
// CPU: all
// OPC #$BB       operand is byte BB
// XXX: IMPORTANT NOTE: also used for MVN/MVP because mode is the same
//      ie. address of first argument is an address pc+1, thus second
mode_Immediate              :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1 
    ab        = pc
}

//
// CPU: all
// OPC            operand implied
mode_Implied                :: #force_inline proc (using c: ^CPU_65C816) {
}

//
// CPU: R65C02, CSG 65CE02, WDC 65C02S
// OPC OP,LL,BB   OP denotes bit number to check LL is a ZP address to check
//                BB denotes signed relative branch, calculated from current PC
mode_ZP_and_Relative        :: #force_inline proc (using c: ^CPU_65C816) {
/*
    pc   += 1
    w0    = read_l( pc     )        // ZP address to read
    b0    = read_b( w0     )        // preserve for oper_ processing

    pc   += 1
    b1    = read_b( pc     )        // relative jump size
    ab    = add__s_w( pc, b1 )        // calculate jump - add signed byte
    px    = test_p( ab, pc )
*/
}


// ----------------------------------------------------------------------------
// XXX: opcodes routines should be moved to separate files for testing, or only
// case / execute part of them?

//oper_ADC                    :: #force_inline proc (using c: ^CPU_65C816) { }
//
//oper_AND                    :: #force_inline proc (using c: ^CPU_65C816) {
//    b0    = read_b( ab     )
//    a    &= b0
//    N     = test_n( a )
//    Z     = test_z( a )
//    pc   += 1
//}
//
// C <- [76543210] <- 0  (mem)               nv*bdizc
//                                           m.....mm
//oper_ASL                    :: #force_inline proc (using c: ^CPU_65C816) {
//    b0    = read_b( ab     )
//    C     = test_n( b0     )
//    b0   <<= 1
//    N     = test_n( b0     )
//    Z     = test_z( b0     )
//            writeb( ab, b0 )
//    pc   += 1
//}
//

// C <- [76543210] <- 0  (acc)               nv*bdizc
//                                           m.....mm
//oper_ASL_A                  :: #force_inline proc (using c: ^CPU_65C816) {
//    C     = test_n( a      )
//    a   <<= 1
//    N     = test_n( a      )
//    Z     = test_z( a      )
//    pc   += 1
//}

oper_ADC                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_AND                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_AND_A                  :: #force_inline proc (using c: ^CPU_65C816) { }
oper_ASL                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_ASL_A                  :: #force_inline proc (using c: ^CPU_65C816) { }
    
oper_BCC                    :: #force_inline proc (using c: ^CPU_65C816) {
    if ! f.C {
        pc.addr   = ab.addr
        cycle    += 1
        cycle    += 1       if f.E && px else 0
    }
    pc.addr   += 1
}

oper_BCS                    :: #force_inline proc (using c: ^CPU_65C816) {
    if   f.C {
        pc.addr   = ab.addr
        cycle    += 1
        cycle    += 1       if f.E && px else 0
    }
    pc.addr   += 1
}

oper_BEQ                    :: #force_inline proc (using c: ^CPU_65C816) {
    if   f.Z {
        pc.addr   = ab.addr
        cycle    += 1
        cycle    += 1       if f.E && px else 0
    }
    pc.addr   += 1

}

oper_BIT                    :: #force_inline proc (using c: ^CPU_65C816) {
    t.val      = load_m( a.size, ab )
    t.size     = a.size
    f.N        = test_n( t )
    f.V        = testsh( t )            // second highest byte 
    t.val     &= a.val
    f.Z        = test_z( t )
    pc.addr   += 1 if a.size else 2
}

oper_BIT_IMM                :: #force_inline proc (using c: ^CPU_65C816) {
    t.val      = load_m( a.size, ab )
    t.size     = a.size
    t.val     &= a.val
    f.Z        = test_z( t )
    pc.addr   += 1 if a.size else 2
}

oper_BMI                    :: #force_inline proc (using c: ^CPU_65C816) {
    if   f.N {
        pc.addr   = ab.addr
        cycle    += 1
        cycle    += 1       if f.E && px else 0
    }
    pc.addr   += 1
}

oper_BNE                    :: #force_inline proc (using c: ^CPU_65C816) {
    if ! f.Z {
        pc.addr   = ab.addr
        cycle    += 1
        cycle    += 1       if f.E && px else 0
    }
    pc.addr   += 1
}

oper_BPL                    :: #force_inline proc (using c: ^CPU_65C816) {
    if ! f.N {
        pc.addr   = ab.addr
        cycle    += 1
        cycle    += 1       if f.E && px else 0
    }
    pc.addr   += 1
}

oper_BRA                    :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr   = ab.addr
    cycle    += 1
    cycle    += 1          if f.E && px else 0
    pc.addr  += 1
}

oper_BRK                    :: #force_inline proc (using c: ^CPU_65C816) { }

oper_BRL                    :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr   = ab.addr
    pc.addr  += 1
}

oper_BVC                    :: #force_inline proc (using c: ^CPU_65C816) {
    if ! f.V {
        pc.addr   = ab.addr
        cycle    += 1
        cycle    += 1       if f.E && px else 0
    }
    pc.addr   += 1
}

oper_BVS                    :: #force_inline proc (using c: ^CPU_65C816) {
    if   f.V {
        pc.addr   = ab.addr
        cycle    += 1
        cycle    += 1       if f.E && px else 0
    }
    pc.addr   += 1
}

oper_CLC                    :: #force_inline proc (using c: ^CPU_65C816) {
    f.C       = false
    pc.addr  += 1
}

oper_CLD                    :: #force_inline proc (using c: ^CPU_65C816) {
    f.D       = false
    pc.addr  += 1
}

oper_CLI                    :: #force_inline proc (using c: ^CPU_65C816) {
    f.I       = false
    pc.addr  += 1
}

oper_CLV                    :: #force_inline proc (using c: ^CPU_65C816) {
    f.V       = false
    pc.addr  += 1
}

oper_CMP                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_COP                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_CPX                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_CPY                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_DEC                    :: #force_inline proc (using c: ^CPU_65C816) { }

oper_DEC_A                  :: #force_inline proc (using c: ^CPU_65C816) {
    a.val     = sub__u( a, 1 )
    f.N       = test_n( a    )
    f.Z       = test_z( a    )   // or Z = x.val == 0 ?
    pc.addr  += 1
}

oper_DEX                    :: #force_inline proc (using c: ^CPU_65C816) {
    x.val     = sub__u( x, 1 )
    f.N       = test_n( x    )
    f.Z       = test_z( x    )   // or Z = x.val == 0 ?
    pc.addr  += 1
}

oper_DEY                    :: #force_inline proc (using c: ^CPU_65C816) {
    y.val     = sub__u( y, 1 )
    f.N       = test_n( y    )
    f.Z       = test_z( y    )   // or Z = x.val == 0 ?
    pc.addr  += 1
}

oper_EOR                    :: #force_inline proc (using c: ^CPU_65C816) { }

oper_INC                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.val      = load_m( a.size, ab        )
    t.size     = a.size
    t.val      = add__u( t, 1 )
    f.N        = test_n( t    )
    f.Z        = test_z( t    )
    _          = stor_m( t.size, ab, t.val )  // convert it to writing proc for register
    pc.addr   += 1 if a.size else 2           // XX - change a.size from bool to enum 1/2 

}

oper_INC_A                  :: #force_inline proc (using c: ^CPU_65C816) {
    a.val     = add__u( a, 1 )
    f.N       = test_n( a    )
    f.Z       = test_z( a    )   // or Z = x.val == 0 ?
    pc.addr  += 1
}

oper_INX                    :: #force_inline proc (using c: ^CPU_65C816) {
    x.val     = add__u( x, 1 )
    f.N       = test_n( x    )
    f.Z       = test_z( x    )   // or Z = x.val == 0 ?
    pc.addr  += 1
}

oper_INY                    :: #force_inline proc (using c: ^CPU_65C816) {
    y.val     = add__u( y, 1 )
    f.N       = test_n( y    )
    f.Z       = test_z( y    )   // or Z = x.val == 0 ?
    pc.addr  += 1
}

oper_JMP                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_JSL                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_JSR                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_LDA                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_LDX                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_LDY                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_LSR                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_MVN                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_MVP                    :: #force_inline proc (using c: ^CPU_65C816) { }

oper_NOP                    :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
}

oper_ORA                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PEA                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PEI                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PER                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PHA                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PHB                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PHD                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PHK                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PHP                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PHX                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PHY                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PLA                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PLB                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PLD                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PLP                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PLX                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_PLY                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_REP                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_ROL                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_ROR                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_RTI                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_RTL                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_RTS                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_SBC                    :: #force_inline proc (using c: ^CPU_65C816) { }

oper_SEC                    :: #force_inline proc (using c: ^CPU_65C816) { 
    f.C       = true
    pc.addr  += 1
}

oper_SED                    :: #force_inline proc (using c: ^CPU_65C816) { 
    f.D       = true
    pc.addr  += 1
}

oper_SEI                    :: #force_inline proc (using c: ^CPU_65C816) {
    f.I       = true
    pc.addr  += 1
}

oper_SEP                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_STA                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_STP                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_STX                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_STY                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_STZ                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_TAX                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_TAY                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_TCD                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_TCS                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_TDC                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_TRB                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_TSB                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_TSC                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_TSX                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_TXA                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_TXS                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_TXY                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_TYA                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_TYX                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_WAI                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_WDM                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_XBA                    :: #force_inline proc (using c: ^CPU_65C816) { }

oper_XCE                    :: #force_inline proc (using c: ^CPU_65C816) {
    f.E       = f.C
    pc.addr  += 1
}











// 0 -> [76543210] -> C  (mem)               nv*bdizc
//                                           0.....mm
//oper_LSR                    :: #force_inline proc (using c: ^CPU_65C816) {
//    b0    = read_b( ab     )
//    C     = test_0( b0     )
//    b0   >>= 1
//    N     = false
//    Z     = test_z( b0     )
//            writeb( ab, b0 )
//    pc   += 1
//}
//
// 0 -> [76543210] -> C  (acc)               nv*bdizc
//                                           0.....mm
//oper_LSR_A                  :: #force_inline proc (using c: ^CPU_65C816) {
//    C     = test_0( a      )
//    a   >>= 1
//    N     = false
//    Z     = test_z( a      )
//    pc   += 1
//}
//
//oper_NOP                    :: #force_inline proc (using c: ^CPU_65C816) {
//    pc   += 1
//}
//

