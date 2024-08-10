
// general ideas for future:
// 1. use 32bit-wide register everywhere to avoid casts
// 2. use bit_fields to avoid bitshifts for banks, 
//    ie. no  ea = u32(bank) << 16 | u32(addr) + 1
//    but     ea = bank | addr + 1
// 3. check appropriateness of bit_fields for registers 
// 4. consider shifting constructs like ( Reg ) to { Reg.val, size }
//    to achieve more uniformity across routines


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

// there are two options
// a) two different register types and procedure overloadin (add/load)
// b) explicite different procedures for operations

DataRegister_65C816 :: struct {
     val:    u16,    // register value
       b:    u16,    // high byte of register (Accumulator only)
    size:    bool,   // 0 == 16 bit, 1 == 8 bit
}

AddressRegister_65C816 :: struct {
    bank:      u16,                  // data bank (u8)
    addr:      u16,                  // address within bank
   index:      u16,                  // for indexed operations
    wrap:      bool,                 // does read wrap on bank boundary?
    size:      bool,                 // 0 == 16 bit, 1 == 8 bit
}

CPU_65C816_type :: enum {
    W65C816S,
}

CPU_65C816 :: struct {
    using cpu: ^CPU,

    type: 	CPU_65C816_type,

    pc:     AddressRegister_65C816,      // pc.bank act as K register
    sp:     AddressRegister_65C816,      // XXX: check it should be Data or Addresss?
    ab:     AddressRegister_65C816,
    ta:     AddressRegister_65C816,      // temporary, internal register

    a:      DataRegister_65C816,
    t:      DataRegister_65C816,        // temporary, internal register, size same as a(!)
    x:      DataRegister_65C816,
    y:      DataRegister_65C816,

    dbr:    u16,      // Data    Bank Register  (u8)
    d:      u16,      // Direct register       (u16)
    //k:      u16,      // Program Bank Register  (u8)   - inside pc.bank

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

        T:    bool,   // Temporary flag, for value holding
    },

                       // misc variables
    ir:     u8,        // instruction register
    px:     bool,      // page was crossed?

    wdm:    bool,      // support for non-standard WDM (0x42) command
    abort:  bool,      // emulator should abort?
    ppc:    u16,       // previous PC - for debug purposes
    cycle:  u32,       // number of cycless for this command

    data0:  u16,       // temporary register
    data1:  u32,       // temporary register (2)
}

// XXX - parametrize CPU type!
w65c816_make :: proc (name: string, bus: ^bus.Bus) -> ^CPU {

    cpu           := new(CPU)
    cpu.name       = name
    cpu.setpc      = w65c816_setpc
    cpu.reset      = w65c816_reset
    cpu.exec       = w65c816_exec
    cpu.clear_irq  = w65c816_clear_irq
    cpu.delete     = w65c816_delete
    cpu.bus        = bus
    cpu.cycles     = 0
    c             := CPU_65C816{cpu = cpu, type = CPU_65C816_type.W65C816S}
    c.a            = DataRegister_65C816{}
    c.x            = DataRegister_65C816{}
    c.y            = DataRegister_65C816{}
    c.pc           = AddressRegister_65C816{wrap = true}
    c.sp           = AddressRegister_65C816{wrap = true}
    c.ab           = AddressRegister_65C816{wrap = true}
    c.ta           = AddressRegister_65C816{wrap = true}
    cpu.model      = c


    // we need global because of external musashi (XXX - maybe whole CPU?)
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

w65c816_reset :: proc(cpu: ^CPU) {
    return
}

w65c816_delete :: proc(cpu: ^CPU) {
    free(cpu)
    return
}

w65c816_clear_irq :: proc(cpu: ^CPU) {
    //if localbus.pic.irq_clear {
    //    log.debugf("%s IRQ clear", cpu.name)
    //    localbus.pic.irq_clear  = false
    //    localbus.pic.irq_active = false
    //    localbus.pic.current    = pic.IRQ.NONE
    //    m68k_set_irq(uint(pic.IRQ.NONE))
    //}
}

w65c816_exec :: proc(cpu: ^CPU, ticks: u32 = 1000) {
    c := &cpu.model.(CPU_65C816)
    current_ticks : u32 = 0

    if ticks == 0 {
        c.cycle        = w65c816_execute(c)
        return
    }

    return
}

w65c816_execute :: proc(cpu: ^CPU_65C816) -> (cycles: u32) {
    cpu.px    = false
    cpu.ir    = u8(read_m(cpu.pc, byte)) // XXX: u16?
    tmp      := read_m(cpu.pc, byte)
    cpu.cycle = 0
    cpu.ab.index = 0    // XXX: move to addressing modes?

    //log.infof("execute, PC %04x opcode %02x (%04x)", cpu.pc.addr, cpu.ir, tmp)
    w65c816_run_opcode(cpu)

    // XXX: create OP table!
    //cycles    = op_table[cpu.ir].cycles
    //cycles   += op_table[cpu.ir].p         if px else 0
    return cycles
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
    a : u16
    if size == byte {
        a = u16(1)
    } else {
        a = u16(2)
    }

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
    a : u16
    if size == byte {
        a = u16(1)
    } else {
        a = u16(2)
    }

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

subu_r :: proc { subu_r_reg, subu_r_addr }
addu_r :: proc { addu_r_reg, addu_r_addr }

read_m :: #force_inline proc (ar: AddressRegister_65C816, size: bool) -> (result: u16) {
    ea     := u32(ar.addr) + u32(ar.index)
    ea     &= 0x0000_ffff if ar.wrap else 0xffff_ffff
    ea     += u32(ar.bank) << 16
    ea     &= 0x00ff_ffff
    result  = u16(localbus->read(.bits_8, ea))

    if size == word {
        ea      = u32(ar.addr) + u32(ar.index) + 1
        ea     &= 0x0000_ffff if ar.wrap else 0xffff_ffff
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

push_r :: #force_inline proc (ar: AddressRegister_65C816, dr: DataRegister_65C816) -> bool {
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

pull_v :: #force_inline proc (ar: AddressRegister_65C816, size: bool) -> (result: u16) {
    ar      := ar

    ar.addr = addu_r(ar, byte)
    result = u16(localbus->read(.bits_8, u32(ar.addr)))

    if ar.size == word {
        ar.addr  = addu_r(ar, byte)
        result  |= u16(localbus->read(.bits_8, u32(ar.addr))) << 8
    }
    return 
}


stor_m :: #force_inline proc (ar: AddressRegister_65C816, dr: DataRegister_65C816) -> bool {
    value  := u32( read_r( dr, dr.size ) )

    ea     := u32(ar.addr) + u32(ar.index)
    ea     &= 0x0000_FFFF if ar.wrap else 0xFFFF_FFFF
    ea     += u32(ar.bank) << 16
    ea     &= 0x00ff_ffff
    localbus->write(.bits_8, ea, value & 0xFF)

    if dr.size == word {
        ea      = u32(ar.addr) + u32(ar.index) + 1
        ea     &= 0x0000_FFFF if ar.wrap else 0xFFFF_FFFF
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
test_p :: #force_inline proc (ar: AddressRegister_65C816) ->  bool {
    return ((ar.addr & 0xFF00) != ((ar.addr+ar.index) & 0xFF00))
}

// negative flag test
// XXX
// there is a possibility to make single routine test_n(val, size)
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

test_z_val :: #force_inline proc (val: u16, size: bool)    -> (result: bool) {
    switch size {
    case byte: result = val & 0xFF == 0x00
    case word: result = val        == 0x00
    }
    return result
}

test_z :: proc { test_z_reg, test_z_val }

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
set__h :: #force_inline proc (dr: DataRegister_65C816, a: bool)    -> (result: u16) {
    if a {
        result = dr.val | (0x80 if dr.size else 0x8000)
    } else {
        result = dr.val & (0x7F if dr.size else 0x7FFF)
    }
    return result
}

// helper for adc with D-flag
parsed :: proc(sum: u32, size: bool) -> (result: u32) {
    sum := sum
	if (sum & 0x0F) > 0x09 {
		sum = sum + 0x06
	}
	if (sum & 0xF0) > 0x90 {
		sum = sum + 0x60
	}

	if size == word {
		if (sum & 0x0F00) > 0x0900 {
				sum = sum + 0x0600
		}
		if (sum & 0xF000) > 0x9000 {
				sum = sum + 0x6000
		}
	}
	result = sum
	return
}

// addressing modes
// references:
// man65816: "Programming the 65816" / WDC 2007
// 2 - http://6502.org/tutorials/65C816opcodes.html
// 3 - http://datasheets.chipdb.org/Western%20Design/w65c816s.pdf


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
    ab.wrap   = false
    pc.addr  += 2
}

mode_Absolute_PBR           :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, word )
    ab.bank   = pc.bank
    ab.wrap   = false
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
    ab.wrap   = false
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
    ab.wrap   = false
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
    ab.index    = x.val
    ab.wrap   = true

    ab.addr   = read_m( ab, word )  // dbr hh ll
    ab.bank   = dbr
    ab.index  = 0
    ab.wrap   = false
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
    ab.wrap   = true

    ab.addr   = read_m( ab, word )  // dbr hh ll
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
    ab.addr   = read_m( pc, byte )  // 0 | D + LL
    pc.addr  += 1
    ab.addr  += d
    ab.bank   = 0
    ab.wrap   = true

    ab.addr   = read_m( ab, word )  // dbr hh ll + Y
    ab.bank   = dbr
    ab.index  = read_r( y, y.size)
    ab.wrap   = false
    px        = test_p( ab )
}

mode_S_Relative_Indirect_Y  :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, byte )  // 0 | S + LL
    pc.addr  += 1
    ab.addr  += sp.addr
    ab.bank   = 0
    ab.wrap   = true

    ab.addr   = read_m( ab, word )  // dbr hh ll + Y
    ab.bank   = dbr
    ab.index  = y.val
    ab.wrap   = false
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
    ta.wrap   = true

    ab.addr   = read_m( ta, word )  // hh ll
    ta.addr  += 2
    ab.bank   = read_m( ta, byte )  // top
    ab.wrap   = false
}

mode_DP_Indirect_Long_Y    :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1 
    ta.addr   = read_m( pc, byte )  // 0 | D + LL
    pc.addr  += 1
    ta.addr  += d
    ta.bank   = 0
    ta.wrap   = true

    ab.addr   = read_m( ta, word )  // hh ll
    ta.addr  += 2
    ab.bank   = read_m( ta, byte )  // top
    ab.index  = y.val
    ab.wrap   = false
    // XXX - check px!
}

// OPC $BBHHLL
mode_Absolute_Long          :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1 
    ab.addr   = read_m( pc, word )  // HH LL
    pc.addr  += 2
    ab.bank   = read_m( pc, byte )  // BB
    pc.addr  += 1 
    ab.wrap   = true
}

// OPC $BBHHLL, X
mode_Absolute_Long_X        :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1 
    ab.addr   = read_m( pc, word )  // HH LL
    pc.addr  += 2
    ab.bank   = read_m( pc, byte )  // BB
    pc.addr  += 1 
    ab.wrap   = false
    ab.index  = x.val
}

// PC relative mode: value is added to PC that already points at NEXT OP
// OPC $LL
mode_PC_Relative            :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, byte )              // relative calculated form pc of next cmd
    pc.addr  += 1
    ab.addr   = adds_b( pc.addr, ab.addr)
    ab.bank   = pc.bank
}

mode_PC_Relative_Long       :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, word )
    pc.addr  += 2 
    ab.addr   = adds_w( pc.addr, ab.addr)
    ab.bank   = pc.bank
}

//
// CPU: all
// OPC $LL        operand is zeropage address, hi-byte is zero address
//                $00LL      data
mode_DP                     :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr   += 1
    ab.addr    = read_m( pc, byte )
    pc.addr   += 1
    ab.addr   += d
    ab.bank    = 0
    ab.index   = 0
    ab.wrap    = true
}
//
// CPU: all
// OPC $LL,X     operand is zeropage address;
//               effective address is address incremented by X without carry [2]
mode_DP_X                   :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr   += 1
    ab.addr    = read_m( pc, byte )
    pc.addr   += 1
    ab.addr   += d
    ab.bank    = 0
    ab.index   = x.val
    ab.wrap    = true
}

//
// CPU: all
// OPC $LL,Y      operand is zeropage address;
//                effective address is address incremented by Y without carry [2]
mode_DP_Y                   :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr   += 1
    ab.addr    = read_m( pc, byte )
    pc.addr   += 1
    ab.addr   += d
    ab.bank    = 0
    ab.index   = y.val
    ab.wrap    = true
}

mode_S_Relative             :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr   += 1
    ab.addr    = read_m( pc, byte )
    pc.addr   += 1
    ab.bank    = 0
    ab.index   = sp.addr         // XXX after change to DataRegister move to .val
    ab.wrap    = true
}


//
// CPU: all, except MOS 6502
// OPC ($LLHH,X)  operand is address;
//                effective address is word in (HHLL+X), inc. with carry: C.w($HHLL+X)
mode_Absolute_X_Indirect       :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, word )  // K | D + HH + LL + X
    ab.bank   = pc.bank
    ab.index    = x.val
    ab.wrap   = true

    ab.addr   = read_m( ab, word )  // k hh ll
    ab.index  = 0
    pc.addr  += 2
}

mode_Absolute_Indirect         :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr  += 1
    ab.addr   = read_m( pc, word )  // 0 | D + HH + LL 
    ab.bank   = 0
    ab.wrap   = true

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
    ta.wrap   = true

    ab.addr   = read_m( ta, word )  // hh ll
    ta.addr  += 2
    ab.bank   = read_m( ta, byte )  // top
    ab.wrap   = false
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
    pc.addr  += 1
    ab        = pc
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
        data1    = u32(read_r(a, a.size ))
        tmp     := data1
        data2   := u32(read_m( ab, a.size ))
        data1   += data2
        data1   += 1 if f.C else 0
        f.V      = test_v( a.size, tmp, data2, data1 )
        a.val    = u16(data1)
        f.C      = test_v( a.size, data1 )
        f.N      = test_n( a )
        f.Z      = test_z( a )
    } else {
        data1    = u32(read_r(a, a.size ))
        data0    = read_m( ab, a.size )
        data2   := u32(data0)

        //fmt.printf(" D %06x M %t C %t\n", data2, f.M, f.C)
        // lowest nybble
        carry   := u32(1) if f.C else 0
        o       := (data1 & 0x0F) + (data2 & 0x0F) + carry

        // decimal correct
        if o > 0x09 do o += 0x06
        //fmt.printf(" D o after first decimal %02x\n", o)
        carry    = 0x10 if o > 0x0f else 0
		o        = (o & 0x0f) + (data1 & 0xF0) + (data2 & 0xF0) + carry
        f.V      = test_v( a.size, u32(data1), u32(data0), u32(o)    )
        if o > 0x9F do o += 0x60

        if f.M == word {
        carry    = 0x0100 if o > 0xFF else 0
		o        = (o & 0xff) + (data1 & 0x0F00) + (data2 & 0x0F00) + carry
        if o > 0x9FF do o += 0x600
        carry    = 0x1000 if o > 0xFFF else 0
		o        = (o & 0xfff) + (data1 & 0xF000) + (data2 & 0xF000) + carry
        f.V      = test_v( a.size, u32(data1), u32(data0), u32(o)    )
        if o > 0x9FFF do o += 0x6000
        }
        
		

        //fmt.printf("%06x M %t C %t\n", o, f.M, f.C)
        //fmt.printf("%04x M %t C %t\n", data1, f.M, f.C)

        a.val    = u16(o)
        f.C      = o > 0xFF if f.M else o > 0xFFFF
        f.N      = test_n( a )
        f.Z      = test_z( a )
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
        cycle    += 2       if f.E && px else 1
    }
}

oper_BCS                    :: #force_inline proc (using c: ^CPU_65C816) {
    if   f.C {
        pc.addr   = ab.addr
        cycle    += 2       if f.E && px else 1
    }
}

oper_BEQ                    :: #force_inline proc (using c: ^CPU_65C816) {
    if   f.Z {
        pc.addr   = ab.addr
        cycle    += 2       if f.E && px else 1
    }
}

oper_BIT                     :: #force_inline proc (using c: ^CPU_65C816) {
    t.val      = read_m( ab, a.size )
    f.N        = test_n( t )
    f.V        = test_s( t )            // second highest bit
    t.val     &= a.val
    f.Z        = test_z( t )
}

// Immediate does not set N nor V
oper_BIT_IMM                  :: #force_inline proc (using c: ^CPU_65C816) {
    t.val      = read_m( ab, a.size )
    t.val     &= a.val
    f.Z        = test_z( t )
}

oper_BMI                    :: #force_inline proc (using c: ^CPU_65C816) {
    if   f.N {
        pc.addr   = ab.addr
        cycle    += 2       if f.E && px else 1
    }
}

oper_BNE                    :: #force_inline proc (using c: ^CPU_65C816) {
    if ! f.Z {
        pc.addr   = ab.addr
        cycle    += 2       if f.E && px else 1
    }
}

oper_BPL                    :: #force_inline proc (using c: ^CPU_65C816) {
    if ! f.N {
        pc.addr   = ab.addr
        cycle    += 2       if f.E && px else 1
    }
}

oper_BRA                    :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr   = ab.addr
    cycle    += 2          if f.E && px else 1
}

oper_BRK                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.size    = byte
    t.val     = pc.bank
    _         = push_r( sp, t      )
    sp.addr   = subu_r( sp, t.size )

    t.size    = word
    t.val     = pc.addr
    t.val    += 1                      // specification say "+2" but mode_ sets +1
    _         = push_r( sp, t      )
    sp.addr   = subu_r( sp, t.size )

    oper_PHP(c)

    f.I       = true
    f.D       = false
    ab.bank   = 0
    ab.addr   = 0xFFE6
    pc.bank   = 0
    pc.addr   = read_m( ab, word )
    t.size    = a.size
}

oper_BRK_E                  :: #force_inline proc (using c: ^CPU_65C816) { }

oper_BRL                    :: #force_inline proc (using c: ^CPU_65C816) {
    pc.addr   = ab.addr
}

oper_BVC                    :: #force_inline proc (using c: ^CPU_65C816) {
    if ! f.V {
        pc.addr   = ab.addr
        cycle    += 2       if f.E && px else 1
    }
}

oper_BVS                    :: #force_inline proc (using c: ^CPU_65C816) {
    if   f.V {
        pc.addr   = ab.addr
        cycle    += 2       if f.E && px else 1
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
    t.val      = read_m( ab, t.size )
    t.val      = subu_r(  a, t.val  )
    f.N        = test_n(  t         )
    f.Z        = test_z(  t         )
    f.C        = read_r(  a, a.size )  >= t.val    // I wish I had a getter
}

oper_COP                    :: #force_inline proc (using c: ^CPU_65C816) {
    t.size    = byte
    t.val     = pc.bank
    _         = push_r( sp, t      )
    sp.addr   = subu_r( sp, t.size )

    t.size    = word
    t.val     = pc.addr
    _         = push_r( sp, t      )
    sp.addr   = subu_r( sp, t.size )

    oper_PHP(c)

    f.I       = true
    f.D       = false
    ab.bank   = 0
    ab.addr   = 0xFFE4
    pc.bank   = 0
    pc.addr   = read_m( ab, word )
    t.size    = a.size
}

oper_COP_E                  :: #force_inline proc (using c: ^CPU_65C816) { }

oper_CPX                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.size     = x.size
    t.val      = read_m( ab, t.size )
    t.val      = subu_r(  x, t.val  )
    f.N        = test_n(  t         )
    f.Z        = test_z(  t         )
    f.C        = read_r(  x, x.size )  >= t.val    // I wish I had a getter
    t.size     = a.size                            // restore standard behaviour
}

oper_CPY                    :: #force_inline proc (using c: ^CPU_65C816) {
    t.size     = y.size
    t.val      = read_m( ab, t.size )
    t.val      = subu_r(  y, t.val  )
    f.N        = test_n(  t         )
    f.Z        = test_z(  t         )
    f.C        = read_r(  y, y.size )  >= t.val    // I wish I had a getter
    t.size     = a.size                            // restore standard behaviour
}

oper_DEC                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.val      = read_m( ab, a.size )
    t.val      = subu_r( t, 1  )
    f.N        = test_n( t     )
    f.Z        = test_z( t     )
    _          = stor_m( ab, t )
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
    t.val      = read_m( ab, a.size )
    t.val      = addu_r( t, 1  )
    f.N        = test_n( t     )
    f.Z        = test_z( t     )
    _          = stor_m( ab, t )
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
oper_JSL                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.size    = byte
    t.val     = pc.bank
    _         = push_r( sp, t      )
    sp.addr   = subu_r( sp, t.size )

    t.size    = word
    t.val     = pc.addr
    t.val    -= 1                          // mode_ sets pc to next command
    _         = push_r( sp, t      )
    sp.addr   = subu_r( sp, t.size )
    pc.bank   = ab.bank
    pc.addr   = ab.addr
    t.size    = a.size
}

oper_JSR                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.size    = word
    t.val     = pc.addr
    t.val    -= 1                          // mode_ sets pc to next command
    _         = push_r( sp, t      )
    sp.addr   = subu_r( sp, t.size )
    pc.addr   = ab.addr
    t.size    = a.size
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


oper_MVN                    :: #force_inline proc (using c: ^CPU_65C816) { }
oper_MVP                    :: #force_inline proc (using c: ^CPU_65C816) { }

oper_NOP                    :: #force_inline proc (using c: ^CPU_65C816) {
}

oper_ORA                    :: #force_inline proc (using c: ^CPU_65C816) {
    t.val     = read_m( ab, a.size )
    a.val    |= t.val
    f.N       = test_n( a     )
    f.Z       = test_z( a     )
}

oper_PEA                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.size    = word
    t.val     = read_m( ab, t.size )
    _         = push_r( sp, t      )
    sp.addr   = subu_r( sp, t.size )
    pc.addr  += 1                        // Immediate mode sets pc of 1 byte
    t.size    = a.size
}

oper_PEI                        :: #force_inline proc (using c: ^CPU_65C816) {
    t.size    = word
    t.val     = read_m( ab, t.size )
    _         = push_r( sp, t      )
    sp.addr   = subu_r( sp, t.size )
    t.size    = a.size                  // restore original
}

oper_PER                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.size    = word
    t.val     = ab.addr               // calculated relative address
    _         = push_r( sp, t      )
    sp.addr   = subu_r( sp, t.size )
    t.size    = a.size                // restore original
}

oper_PHA                    :: #force_inline proc (using c: ^CPU_65C816) { 
    _         = push_r( sp, a      )
    sp.addr   = subu_r( sp, a.size )
}

// XXX - convert DBR to register
oper_PHB                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.size    = byte
    t.val     = dbr
    _         = push_r( sp, t      )
    sp.addr   = subu_r( sp, t.size )
    t.size    = a.size
}

oper_PHD                    :: #force_inline proc (using c: ^CPU_65C816) {
    t.size    = word
    t.val     = d
    _         = push_r( sp, t      )
    sp.addr   = subu_r( sp, t.size )
    t.size    = a.size
}

oper_PHK                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.size    = byte
    t.val     = pc.bank
    _         = push_r( sp, t      )
    sp.addr   = subu_r( sp, t.size )
    t.size    = a.size
}

oper_PHP                    :: #force_inline proc (using c: ^CPU_65C816) { 
    t.size    = byte
    t.val     = 0
    t.val    |= 0x80 if f.N else 0
    t.val    |= 0x40 if f.V else 0
    t.val    |= 0x20 if f.M else 0
    t.val    |= 0x10 if f.X else 0
    t.val    |= 0x08 if f.D else 0
    t.val    |= 0x04 if f.I else 0
    t.val    |= 0x02 if f.Z else 0
    t.val    |= 0x01 if f.C else 0
    _         = push_r( sp, t      )
    sp.addr   = subu_r( sp, t.size )
    t.size    = a.size
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
    dbr       = pull_v(  sp, byte  )
    sp.addr   = addu_r(  sp, byte  )
    f.N       = test_n( dbr, byte  )
    f.Z       = test_z( dbr, byte  )
}

oper_PLD                    :: #force_inline proc (using c: ^CPU_65C816) { 
    d         = pull_v(  sp, word  )
    sp.addr   = addu_r(  sp, word  )
    f.N       = test_n(   d, word  )
    f.Z       = test_z(   d, word  )
}

oper_PLP                    :: #force_inline proc (using c: ^CPU_65C816) {
    t.val     = pull_v(  sp, byte  )
    sp.addr   = addu_r(  sp, byte  )
    f.N       = t.val & 0x80 == 0x80
    f.V       = t.val & 0x40 == 0x40
    f.M       = t.val & 0x20 == 0x20
    f.X       = t.val & 0x10 == 0x10
    f.D       = t.val & 0x08 == 0x08
    f.I       = t.val & 0x04 == 0x04
    f.Z       = t.val & 0x02 == 0x02
    f.C       = t.val & 0x01 == 0x01

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
    f.M       = false if t.val & 0x20 == 0x20 else f.M
    f.X       = false if t.val & 0x10 == 0x10 else f.X
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

    pc.bank   = pull_v( sp, byte )
    sp.addr   = addu_r( sp, byte )
}

oper_RTL                    :: #force_inline proc (using c: ^CPU_65C816) { 
    pc.addr   = pull_v( sp, word )
    pc.addr  += 1
    sp.addr   = addu_r( sp, word )

    pc.bank   = pull_v( sp, byte )
    sp.addr   = addu_r( sp, byte )
}

oper_RTS                    :: #force_inline proc (using c: ^CPU_65C816) { 
    pc.addr   = pull_v( sp, word )
    pc.addr  += 1
    sp.addr   = addu_r( sp, word )
}

oper_SBC                    :: #force_inline proc (using c: ^CPU_65C816) { }

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

// bad
oper_TCD                    :: #force_inline proc (using c: ^CPU_65C816) { 
    d         = read_r( a, word )
    f.N       = test_n( d, word )
    f.Z       = test_z( d, word )
    /*
    f.N       = d & 0x8000 == 0x8000 // test_n2?
    f.Z       = d == 0
    */
}

// "However, when the e flag is 1, SH is forced to $01"
oper_TCD_E                  :: #force_inline proc (using c: ^CPU_65C816) { 
    d         = a.val  & 0x00FF
    d        |= 0x0100
    f.N       = test_n( d, byte )
    f.Z       = test_z( d, byte )
}

oper_TCS                        :: #force_inline proc (using c: ^CPU_65C816) { 
    sp.addr   = read_r( a, word )
}

// check if Z is set from 16bit or 8bit?
oper_TCS_E                  :: #force_inline proc (using c: ^CPU_65C816) { 
    sp.addr   = a.val  & 0x00FF
    sp.addr  |= 0x0100
    f.N       = test_n( sp.addr, byte )
    f.Z       = test_z( sp.addr, byte )
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

oper_TXS                    :: #force_inline proc (using c: ^CPU_65C816) { 
    sp.addr   = read_r( x, word   )
}

// emulation mode
// "When the e flag is 1, SH is forced to $01, so in effect, TXS is an 8-bit
// transfer in this case since XL is transferred to SL and SH remains $01."
oper_TXS_E                  :: #force_inline proc (using c: ^CPU_65C816) { 
    sp.addr   = read_r( x, byte   )
    sp.addr  |= 0x0100
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

oper_WAI                    :: #force_inline proc (using c: ^CPU_65C816) {
}

oper_WDM                    :: #force_inline proc (using c: ^CPU_65C816) { 
}

// The n and z flags are always based on an 8-bit result, no matter what the
// value of the m flag is. 
oper_XBA                    :: #force_inline proc (using c: ^CPU_65C816) {
    data0     = read_r( a, word   )
    a.val     = data0 << 8
    a.b       = data0 << 8                  // preserve high byte
    a.val    |= data0 >> 8

    f.N       = a.val  & 0x80 == 0x80       // always test 8bit  XXX - maybe test_* should be parametrized?
    f.Z       = a.val  & 0xFF == 0x00       // always test 8bit
}
 
// XXX: bad
oper_XCE                    :: #force_inline proc (using c: ^CPU_65C816) {
    f.E       = f.C
}












