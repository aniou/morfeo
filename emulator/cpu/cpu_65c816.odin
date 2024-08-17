
// general ideas for future:
// 1. use 32bit-wide register everywhere to avoid casts
// 2. use bit_fields to avoid bitshifts for banks, 
//    ie. no  ea = u32(bank) << 16 | u32(addr) + 1
//    but     ea = bank | addr + 1
// 3. check appropriateness of bit_fields for registers 
// 4. consider shifting constructs like ( Reg ) to { Reg.val, size }
//    to achieve more uniformity across routines

// + all tests (except MVN/MVP) passed
// + cycles are supported
// - irqs not implemented
//   - and reset too
// - code not optimized

/*
CPU: 65c816

This implementation is based on infromation from following bibliography,
part of them are cited directly in comments for particular opcodes and
addressing modes.

1. Bruce Clark                     (2015) "65C816 Opcodes"
   http://6502.org/tutorials/65C816opcodes.html

2. David Eyes, Ron Lichty          (1992) "Programming the 65816"

3. The Western Design Center, Inc. (2004) "W65C816S Microprocessor DATA SHEET"
   http://datasheets.chipdb.org/Western%20Design/w65c816s.pdf

*/
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
       b:    u16,    // high byte of register (Accumulator only)
    size:    bool,   // 0 == 16 bit, 1 == 8 bit
}

AddressRegister_65C816 :: struct {
    bank:      u16,                  // data bank (u8)
    addr:      u16,                  // address within bank
   index:      u16,                  // for indexed operations
   bwrap:      bool,                 // does wrap on bank boundary?
   pwrap:      bool,                 // does wrap on page boundary?
    size:      bool,                 // 0 == 16 bit, 1 == 8 bit
}

CPU_65C816_type :: enum {
    W65C816S,
}

CPU_65C816 :: struct {
    using cpu: ^CPU,

    type:   CPU_65C816_type,

    pc:     AddressRegister_65C816,     // note: pc.bank act as K register
    sp:     AddressRegister_65C816,     // XXX: check it should be Data or Addresss?

    a:      DataRegister_65C816,
    x:      DataRegister_65C816,
    y:      DataRegister_65C816,

    dbr:    u16,                        // Data    Bank Register  (u8)
    d:      u16,                        // Direct register       (u16)
    //k:      u16,                      // Program Bank Register  (u8)   - inside pc.bank

    // temporary, emulator registers
    ab:     AddressRegister_65C816,     // temporary address bus, heavily used
    ta:     AddressRegister_65C816,     // temporary, internal address register
    tb:     DataRegister_65C816,        // always byte
    tw:     DataRegister_65C816,        // always word
    t:      DataRegister_65C816,        // same size as A register
    data0:  u16,                        // temporary value holder
 
    // flag set for 65C816:  nvmxdizc e
    // flag set for 65xx     nv1bdizc
    f : struct {      // flags
        N:    bool,   // Negative
        V:    bool,   // oVerflow
        M:    bool,   // accumulator and Memory width : 65C816 only, 1 in emulation mode
        X:    bool,   // indeX register width         : 65C816 only, B in emulation mode
        D:    bool,   // Decimal mode
        I:    bool,   // Interrupt disable
        Z:    bool,   // Zero
        C:    bool,   // Carry

        E:    bool,   // (no direct access) Emulation : 65C816 only
        T:    bool,   // Temporary flag, for value holding
    },

    // misc variables, used by emulator
    ir:     u8,        // instruction register
    px:     bool,      // page was crossed?
    wdm:    bool,      // support for non-standard WDM (0x42) command?
    abort:  bool,      // emulator should abort?
    ppc:    u16,       // previous PC - for debug purposes
    cycles: u32,       // number of cycless for this command

    // only for MVN/MVP support
    in_mvn: bool,      // CPU is in middle in MVN - lower precedence than irq
    in_mvp: bool,      // CPU is in middle in MVP - lower precedence than irq
    src:    u16,       // two temorary registers for MVN/MVP used in case of
    dst:    u16,       // irq during MVN/P, when banks in ab and ta temporary
                       // registers may be overwritten by other operations
}

// XXX - parametrize CPU type!
w65c816_make :: proc (name: string, bus: ^bus.Bus) -> ^CPU {

    cpu           := new(CPU)
    cpu.name       = name
    cpu.setpc      = w65c816_setpc
    cpu.reset      = w65c816_reset
    cpu.exec       = w65c816_exec
    //cpu.clear_irq  = w65c816_clear_irq
    cpu.delete     = w65c816_delete
    cpu.bus        = bus
    cpu.all_cycles = 0

    c             := CPU_65C816{cpu = cpu, type = CPU_65C816_type.W65C816S}
    c.a            = DataRegister_65C816{}
    c.x            = DataRegister_65C816{}
    c.y            = DataRegister_65C816{}
    c.t            = DataRegister_65C816{}
    c.tb           = DataRegister_65C816{size = byte}
    c.tw           = DataRegister_65C816{size = word}
    c.pc           = AddressRegister_65C816{bwrap = true}
    c.sp           = AddressRegister_65C816{bwrap = true}
    c.ab           = AddressRegister_65C816{bwrap = true}
    c.ta           = AddressRegister_65C816{bwrap = true}
    cpu.model      = c

    // we need global because of external musashi
    localbus   = bus

    //w65c816_init();
    return cpu
}

w65c816_setpc :: proc(cpu: ^CPU, address: u32) {
    c         := &cpu.model.(CPU_65C816)
    c.pc.addr  = u16( address & 0x0000_FFFF       )
    c.pc.bank  = u16((address & 0x00FF_0000) >> 16)
    return
}

w65c816_delete :: proc(cpu: ^CPU) {
    free(cpu)
    return
}

// ----------------------------------------------------------------------------
// interrupt routines
//
// e = 0    e = 1
// ------   ------
// 00FFE4   00FFF4   COP
// 00FFE6   00FFFE   BRK
// 00FFE8   00FFF8   ABORT
// 00FFEA   00FFFA   NMI
//          00FFFC   RESET
// 00FFEE   00FFFE   IRQ
 
// it is worth to mention that RESET nor power-on does not 
// set low byte of Stack Pointer, and it needs to be set
// explicitly in code
//
// also: "The internal clock, which is driven by the Ø2 clock generator
// circuit, will be restarted if it had previously been stopped by an STP 
// or WAI instruction" [3]
//
// 1. http://forum.6502.org/viewtopic.php?f=4&t=2258
// 2. ["Programming the 65816", 1992, pages 55, 201]
// 3. http://6502.org/tutorials/65c816interrupts.html#toc:interrupt_reset

w65c816_reset :: proc(cpu: ^CPU) {
    c          := &cpu.model.(CPU_65C816)

    c.sp.addr   = (c.sp.addr & 0x00FF) | 0x0100
    c.d         = 0
    c.dbr       = 0
    c.x.val    &= 0x00FF
    c.y.val    &= 0x00FF

    c.f.E       = true
    c.f.M       = true
    c.f.X       = true
    c.f.D       = false
    c.f.I       = true

    c.ab.bank   = 0
    c.ab.addr   = 0xFFFC
    c.pc.addr   = read_m( c.ab, word )
    c.pc.bank   = 0

    // internal variables
    if c.a.size == word {
        c.a.b     = c.a.val & 0xFF00
    }
    c.a.size    = byte
    c.t.size    = byte
    c.x.size    = byte
    c.y.size    = byte
    c.in_mvn    = false
    c.in_mvp    = false

    return
}

// XXX: abort interrupt - not implemented properly
//      it should abort command and discard all changes...
//
// XXX: COP, BRK, NMI, IRQ has almost the same code
w65c816_abort :: proc(using c: ^CPU_65C816) {

    cycles        = 8

    if !f.E {
        tb.val    = pc.bank
        _         = push_r( sp, tb      )
        sp.addr   = subu_r( sp, tb.size )
    } else {
        f.X       = false                   // f.B in emulation mode
        cycles   -= 1
    }

    tw.val    = pc.addr
    tw.val   += 1                           // specification say "+2" but mode_ sets +1
    _         = push_r( sp, tw      )
    sp.addr   = subu_r( sp, tw.size )

    oper_PHP(c)

    f.I       = true
    f.D       = false
    ab.bank   = 0
    ab.addr   = 0xFFF8 if f.E else 0xFFE8
    pc.bank   = 0
    pc.addr   = read_m( ab, word )
}

w65c816_irq :: proc(using c: ^CPU_65C816) {

    if f.I do return

    cycles        = 8

    if !f.E {
        tb.val    = pc.bank
        _         = push_r( sp, tb      )
        sp.addr   = subu_r( sp, tb.size )
    } else {
        f.X       = false                   // f.B in emulation mode to dist. from BRK
        cycles   -= 1
    }

    tw.val    = pc.addr
    tw.val   += 1                           // specification say "+2" but mode_ sets +1
    _         = push_r( sp, tw      )
    sp.addr   = subu_r( sp, tw.size )

    oper_PHP(c)

    f.I       = true
    f.D       = false
    ab.bank   = 0
    ab.addr   = 0xFFFE if f.E else 0xFFEE
    pc.bank   = 0
    pc.addr   = read_m( ab, word )
}
	
w65c816_nmi :: proc(using c: ^CPU_65C816) {

    cycles        = 8

    if !f.E {
        tb.val    = pc.bank
        _         = push_r( sp, tb      )
        sp.addr   = subu_r( sp, tb.size )
    } else {
        f.X       = false                   // f.B in emulation mode
        cycles   -= 1
    }

    tw.val    = pc.addr
    tw.val   += 1                           // specification say "+2" but mode_ sets +1
    _         = push_r( sp, tw      )
    sp.addr   = subu_r( sp, tw.size )

    oper_PHP(c)

    f.I       = true
    f.D       = false
    ab.bank   = 0
    ab.addr   = 0xFFFA if f.E else 0xFFEA
    pc.bank   = 0
    pc.addr   = read_m( ab, word )

}

w65c816_exec :: proc(cpu: ^CPU, ticks: u32 = 1000) {
    c := &cpu.model.(CPU_65C816)
    current_ticks : u32 = 0

    // XXX: implement here something like that
    //      we need an new pic implementation
    // XXX: maybe that logic should be at platform level?
    //
    //    if localbus.pic.irq_active == false && localbus.pic.current != pic.IRQ.NONE {
    //        log.debugf("%s IRQ should be set!", cpu.name)
    //        localbus.pic.irq_active = true
    //        log.debugf("IRQ active from exec %v irq %v", localbus.pic.irq_active, localbus.pic.irq)
    //        m68k_set_irq(localbus.pic.irq)
    //    }

    if ticks == 0 {
        w65c816_execute(c)
        return
    }

    return
}

w65c816_execute :: proc(cpu: ^CPU_65C816) {

    switch {
    case cpu.in_mvn:
          oper_MVN(cpu)
          cpu.cycles    += cycles_65c816[cpu.ir]

    case cpu.in_mvp:
         oper_MVP(cpu)
          cpu.cycles    += cycles_65c816[cpu.ir]
    case:
          cpu.px       = false
          cpu.ir       = u8(read_m(cpu.pc, byte)) // XXX: u16?
          cpu.cycles   = cycles_65c816[cpu.ir]
          cpu.ab.index = 0                     // XXX: move to addressing modes?
          cpu.ab.pwrap = false                 // XXX: move to addressing modes?
          w65c816_run_opcode(cpu)
    }

    cpu.cycles  += incCycles_PageCross[cpu.ir]     if cpu.px && cpu.f.X   else 0
    cpu.cycles  -= decCycles_flagM[cpu.ir]         if cpu.f.M             else 0
    cpu.cycles  -= decCycles_flagX[cpu.ir]         if cpu.f.X             else 0
    cpu.cycles  += incCycles_regDL_not00[cpu.ir]   if cpu.d & 0x00FF != 0 else 0

    return
}

// add unsigned to index register
addu_r_reg :: #force_inline proc (dr: DataRegister_65C816, a: u16)     -> (result: u16) {
    if dr.size == byte {
        high   := dr.val & 0xFF00
        result  = dr.val + a
        result &= 0x00FF
        result |= high
    } else {
        result = dr.val + a
    }
    return
}

addu_r_addr :: #force_inline proc (ar: AddressRegister_65C816, size: bool)     -> (result: u16) {
    a : u16 = 1 if size==byte else 2

    if ar.size == byte {
        high   := ar.addr & 0xFF00
        result  = ar.addr + a
        result &= 0x00FF
        result |= high
    } else {
        result = ar.addr + a
    }
    return
}

subu_r_reg :: #force_inline proc (dr: DataRegister_65C816, a: u16)     -> (result: u16) {
    if dr.size == byte {
        high   := dr.val & 0xFF00
        result  = dr.val - a
        result &= 0x00FF
        result |= high
    } else {
        result = dr.val - a
    }
    return
}

subu_r_addr :: #force_inline proc (ar: AddressRegister_65C816, size: bool)     -> (result: u16) {
    a : u16 = 1 if size==byte else 2

    if ar.size == byte {
        high   := ar.addr & 0xFF00
        result  = ar.addr - a
        result &= 0x00FF
        result |= high
    } else {
        result = ar.addr - a
    }
    return
}

subu_r_val  :: #force_inline proc (val: u16, size: bool)     -> (result: u16) {
    a : u16 = 1 if size==byte else 2

    result  = val - a
    return
}


subu_r :: proc { subu_r_reg, subu_r_addr, subu_r_val }
addu_r :: proc { addu_r_reg, addu_r_addr }

read_m :: #force_inline proc (ar: AddressRegister_65C816, size: bool) -> (result: u16) {
    ea, high: u32

    if ar.pwrap {
        high  = u32(ar.addr) & 0xFF00
        ea    = u32(ar.addr) + u32(ar.index)
        ea   &= 0x00FF
        ea   |= high
    } else {
        ea    = u32(ar.addr) + u32(ar.index)
    }

    ea     &= 0x0000_ffff if ar.bwrap else 0xffff_ffff
    ea     += u32(ar.bank) << 16
    ea     &= 0x00ff_ffff
    result  = u16(localbus->read(.bits_8, ea))

    if size == word {
        if ar.pwrap {
            high  = u32(ar.addr) & 0xFF00
            ea    = u32(ar.addr) + u32(ar.index) + 1
            ea   &= 0x00FF
            ea   |= high
        } else {
            ea    = u32(ar.addr) + u32(ar.index) + 1
        }

        ea     &= 0x0000_ffff if ar.bwrap else 0xffff_ffff
        ea     += u32(ar.bank) << 16
        ea     &= 0x00ff_ffff
        result |= u16(localbus->read(.bits_8, ea)) << 8
    }
    return
}

read_r :: #force_inline proc (reg: DataRegister_65C816, size: bool) -> (result: u16) {
    switch size {
    case byte:
        result =  reg.val & 0x00FF
    case word:
        result = (reg.val & 0x00FF) | reg.b if reg.size else reg.val
    }
    return result
}

read_a :: #force_inline proc (reg: AddressRegister_65C816, size: bool) -> (result: u16) {
    switch size {
    case byte:
        result = reg.addr & 0x00FF
    case word:
        result = reg.addr
    }
    return result
}

// XXX: used only in one case (JSL) - optimize that?
push_r_addr :: #force_inline proc (addr: u16, dr: DataRegister_65C816) -> bool {
    value   := u32( read_r( dr, dr.size ) )
    if dr.size == word {
        localbus->write(.bits_8, u32(addr    ), (value & 0xFF00) >> 8)
        localbus->write(.bits_8, u32(addr - 1),  value & 0xFF  )
    } else {
        localbus->write(.bits_8, u32(addr    ),  value & 0xFF  )
    }
    return false
}

push_r_reg :: #force_inline proc (ar: AddressRegister_65C816, dr: DataRegister_65C816) -> bool {
    value   := u32( read_r( dr, dr.size ) )
    ar      := ar

    if dr.size == word {
        localbus->write(.bits_8, u32(ar.addr), (value & 0xFF00) >> 8)
        ar.addr = subu_r(ar, byte)
        localbus->write(.bits_8, u32(ar.addr), value & 0xFF)
    } else {
        localbus->write(.bits_8, u32(ar.addr), value & 0xFF)
    }
    return false
}

push_r :: proc { push_r_addr, push_r_reg }

pull_v :: #force_inline proc (ar: AddressRegister_65C816, size: bool) -> (result: u16) {
    ar      := ar

    ar.addr = addu_r(ar, byte)
    result = u16(localbus->read(.bits_8, u32(ar.addr)))

    if size == word {
        ar.addr  = addu_r(ar, byte)
        result  |= u16(localbus->read(.bits_8, u32(ar.addr))) << 8
    }
    return 
}


stor_m :: #force_inline proc (ar: AddressRegister_65C816, dr: DataRegister_65C816) -> bool {
    value  := u32( read_r( dr, dr.size ) )

    ea, high : u32

    if ar.pwrap {
        high  = u32(ar.addr) & 0xFF00
        ea    = u32(ar.addr) + u32(ar.index)
        ea   &= 0x00FF
        ea   |= high
    } else {
        ea    = u32(ar.addr) + u32(ar.index)
    }

    ea     &= 0x0000_FFFF if ar.bwrap else 0xFFFF_FFFF
    ea     += u32(ar.bank) << 16
    ea     &= 0x00ff_ffff
    localbus->write(.bits_8, ea, value & 0xFF)

    if dr.size == word {
        if ar.pwrap {
            high  = u32(ar.addr) & 0xFF00
            ea    = u32(ar.addr) + u32(ar.index) + 1
            ea   &= 0x00FF
            ea   |= high
        } else {
            ea    = u32(ar.addr) + u32(ar.index) + 1
        }
        ea     &= 0x0000_FFFF if ar.bwrap else 0xFFFF_FFFF
        ea     += u32(ar.bank) << 16
        ea     &= 0x00ff_ffff
        localbus->write(.bits_8, ea, (value & 0xFF00) >> 8)
    }

    return false
}

adds_b :: #force_inline proc (a, b: u16) -> (result: u16) {
    if b >= 0x80   {
        result = a + b - 0x100
    } else {
        result = a + b
    }
    return
}

adds_w :: #force_inline proc (a, b: u16) -> (result: u16) {
    if b >= 0x8000 {
        result  = a + b - 0xFFFF
        result -= 1                 // because -0x1_0000 doesn't fit in u16
    } else {
        result  = a + b
    }
    return
}

// detection of page crossing, used for cycle cost calculations
test_p_reg :: #force_inline proc (ar: AddressRegister_65C816) ->  bool {
    return ((ar.addr & 0xFF00) != ((ar.addr+ar.index) & 0xFF00))
}

test_p_val :: #force_inline proc (a, b: u16) -> bool {
    return (a & 0xFF00) != (b & 0xFF00)
}

test_p :: proc { test_p_reg, test_p_val }

// negative flag test
// XXX: there is a possibility to make single routine test_n(val, size)
//
test_n_reg :: #force_inline proc (dr: DataRegister_65C816)    -> (result: bool) {
    switch dr.size {
    case byte: result = (dr.val &   0x80) ==   0x80
    case word: result = (dr.val & 0x8000) == 0x8000
    }
    return result
}

test_n_val :: #force_inline proc (val: u16, size: bool)    -> (result: bool) {
    switch size {
    case byte: result = (val &   0x80) ==   0x80
    case word: result = (val & 0x8000) == 0x8000
    }
    return result
}

test_n :: proc { test_n_reg, test_n_val }

// zero value test
test_z_reg :: #force_inline proc (dr: DataRegister_65C816)    -> (result: bool) {
    switch dr.size {
    case byte: result = dr.val & 0xFF == 0x00
    case word: result = dr.val        == 0x00
    }
    return result
}

test_z_val :: #force_inline proc (val: u16, size: bool)       -> (result: bool) {
    switch size {
    case byte: result = val & 0xFF == 0x00
    case word: result = val        == 0x00
    }
    return result
}

test_z     ::               proc { test_z_reg, test_z_val }

// bit 0 test - for LSR, ROR...
test_0 :: #force_inline proc (dr: DataRegister_65C816)    -> bool {
    return (dr.val & 1) == 1
}         

// special case for single command, BIT - testing second highest
test_s :: #force_inline proc (dr: DataRegister_65C816)    -> (result: bool) {
    switch dr.size {
    case byte: result = dr.val &   0x40 ==   0x40
    case word: result = dr.val & 0x4000 == 0x4000
    }
    return result
}

// "the overflow flag is set when the sign of the addends
//  is the same and differs from the sign of the sum"
//
// XXX - check if we really need to pass sum
test_v_v1 :: #force_inline proc(size: bool, a, b, s: u32) -> (result: bool) {
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

// XXX: in case of u32 register and 8/16 bit operations we
//      need simply check change on "upper" bits to detect
//      overflow?
test_v_v2 :: #force_inline proc(size: bool, sum: u32) -> (overflow: bool) {
    switch size {
    case byte:    overflow = (sum & 0xFFFF_FF00) != 0
    case word:    overflow = (sum & 0xFFFF_0000) != 0
    }
    return 
}

test_v :: proc { test_v_v1, test_v_v2 }


// set or clear highest bit (15 or 7, according to register size) 
// used in LSR and ROR
set__h :: #force_inline proc (dr: DataRegister_65C816, a: bool)    -> (result: u16) {
    if a {
        result = dr.val | (0x80 if dr.size else 0x8000)
    } else {
        result = dr.val & (0x7F if dr.size else 0x7FFF)
    }
    return result
}

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
    ab.addr   = read_m( pc, word )
    ab.bank   = dbr
    ab.bwrap  = false
    pc.addr  += 2
}

mode_Absolute_PBR           :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, word )
    ab.bank   = pc.bank
    ab.bwrap  = false
    pc.addr  += 2
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
    ab.addr   = read_m( pc, word )
    ab.bank   = dbr
    ab.bwrap  = false
    ab.index  = x.val
    px        = test_p( ab )
    pc.addr  += 2
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
    ab.addr   = read_m( pc, word )
    ab.bank   = dbr
    ab.bwrap  = false
    ab.index  = y.val
    px        = test_p( ab )
    pc.addr  += 2
}

// XXX
// If, for whatever reason, you do not wish to have direct page wrap around in
// emulation mode, it will not occur when the DL register is nonzero. 
// [Bruce Clark, 2015]


//
// CPU:           all
// OPC ($LL,X)    operand is zeropage address; effective address is word
//                $00LL+X    data lo
//                $00LL+X+1  data hi
mode_DP_X_Indirect          :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, byte )  // 0 | D + LL + X
    pc.addr  += 1
    ab.addr  += d 
    ab.bank   = 0
    ab.index  = x.val
    ab.bwrap  = true
    ab.pwrap  = true if f.E && (d & 0x00FF == 0) else false  // XXX prettified?

    ab.addr   = read_m( ab, word )  // dbr hh ll
    ab.bank   = dbr
    ab.index  = 0
    ab.bwrap  = false
    ab.pwrap  = false
}

//
// CPU: all, except MOS 6502
// OPC ($LL)      operand is zeropage address;
//                effective address is word in (LL):  C.w($00LL)
mode_DP_Indirect            :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, byte )  // 0 | D + LL
    pc.addr  += 1
    ab.addr  += d
    ab.bank   = 0
    ab.bwrap  = true
    ab.pwrap  = true if f.E && (d & 0x00FF == 0) else false  // XXX prettified?

    ab.addr   = read_m( ab, word )  // dbr hh ll
    ab.bank   = dbr
    ab.bwrap  = false
    ab.pwrap  = false
}

//
// CPU: all
// OPC ($LL),Y    operand is zeropage address;
//                effective address is word in (LL, LL + 1)
//                incremented by Y with carry: C.w($00LL) + Y

// Again, note that this is one of the rare instances where emulation mode has
// different behavior than the 65C02 or NMOS 6502. Since the 65C02 and NMOS
// 6502 have a 16-bit address space, if the address of the data were $FFFE+Y
// and the Y register were $0A, the address of the data would be $0008. On the
// 65C816, the address of the data would be $010008 (assuming the DBR was $00).
// In practice, this is typically not a problem, since code written for the
// 65C02 or NMOS 6502 would almost never use a pointer that would wrap at the
// 16-bit address space boundary like that. 
// 
// [Bruce Clark (2015) "65C816 Opcodes"]

mode_DP_Indirect_Y          :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, byte )  // 0 | D + LL
    pc.addr  += 1
    ab.addr  += d
    ab.bank   = 0
    ab.bwrap  = true
    ab.pwrap  = true if f.E && (d & 0x00FF == 0) else false  // XXX prettified?

    ab.addr   = read_m( ab, word )  // dbr hh ll + Y
    ab.bank   = dbr
    ab.index  = read_r( y, y.size )
    ab.bwrap  = false
    ab.pwrap  = false
    px        = test_p( ab )
}

mode_S_Relative_Indirect_Y  :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, byte )  // 0 | S + LL
    pc.addr  += 1
    ab.addr  += sp.addr
    ab.bank   = 0
    ab.bwrap  = true
    ab.pwrap  = false

    ab.addr   = read_m( ab, word )  // dbr hh ll + Y
    ab.bank   = dbr
    ab.index  = y.val
    ab.bwrap  = false
    ab.pwrap  = false
}

//
// CPU: 
// OPC [$LL]      operand is zeropage address;
//                effective address is word in (LL):  C.w($00LL)
mode_DP_Indirect_Long       :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1 
    ta.addr   = read_m( pc, byte )  // 0 | D + LL
    pc.addr  += 1
    ta.addr  += d
    ta.bank   = 0
    ta.bwrap  = true

    ab.addr   = read_m( ta, word )  // hh ll
    ta.addr  += 2
    ab.bank   = read_m( ta, byte )  // top
    ab.bwrap  = false
}

mode_DP_Indirect_Long_Y    :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1 
    ta.addr   = read_m( pc, byte )  // 0 | D + LL
    pc.addr  += 1
    ta.addr  += d
    ta.bank   = 0
    ta.bwrap  = true

    ta.pwrap  = false
    ab.addr   = read_m( ta, word )  // hh ll
    ta.addr  += 2
    ab.bank   = read_m( ta, byte )  // top
    ab.index  = y.val
    ab.bwrap  = false
}

// OPC $BBHHLL
mode_Absolute_Long          :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1 
    ab.addr   = read_m( pc, word )  // HH LL
    pc.addr  += 2
    ab.bank   = read_m( pc, byte )  // BB
    pc.addr  += 1 
    ab.bwrap  = true
}

// OPC $BBHHLL, X
mode_Absolute_Long_X        :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1 
    ab.addr   = read_m( pc, word )  // HH LL
    pc.addr  += 2
    ab.bank   = read_m( pc, byte )  // BB
    pc.addr  += 1 
    ab.bwrap  = false
    ab.index  = x.val
}

// PC relative mode: value is added to PC that already points at NEXT OP
// OPC $LL
mode_PC_Relative            :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, byte )              // relative calculated form pc of next cmd
    pc.addr  += 1
    ab.addr   = adds_b( pc.addr, ab.addr )
    px        = test_p( pc.addr, ab.addr )
    ab.bank   = pc.bank
}

mode_PC_Relative_Long       :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, word )
    pc.addr  += 2 
    ab.addr   = adds_w( pc.addr, ab.addr )
    px        = test_p( pc.addr, ab.addr )
    ab.bank   = pc.bank
}

//
// CPU: all
// OPC $LL        operand is zeropage address, hi-byte is zero address
//                $00LL      data
mode_DP                     :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, byte )
    pc.addr  += 1
    ab.addr  += d
    ab.bank   = 0
    ab.index  = 0
    ab.bwrap  = true
}
//
// CPU: all
// OPC $LL,X     operand is zeropage address;
//               effective address is address incremented by X without carry [2]
mode_DP_X                   :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, byte )
    pc.addr  += 1
    ab.addr  += d
    ab.bank   = 0
    ab.index  = x.val
    ab.bwrap  = true
    ab.pwrap  = true if f.E && (d & 0x00FF == 0) else false  // XXX prettified?
}

//
// CPU: all
// OPC $LL,Y      operand is zeropage address;
//                effective address is address incremented by Y without carry [2]
mode_DP_Y                   :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, byte )
    pc.addr  += 1
    ab.addr  += d
    ab.bank   = 0
    ab.index  = y.val
    ab.bwrap  = true
    ab.pwrap  = true if f.E && (d & 0x00FF == 0) else false  // XXX prettified?
}

mode_S_Relative             :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, byte )
    pc.addr  += 1
    ab.bank   = 0
    ab.index  = sp.addr
    ab.bwrap  = true
}


//
// CPU: all, except MOS 6502
// OPC ($LLHH,X)  operand is address;
//                effective address is word in (HHLL+X), inc. with carry: C.w($HHLL+X)
mode_Absolute_X_Indirect       :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, word )  // K | D + HH + LL + X
    ab.bank   = pc.bank
    ab.index  = x.val
    ab.bwrap  = true

    ab.addr   = read_m( ab, word )  // k hh ll
    ab.index  = 0
    pc.addr  += 2
}

mode_Absolute_Indirect         :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, word )  // 0 | D + HH + LL 
    ab.bank   = 0
    ab.bwrap  = true

    ab.addr   = read_m( ab, word )  // k hh ll
    ab.bank   = pc.bank
    pc.addr  += 2
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
    ta.addr   = read_m( pc, word )
    pc.addr  += 1                   // innefective, just for completness
    ta.bank   = 0
    ta.bwrap  = true

    ab.addr   = read_m( ta, word )  // hh ll
    ta.addr  += 2
    ab.bank   = read_m( ta, byte )  // top
    ab.bwrap  = false
}

//
// CPU: all
// OPC A          operand is AC (implied single byte instruction)
mode_Accumulator            :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
}


//
// CPU: all
// OPC #$BB       operand is byte BB
mode_Immediate              :: #force_inline proc (using c: ^CPU_65C816) {
    ab        = pc
    ab.addr  += 1
    pc.addr  += 2
}

mode_Immediate_flag_M       :: #force_inline proc (using c: ^CPU_65C816) {
    ab        = pc
    ab.addr  += 1
    pc.addr  += 2 if f.M == byte else 3
}

mode_Immediate_flag_X       :: #force_inline proc (using c: ^CPU_65C816) {
    ab        = pc
    ab.addr  += 1
    pc.addr  += 2 if f.X == byte else 3
}

// only for MVN/MVP
mode_BlockMove              :: #force_inline proc (using c: ^CPU_65C816) {
    ab        = pc
    ab.addr  += 1
    pc.addr  += 2
}

//
// CPU: all
// OPC            operand implied
mode_Implied                :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
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

// XXX: it looks currently so bad, consider 32-bit register backends
oper_ADC                    :: #force_inline proc (using c: ^CPU_65C816) { 
    if f.D == false {
        data1    := u32(read_r(a, a.size ))
        tmp      := data1
        data2    := u32(read_m( ab, a.size ))
        data1    += data2
        data1    += 1 if f.C else 0
        f.V       = test_v( a.size, tmp, data2, data1 )
        a.val     = u16(data1)
        f.C       = test_v( a.size, data1 )
        f.N       = test_n( a )
        f.Z       = test_z( a )
    } else {
        data1    := u32(read_r(a, a.size ))
        data0     = read_m( ab, a.size )
        data2    := u32(data0)

        carry    := u32(1) if f.C    else 0
        o        := (data1 & 0x0F) + (data2 & 0x0F) + carry
        o        += 0x06 if o > 0x09 else 0              // decimal correction
        carry     = 0x10 if o > 0x0f else 0              // carry of first nybble
        o         = (o & 0x0f) + (data1 & 0xF0) + (data2 & 0xF0) + carry
        f.V       = test_v( a.size, u32(data1), u32(data0), u32(o)    )
        o        += 0x60 if o > 0x9f else 0              // decimal correction

        if f.M == word {
            carry    = 0x0100 if o > 0xFF   else 0
            o        = (o & 0xff) + (data1 & 0x0F00) + (data2 & 0x0F00) + carry
            o       += 0x600  if o > 0x9FF  else 0
            carry    = 0x1000 if o > 0xFFF  else 0
            o        = (o & 0xfff) + (data1 & 0xF000) + (data2 & 0xF000) + carry
            f.V      = test_v( a.size, u32(data1), u32(data0), u32(o)    )
            o       += 0x6000 if o > 0x9FFF else 0
        }
        
        a.val     = u16(o)
        f.C       = o > 0xFF if f.M else o > 0xFFFF
        f.N       = test_n( a )
        f.Z       = test_z( a )
    }
}

oper_AND                    :: #force_inline proc (using c: ^CPU_65C816) {
    t.val     = read_m( ab, a.size )
    a.val    &= t.val
    f.N       = test_n( a     )
    f.Z       = test_z( a     )
}

// C <- [76543210] <- 0  (mem)               nv*bdizc
//                                           m.....mm
oper_ASL                  :: #force_inline proc (using c: ^CPU_65C816) {
    t.val     = read_m( ab, a.size )
    f.C       = test_n( t          )
    t.val   <<= 1
    f.N       = test_n( t          )
    f.Z       = test_z( t          )
    _         = stor_m( ab, t      )
}
    
// C <- [76543210] <- 0  (acc)               nv*bdizc
//                                           m.....mm
oper_ASL_A                 :: #force_inline proc (using c: ^CPU_65C816) {
    t.val     = read_r( a, a.size )
    f.C       = test_n( t         )
    t.val   <<= 1
    f.N       = test_n( t         )
    f.Z       = test_z( t         )
    a.val     = read_r( t, a.size )  // a.val and 0x00FF in short mode
}

oper_BCC                    :: #force_inline proc (using c: ^CPU_65C816) {
    if ! f.C {
        pc.addr   = ab.addr
        cycles   += 2       if f.E && px else 1
    }
}

oper_BCS                    :: #force_inline proc (using c: ^CPU_65C816) {
    if   f.C {
        pc.addr   = ab.addr
        cycles   += 2       if f.E && px else 1
    }
}

oper_BEQ                    :: #force_inline proc (using c: ^CPU_65C816) {
    if   f.Z {
        pc.addr   = ab.addr
        cycles   += 2       if f.E && px else 1
    }
}

oper_BIT                     :: #force_inline proc (using c: ^CPU_65C816) {
    t.val     = read_m( ab, a.size )
    f.N       = test_n( t )
    f.V       = test_s( t )            // second highest bit
    t.val    &= a.val
    f.Z       = test_z( t )
}

// Immediate does not set N nor V
oper_BIT_IMM                  :: #force_inline proc (using c: ^CPU_65C816) {
    t.val     = read_m( ab, a.size )
    t.val    &= a.val
    f.Z       = test_z( t )
}

oper_BMI                    :: #force_inline proc (using c: ^CPU_65C816) {
    if   f.N {
        pc.addr   = ab.addr
        cycles   += 2       if f.E && px else 1
    }
}

oper_BNE                    :: #force_inline proc (using c: ^CPU_65C816) {
    if ! f.Z {
        pc.addr   = ab.addr
        cycles   += 2       if f.E && px else 1
    }
}

oper_BPL                    :: #force_inline proc (using c: ^CPU_65C816) {
    if ! f.N {
        pc.addr   = ab.addr
        cycles   += 2       if f.E && px else 1
    }
}

oper_BRA                    :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr   = ab.addr
    cycles   += 1          if f.E && px else 0
}

// In emulation mode, BRK and COP push the 16-bit address (again high byte
// first, then low byte) of the BRK or COP instruction plus 2, then push the
// P register, then jump to the appropriate (16-bit) emulation mode interrupt
// vector. The emulation mode BRK vector is at $00FFFE and the emulation mode
// COP vector is at $00FFF4. When BRK pushes the P register, the b flag (i.e.
// bit 5) will be set; because, in emulation mode, as on the NMOS 6502 and
// 65C02, BRK and IRQ share an interrupt vector, this allows the BRK/IRQ
// handler to distinguish a BRK from an IRQ. COP in emulation mode may seem
// somewhat paradoxical, since it was not available on the NMOS 6502 or 65C02,
// but COP can be used in emulation mode, and when pushing onto the stack it
// will wrap at the page 1 boundary (in other words, it is treated as an "old"
// instruction, rather than a "new" instruction). 
//
// [Bruce Clark (2015) "65C816 Opcodes"]
//
//
// masking by I flag?
// 
oper_BRK                    :: #force_inline proc (using c: ^CPU_65C816) { 
    if !f.E {
        tb.val    = pc.bank
        _         = push_r( sp, tb      )
        sp.addr   = subu_r( sp, tb.size )
    } else {
        f.X       = true                    // f.B in emulation mode
        cycles   -= 1
    }

    tw.val    = pc.addr
    tw.val   += 1                           // specification say "+2" but mode_ sets +1
    _         = push_r( sp, tw      )
    sp.addr   = subu_r( sp, tw.size )

    oper_PHP(c)

    f.I       = true
    f.D       = false
    ab.bank   = 0
    ab.addr   = 0xFFFE if f.E else 0xFFE6
    pc.bank   = 0
    pc.addr   = read_m( ab, word )
}


oper_BRL                    :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr   = ab.addr
}

oper_BVC                    :: #force_inline proc (using c: ^CPU_65C816) {
    if ! f.V {
        pc.addr   = ab.addr
        cycles   += 2       if f.E && px else 1
    }
}

oper_BVS                    :: #force_inline proc (using c: ^CPU_65C816) {
    if   f.V {
        pc.addr   = ab.addr
        cycles   += 2       if f.E && px else 1
    }
}

oper_CLC                    :: #force_inline proc (using c: ^CPU_65C816) {
    f.C       = false
}

oper_CLD                    :: #force_inline proc (using c: ^CPU_65C816) {
    f.D       = false
}

oper_CLI                    :: #force_inline proc (using c: ^CPU_65C816) {
    f.I       = false
}

oper_CLV                    :: #force_inline proc (using c: ^CPU_65C816) {
    f.V       = false
}

oper_CMP                    :: #force_inline proc (using c: ^CPU_65C816) {
    t.size    = a.size
    t.val     = read_m( ab, t.size )
    t.val     = subu_r(  a, t.val  )
    f.N       = test_n(  t         )
    f.Z       = test_z(  t         )
    f.C       = read_r(  a, a.size )  >= read_r(t, t.size)    // I wish I had a getter
}

oper_COP                    :: #force_inline proc (using c: ^CPU_65C816) {
    if !f.E {
        tb.val    = pc.bank
        _         = push_r( sp, tb      )
        sp.addr   = subu_r( sp, tb.size )
    } else {
        cycles   -= 1
    }

    tw.val    = pc.addr
    _         = push_r( sp, tw      )
    sp.addr   = subu_r( sp, tw.size )

    oper_PHP(c)

    f.I       = true
    f.D       = false
    ab.bank   = 0
    ab.addr   = 0xFFF4 if f.E else 0xFFE4
    pc.bank   = 0
    pc.addr   = read_m( ab, word )
}

oper_COP_E                  :: #force_inline proc (using c: ^CPU_65C816) { }

oper_CPX                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.size    = x.size
    t.val     = read_m( ab, t.size )
    t.val     = subu_r(  x, t.val  )
    f.N       = test_n(  t         )
    f.Z       = test_z(  t         )
    f.C       = read_r(  x, x.size )  >= t.val    // I wish I had a getter
    t.size    = a.size                            // restore standard behaviour
}

oper_CPY                    :: #force_inline proc (using c: ^CPU_65C816) {
    t.size    = y.size
    t.val     = read_m( ab, t.size )
    t.val     = subu_r(  y, t.val  )
    f.N       = test_n(  t         )
    f.Z       = test_z(  t         )
    f.C       = read_r(  y, y.size )  >= t.val    // I wish I had a getter
    t.size    = a.size                            // restore standard behaviour
}

oper_DEC                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.val     = read_m( ab, a.size )
    t.val     = subu_r( t, 1  )
    f.N       = test_n( t     )
    f.Z       = test_z( t     )
    _         = stor_m( ab, t )
}

oper_DEC_A                  :: #force_inline proc (using c: ^CPU_65C816) {
    a.val     = subu_r( a, 1 )
    f.N       = test_n( a    )
    f.Z       = test_z( a    )
}

oper_DEX                    :: #force_inline proc (using c: ^CPU_65C816) {
    x.val     = subu_r( x, 1 )
    f.N       = test_n( x    )
    f.Z       = test_z( x    )
}

oper_DEY                    :: #force_inline proc (using c: ^CPU_65C816) {
    y.val     = subu_r( y, 1 )
    f.N       = test_n( y    )
    f.Z       = test_z( y    )
}

oper_EOR                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.val     = read_m( ab, a.size )
    a.val    ~= t.val
    f.N       = test_n( a     )
    f.Z       = test_z( a     )
}

oper_INC                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.val     = read_m( ab, a.size )
    t.val     = addu_r( t, 1  )
    f.N       = test_n( t     )
    f.Z       = test_z( t     )
    _         = stor_m( ab, t )
}

oper_INC_A                  :: #force_inline proc (using c: ^CPU_65C816) {
    a.val     = addu_r( a, 1 )
    f.N       = test_n( a    )
    f.Z       = test_z( a    )
}

oper_INX                    :: #force_inline proc (using c: ^CPU_65C816) {
    x.val     = addu_r( x, 1 )
    f.N       = test_n( x    )
    f.Z       = test_z( x    )
}

oper_INY                    :: #force_inline proc (using c: ^CPU_65C816) {
    y.val     = addu_r( y, 1 )
    f.N       = test_n( y    )
    f.Z       = test_z( y    )
}

oper_JMP                    :: #force_inline proc (using c: ^CPU_65C816) { 
    pc.bank   = ab.bank
    pc.addr   = ab.addr
}

// XXX: jsl and jsr workaround due to lack specialized push_*
// XXX: specialized word-sized registers?
// XXX: or specialized push_procedures?
// XXX: should mode_* set commands to next operand or not
//      here we need to sp.addr -= 1 and that is unnatural
//      but fits nice for relative jump operands...

// In this connection it is important to be aware that, although the high byte
// of the stack register is consistently forced to one, new 65816 opcodes
// executed in the emulation mode will not wrap the stack if the low byte over-
// or underflowed in the middle of an instruction. For example, if the stack
// pointer is equal to $101, and a JSL is executed, the final byte of the three
// bytes pushed on the stack will be at $FF, not $1FF; but the stack pointer at
// the end of the instruction will point to $1FE. However, if JSR (a 6502
// instruction) is executed in the emulation mode with the stack pointer equal
// to $100, the second of the two bytes pushed will be stored at $1FF.
//
// [programming..., page 278]
//
oper_JSL                    :: #force_inline proc (using c: ^CPU_65C816) { 
    tb.val    = pc.bank
    data0     = sp.addr
    _         = push_r( data0, tb      )
    sp.addr   = subu_r(    sp, tb.size )
    data0     = subu_r( data0, tb.size )

    tw.val    = pc.addr
    tw.val   -= 1                          // mode_ sets pc to next command
    _         = push_r( data0, tw      )
    sp.addr   = subu_r(    sp, tw.size )
    pc.bank   = ab.bank
    pc.addr   = ab.addr
}

oper_JSR                    :: #force_inline proc (using c: ^CPU_65C816) { 
    tw.val    = pc.addr
    tw.val   -= 1                          // mode_ sets pc to next command
    _         = push_r( sp, tw      )
    sp.addr   = subu_r( sp, tw.size )
    pc.addr   = ab.addr
}

oper_LDA                    :: #force_inline proc (using c: ^CPU_65C816) { 
    a.val     = read_m( ab, a.size )
    f.N       = test_n( a          )
    f.Z       = test_z( a          )
}

oper_LDX                    :: #force_inline proc (using c: ^CPU_65C816) { 
    x.val     = read_m( ab, x.size )
    f.N       = test_n( x          )
    f.Z       = test_z( x          )
}

oper_LDY                    :: #force_inline proc (using c: ^CPU_65C816) { 
    y.val     = read_m( ab, y.size )
    f.N       = test_n( y          )
    f.Z       = test_z( y          )
}

// 0 -> [76543210] -> C  (mem)               nv*bdizc
//                                           0.....mm
oper_LSR                    :: #force_inline proc (using c: ^CPU_65C816) {
    t.val     = read_m( ab, a.size )
    f.C       = test_0( t          )
    t.val   >>= 1
    t.val     = set__h( t,  false  )
    f.N       = false
    f.Z       = test_z( t          )
    _         = stor_m( ab, t      )
}


// 0 -> [76543210] -> C  (acc)               nv*bdizc
//                                           0.....mm
oper_LSR_A                  :: #force_inline proc (using c: ^CPU_65C816) {
    t.val     = read_r( a, a.size )
    f.C       = test_0( t          )
    t.val   >>= 1
    t.val     = set__h( t,  false  )
    f.N       = false
    f.Z       = test_z( t          )
    a.val     = t.val
}

// XXX: search for proper tests for that opcode
oper_MVN                    :: #force_inline proc (using c: ^CPU_65C816) { 
    if !in_mvn {                        // preparing for run
        dst       = read_m( ab, byte )
        ab.addr  += 1
        src       = read_m( ab, byte )
        dbr       = dst
    }

    ta.bank   = src                    // source
    ta.addr   = 0
    ta.bwrap  = true
    ta.index  = read_r( x, x.size )

    ab.bank   = dst                    // destination
    ab.addr   = 0
    ab.bwrap  = true
    ab.index  = read_r( y, y.size)

    tb.val    = read_m( ta, byte )
    _         = stor_m( ab, tb   )

    x.val     = addu_r( x, 1     )     // incrementing X/Y
    y.val     = addu_r( y, 1     )

    data0     = read_r( a, word  )     // decrementing A
    data0    -= 1

    if a.size == byte {
        a.b    = data0 & 0xFF00
        a.val  = data0 & 0x00FF
    } else {
        a.b    = data0 & 0xFF00
        a.val  = data0
    }

    in_mvn     = false if data0 == 0xFFFF else true
}

oper_MVP                    :: #force_inline proc (using c: ^CPU_65C816) { 
    if !in_mvp {                        // preparing for run
        dst       = read_m( ab, byte )
        ab.addr  += 1
        src       = read_m( ab, byte )
        dbr       = dst
    }

    ta.bank   = src                    // source
    ta.addr   = 0
    ta.bwrap  = true
    ta.index  = read_r( x, x.size )

    ab.bank   = dst                    // destination
    ab.addr   = 0
    ab.bwrap  = true
    ab.index  = read_r( y, y.size)

    tb.val    = read_m( ta, byte )
    _         = stor_m( ab, tb   )

    x.val     = subu_r( x, 1     )     // incrementing X/Y
    y.val     = subu_r( y, 1     )

    data0     = read_r( a, word  )     // decrementing A
    data0    -= 1

    if a.size == byte {
        a.b    = data0 & 0xFF00
        a.val  = data0 & 0x00FF
    } else {
        a.b    = data0 & 0xFF00
        a.val  = data0
    }

    in_mvp    = false if data0 == 0xFFFF else true
}

oper_NOP                    :: #force_inline proc (using c: ^CPU_65C816) {
}

oper_ORA                    :: #force_inline proc (using c: ^CPU_65C816) {
    t.val     = read_m( ab, a.size )
    a.val    |= t.val
    f.N       = test_n( a     )
    f.Z       = test_z( a     )
}

oper_PEA                    :: #force_inline proc (using c: ^CPU_65C816) { 
    sp.size   = word
    tw.val    = read_m( ab, tw.size )
    _         = push_r( sp, tw      )
    sp.addr   = subu_r( sp, tw.size )
    pc.addr  += 1                        // Immediate mode sets pc of 1 byte
    if f.E {
        sp.size = f.E
        sp.addr = (sp.addr & 0x00FF) | 0x0100
    }
}

oper_PEI                        :: #force_inline proc (using c: ^CPU_65C816) {
    sp.size   = word
    tw.val    = read_m( ab, tw.size )
    _         = push_r( sp, tw      )
    sp.addr   = subu_r( sp, tw.size )
    if f.E {
        sp.size = f.E
        sp.addr = (sp.addr & 0x00FF) | 0x0100
    }
}

oper_PER                    :: #force_inline proc (using c: ^CPU_65C816) { 
    sp.size   = word
    tw.val    = ab.addr               // calculated relative address
    _         = push_r( sp, tw      )
    sp.addr   = subu_r( sp, tw.size )
    if f.E {
        sp.size = f.E
        sp.addr = (sp.addr & 0x00FF) | 0x0100
    }
}

oper_PHA                    :: #force_inline proc (using c: ^CPU_65C816) { 
    _         = push_r( sp, a      )
    sp.addr   = subu_r( sp, a.size )
}

// XXX - convert DBR to register
oper_PHB                    :: #force_inline proc (using c: ^CPU_65C816) { 
    tb.val    = dbr
    _         = push_r( sp, tb      )
    sp.addr   = subu_r( sp, tb.size )
}

oper_PHD                    :: #force_inline proc (using c: ^CPU_65C816) {
    tw.val    = d
    sp.size   = word                    // "new" instruction, no stack wrap
    _         = push_r( sp, tw      )
    sp.addr   = subu_r( sp, tw.size )
    if f.E {
        sp.size = f.E
        sp.addr = (sp.addr & 0x00FF) | 0x0100
    }
}

oper_PHK                    :: #force_inline proc (using c: ^CPU_65C816) { 
    tb.val    = pc.bank
    _         = push_r( sp, tb      )
    sp.addr   = subu_r( sp, tb.size )
}

oper_PHP                    :: #force_inline proc (using c: ^CPU_65C816) { 
    tb.val    = 0
    tb.val   |= 0x80 if f.N        else 0
    tb.val   |= 0x40 if f.V        else 0
    tb.val   |= 0x20 if f.M || f.E else 0   // always 1 in E mode
    tb.val   |= 0x10 if f.X        else 0
    tb.val   |= 0x08 if f.D        else 0
    tb.val   |= 0x04 if f.I        else 0
    tb.val   |= 0x02 if f.Z        else 0
    tb.val   |= 0x01 if f.C        else 0
    _         = push_r( sp, tb      )
    sp.addr   = subu_r( sp, tb.size )
}

oper_PHX                    :: #force_inline proc (using c: ^CPU_65C816) { 
    _         = push_r( sp, x      )
    sp.addr   = subu_r( sp, x.size )
}

oper_PHY                    :: #force_inline proc (using c: ^CPU_65C816) { 
    _         = push_r( sp, y      )
    sp.addr   = subu_r( sp, y.size )
}

oper_PLA                    :: #force_inline proc (using c: ^CPU_65C816) { 
    a.val     = pull_v( sp, a.size )
    sp.addr   = addu_r( sp, a.size )
    f.N       = test_n( a          )
    f.Z       = test_z( a          )
}

oper_PLB                    :: #force_inline proc (using c: ^CPU_65C816) { 
    sp.size   = word
    dbr       = pull_v(  sp, byte  )
    sp.addr   = addu_r(  sp, byte  )
    f.N       = test_n( dbr, byte  )
    f.Z       = test_z( dbr, byte  )
    if f.E {
        sp.size = f.E
        sp.addr = (sp.addr & 0x00FF) | 0x0100
    }
}

oper_PLD                    :: #force_inline proc (using c: ^CPU_65C816) { 
    sp.size   = word
    d         = pull_v(  sp, word  )
    sp.addr   = addu_r(  sp, word  )
    f.N       = test_n(   d, word  )
    f.Z       = test_z(   d, word  )
    if f.E {
        sp.size = f.E
        sp.addr = (sp.addr & 0x00FF) | 0x0100
    }
}

oper_PLP                    :: #force_inline proc (using c: ^CPU_65C816) {
    t.val     = pull_v(  sp, byte  )
    sp.addr   = addu_r(  sp, byte  )
    f.N       = t.val & 0x80 == 0x80
    f.V       = t.val & 0x40 == 0x40
    f.M       = true if f.E else t.val & 0x20 == 0x20   // in fact: in E unused
    f.X       = true if f.E else t.val & 0x10 == 0x10   // in fact: in E flag B cannot be set via PLP
    f.D       = t.val & 0x08 == 0x08
    f.I       = t.val & 0x04 == 0x04
    f.Z       = t.val & 0x02 == 0x02
    f.C       = t.val & 0x01 == 0x01

    // internal part
    if ! f.E {
        if f.M == word && a.size == byte {
            a.val     = a.val & 0x00FF
            a.val    |= a.b
        }
        a.size    = f.M
        t.size    = f.M
        x.size    = f.X
        y.size    = f.X

        if f.X == byte {
            x.val = x.val & 0x00FF
            y.val = y.val & 0x00FF
        }
    }
}

oper_PLX                    :: #force_inline proc (using c: ^CPU_65C816) { 
    x.val     = pull_v( sp, x.size )
    sp.addr   = addu_r( sp, x.size )
    f.N       = test_n( x          )
    f.Z       = test_z( x          )
}

oper_PLY                    :: #force_inline proc (using c: ^CPU_65C816) {
    y.val     = pull_v( sp, y.size )
    sp.addr   = addu_r( sp, y.size )
    f.N       = test_n( y          )
    f.Z       = test_z( y          )
}

oper_REP                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.val     = read_m( ab, byte   )
    f.N       = false if t.val & 0x80 == 0x80 else f.N
    f.V       = false if t.val & 0x40 == 0x40 else f.V
    if !f.E {
        f.M       = false if t.val & 0x20 == 0x20 else f.M
        f.X       = false if t.val & 0x10 == 0x10 else f.X
    } else {
        f.M       = true
        f.X       = true
    }
    f.D       = false if t.val & 0x08 == 0x08 else f.D
    f.I       = false if t.val & 0x04 == 0x04 else f.I
    f.Z       = false if t.val & 0x02 == 0x02 else f.Z
    f.C       = false if t.val & 0x01 == 0x01 else f.C

    // internal part
    a.size    = f.M
    t.size    = f.M
    x.size    = f.X
    y.size    = f.X
    if f.X == byte {
        x.val = x.val & 0x00FF
        y.val = y.val & 0x00FF
    }
}

// C <- [76543210] <- C
oper_ROL                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.val     = read_m( ab, t.size )
    f.T       = test_n( t          )        // temporary flag...
    t.val   <<= 1
    t.val    |= 1  if f.C    else 0 
    f.N       = test_n( t          )
    f.Z       = test_z( t          )
    f.C       = f.T                         // lowest bit to C
    _         = stor_m( ab, t      )
}

oper_ROL_A                  :: #force_inline proc (using c: ^CPU_65C816) { 
    t.val     = read_r( a, a.size )
    f.T       = test_n( t          )        // temporary flag...
    t.val   <<= 1
    t.val    |= 1  if f.C    else 0 
    f.N       = test_n( t          )
    f.Z       = test_z( t          )
    f.C       = f.T                         // lowest bit to C
    a.val     = read_r( t, a.size )         // a.val and 0x00FF in short mode
}

// C -> [76543210] -> C
oper_ROR                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.val     = read_m( ab, t.size )
    f.T       = test_0( t          )        // temporary flag...
    t.val   >>= 1
    t.val     = set__h( t,  f.C    )
    f.N       = test_n( t          )
    f.Z       = test_z( t          )
    f.C       = f.T                         // lowest bit to C
    _         = stor_m( ab, t      )
}

// C -> [76543210] -> C
oper_ROR_A                  :: #force_inline proc (using c: ^CPU_65C816) { 
    t.val     = read_r( a, a.size )
    f.T       = test_0( t          )        // temporary flag...
    t.val   >>= 1
    t.val     = set__h( t,  f.C    )
    f.N       = test_n( t          )
    f.Z       = test_z( t          )
    f.C       = f.T                         // lowest bit to C
    a.val     = read_r( t, a.size )         // a.val and 0x00FF in short mode
}

// XXX pull PLP content to subroutine?
oper_RTI                    :: #force_inline proc (using c: ^CPU_65C816) {
    oper_PLP(c)
    pc.addr   = pull_v( sp, word )
    sp.addr   = addu_r( sp, word )

    if !f.E {
        pc.bank   = pull_v( sp, byte )
        sp.addr   = addu_r( sp, byte )
    } else {
        cycles   -= 1
    }
    
}

oper_RTL                    :: #force_inline proc (using c: ^CPU_65C816) { 
    sp.size   = word
    pc.addr   = pull_v( sp, word )
    pc.addr  += 1
    sp.addr   = addu_r( sp, word )

    pc.bank   = pull_v( sp, byte )
    sp.addr   = addu_r( sp, byte )
    if f.E {
        sp.size = f.E
        sp.addr = (sp.addr & 0x00FF) | 0x0100
    }
}

oper_RTS                    :: #force_inline proc (using c: ^CPU_65C816) { 
    pc.addr   = pull_v( sp, word )
    pc.addr  += 1
    sp.addr   = addu_r( sp, word )
}

oper_SBC                    :: #force_inline proc (using c: ^CPU_65C816) { 
    if f.D == false {
        data1    := u32(read_r(a, a.size ))
        tmp      := data1
        data2    := u32(read_m( ab, a.size ))
        data1    -= data2
        data1    -= 0 if f.C else 1
        f.V       = test_v( a.size, tmp, ~data2, data1 )
        a.val     = u16(data1)
        f.C       = test_v( a.size, ~data1 )
        f.N       = test_n( a )
        f.Z       = test_z( a )
    } else {
        data0     = read_m( ab, a.size )
        data1    := u32(read_r(a, a.size ))
        data2    := u32(data0)
        carry    := u32(1) if f.C    else 0

        // http://6502.org/tutorials/decimal_mode.html#A
        //
        // 4a. AL = (A & $0F) - (B & $0F) + C-1
        // 4b. A = A - B + C-1
        // 4c. If A < 0, then A = A - $60
        // 4d. If AL < 0, then A = A - $06
        // 4e. The accumulator result is the lower 8 bits of A

        // XXX - convert it to properr nybble-like operations without unneeded and/or operations

        o       :  u32
        if f.M == byte {
            o        =  data1         -  data2         + (carry - 1)
            al1     := (data1 & 0x0F ) - (data2 & 0x0F ) + 0x1 * (carry - 1)
            if  al1 & 0xFFFF_0000 != 0 { carry = 0 } else {carry = 1}
            al2     := (data1 & 0xF0 ) - (data2 & 0xF0 ) + 0x10 * (carry - 1)
            //fmt.printf("C: %t %06x %04x %04x %06x %06x %06x ", f.C, o, data1, data2, al1, al2, 0)
            f.V      = test_v( a.size, u32(data1), u32(~data0), u32(o)    )
            oh      := o & 0xFF00
            o       -= 0x0060 if al2 & 0xFFFF_FF00 != 0  else 0
            o       &= 0x00FF
            o       |= oh
            oh       = o & 0xFFF0
            o       -= 0x0006 if al1 & 0xFFFF_FFF0 != 0  else 0
            o       &= 0x000F
            o       |= oh
            f.C      = o & 0xFFFF_FF00 == 0
            //fmt.printf("final o: %06x\n", o)
        } else {
            o        =  data1          -  data2          + 0x1 * (carry - 1)
            al1     := (data1 & 0x0F ) - (data2 & 0x0F ) + 0x1 * (carry - 1)
            if  al1 & 0xFFFF_0000 != 0 { carry = 0 } else {carry = 1}
            al2     := (data1 & 0xF0 ) - (data2 & 0xF0 ) + 0x10 * (carry - 1)
            if  al2 & 0xFFFF_0000 != 0 { carry = 0 } else { carry = 1 }
            al3     := (data1 & 0xF00) - (data2 & 0xF00) + 0x100 * (carry - 1)
            //fmt.printf("C: %t %06x %04x %04x %06x %06x %06x ", f.C, o, data1, data2, al1, al2, al3)
            f.C      = o & 0xFFFF_0000 == 0
            f.V      = test_v( a.size, u32(data1), u32(~data0), u32(o)    )
            o       -= 0x6000 if o   & 0xFFFF_0000 != 0  else 0
            oh      := o & 0xF000

            o       -= 0x0600 if al3 & 0xFFFF_F000 != 0  else 0
            o       &= 0x0FFF
            o       |= oh
            oh       = o & 0xFF00
            o       -= 0x0060 if al2 & 0xFFFF_FF00 != 0  else 0
            o       &= 0x00FF
            o       |= oh
            oh       = o & 0xFFF0
            o       -= 0x0006 if al1 & 0xFFFF_FFF0 != 0  else 0
            o       &= 0x000F
            o       |= oh
            //fmt.printf("final o: %06x\n", o)
        }
        
        a.val     = u16(o)
        f.N       = test_n( a )
        f.Z       = test_z( a )
    }
}

oper_SEC                    :: #force_inline proc (using c: ^CPU_65C816) { 
    f.C       = true
}

oper_SED                    :: #force_inline proc (using c: ^CPU_65C816) { 
    f.D       = true
}

oper_SEI                    :: #force_inline proc (using c: ^CPU_65C816) {
    f.I       = true
}

oper_SEP                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.val     = read_m( ab, byte   )
    f.N       = true if t.val & 0x80 == 0x80 else f.N
    f.V       = true if t.val & 0x40 == 0x40 else f.V
    f.M       = true if t.val & 0x20 == 0x20 else f.M
    f.X       = true if t.val & 0x10 == 0x10 else f.X
    f.D       = true if t.val & 0x08 == 0x08 else f.D
    f.I       = true if t.val & 0x04 == 0x04 else f.I
    f.Z       = true if t.val & 0x02 == 0x02 else f.Z
    f.C       = true if t.val & 0x01 == 0x01 else f.C

    // internal part
    a.size    = f.M
    t.size    = f.M
    x.size    = f.X
    y.size    = f.X
    if f.X == byte {
        x.val = x.val & 0x00FF
        y.val = y.val & 0x00FF
    }
}

oper_STA                    :: #force_inline proc (using c: ^CPU_65C816) { 
    _         = stor_m( ab, a    )
}

// XXX: implement something
oper_STP                    :: #force_inline proc (using c: ^CPU_65C816) { 
}

oper_STX                    :: #force_inline proc (using c: ^CPU_65C816) { 
    _         = stor_m( ab, x    )
}
oper_STY                    :: #force_inline proc (using c: ^CPU_65C816) {
    _         = stor_m( ab, y    )
}
oper_STZ                    :: #force_inline proc (using c: ^CPU_65C816) {
    t.val     = 0
    _         = stor_m( ab, t    )
}

oper_TAX                    :: #force_inline proc (using c: ^CPU_65C816) { 
    x.val     = read_r( a, x.size )
    f.N       = test_n( x         )
    f.Z       = test_z( x         )
}

oper_TAY                    :: #force_inline proc (using c: ^CPU_65C816) {
    y.val     = read_r( a, y.size )
    f.N       = test_n( y         )
    f.Z       = test_z( y         )
}

oper_TCD                    :: #force_inline proc (using c: ^CPU_65C816) { 
    d         = read_r( a, word )
    f.N       = test_n( d, word )
    f.Z       = test_z( d, word )
}

oper_TCS                        :: #force_inline proc (using c: ^CPU_65C816) { 
    if f.E {
        sp.addr   = a.val  & 0x00FF
        sp.addr  |= 0x0100
    } else {
        sp.addr   = read_r( a, word )
    }
}

// TDC is always 16-bit
oper_TDC                    :: #force_inline proc (using c: ^CPU_65C816) { 
    a.val     = d
    a.b       = d  & 0xFF00
    f.N       = test_n( a.val, word )
    f.Z       = test_z( a.val, word )

}

oper_TRB                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.val     = read_m( ab, t.size    )
    data0     = t.val & a.val
    f.Z       = test_z( data0, a.size )
    t.val   &~= a.val
    _         = stor_m( ab, t         )
}

oper_TSB                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.val     = read_m( ab, t.size    )
    data0     = t.val & a.val
    f.Z       = test_z( data0, a.size )
    t.val    |= a.val
    _         = stor_m( ab, t         )
}

// TSC is always 16-bit
oper_TSC                    :: #force_inline proc (using c: ^CPU_65C816) { 
    a.val     = sp.addr
    a.b       = sp.addr & 0xFF00
    f.N       = test_n( a.val, word )
    f.Z       = test_z( a.val, word )
}

oper_TSX                    :: #force_inline proc (using c: ^CPU_65C816) { 
    x.val     = read_a( sp, x.size  )
    f.N       = test_n( x           )
    f.Z       = test_z( x           )
}

oper_TXA                    :: #force_inline proc (using c: ^CPU_65C816) { 
    a.val     = read_r( x, a.size )
    f.N       = test_n( a         )
    f.Z       = test_z( a         )
}

// "When the e flag is 1, SH is forced to $01, so in effect, TXS is an 8-bit
// transfer in this case since XL is transferred to SL and SH remains $01."
oper_TXS                    :: #force_inline proc (using c: ^CPU_65C816) { 
    if f.E {
        sp.addr   = read_r( x, byte   )
        sp.addr  |= 0x0100
    } else {
        sp.addr   = read_r( x, word   )
    }
}

oper_TXY                    :: #force_inline proc (using c: ^CPU_65C816) {
    y.val     = x.val
    f.N       = test_n( y    )
    f.Z       = test_z( y    )
}

oper_TYA                    :: #force_inline proc (using c: ^CPU_65C816) {
    a.val     = read_r( y, a.size )
    f.N       = test_n( a         )
    f.Z       = test_z( a         )
}

oper_TYX                    :: #force_inline proc (using c: ^CPU_65C816) {
    x.val     = y.val
    f.N       = test_n( x    )
    f.Z       = test_z( x    )
}

// XXX: implement something
oper_WAI                    :: #force_inline proc (using c: ^CPU_65C816) {
}

// XXX: implement debug interface
oper_WDM                    :: #force_inline proc (using c: ^CPU_65C816) { 
}

// The n and z flags are always based on an 8-bit result, no matter what the
// value of the m flag is. 
oper_XBA                    :: #force_inline proc (using c: ^CPU_65C816) {
    data0     = read_r( a, word   )
    a.val     = data0 << 8
    a.b       = data0 << 8                  // preserve high byte
    a.val    |= data0 >> 8
    f.N       = test_n( a.val, byte )
    f.Z       = test_z( a.val, byte )
}
 
// XXX: I'm not sure about behaviour when "nothing changed"
//      check it on real hardware...
oper_XCE                    :: #force_inline proc (using c: ^CPU_65C816) {

    if f.C == f.E {
        return
    }

    // transition E from 0 to 1
    if f.C == true {
        f.E     = true
        f.C     = false

        f.X     = byte
        f.M     = byte
        a.b     = a.val & 0xFF00  // preserve B accumulator, [page 423]
        a.size  = byte
        t.size  = byte
        x.size  = byte
        y.size  = byte
        x.val   = x.val & 0x00FF    
        y.val   = y.val & 0x00FF    
        
        sp.size  = byte
        sp.addr &= 0x00FF
        sp.addr |= 0x0100
    } else {
        f.E      = false
        f.C      = true

        sp.size  = word             // e 1 -> 0 does not change M,X
    }
}












