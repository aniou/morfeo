
// general ideas for future:
// 1. use 32bit-wide register everywhere to avoid casts
// 2. use bit_fields to avoid bitshifts for banks, 
//    ie. no  ea = u32(bank) << 16 | u32(addr) + 1
//    but     ea = bank | addr + 1
// 3. check appropriateness of bit_fields for registers 
// 4. consider shifting constructs like ( Reg ) to { Reg.val, size }
//    to achieve more uniformity across routines


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

4. BCS Technology Limited          (2014) "Investigating 65C816 Interrupts"
   http://www.6502.org/tutorials/65c816interrupts.html
*/
package cpu

import "base:runtime"
import "core:fmt"
import "core:log"
import "emulator:bus"
import "emulator:pic"
import "lib:emu"
import "core:prof/spall"

make_w65c816 :: proc (name: string, bus: ^bus.Bus) -> ^CPU {
    cpu           := new(CPU)
    cpu.name       = name
    cpu.setpc      = setpc_w65c816
    cpu.reset      = reset_w65c816
    cpu.run        = run_w65c816
    cpu.clear_irq  = clear_irq_w65c816      // XXX not finished yet
    cpu.delete     = delete_w65c816
    cpu.bus        = bus
    cpu.all_cycles = 0

    c             := CPU_65xxx{cpu = cpu, type = CPU_65xxx_type.W65C816S}
    c.real65c02    = false
    c.a            = DataRegister_65xxx{}
    c.x            = DataRegister_65xxx{}
    c.y            = DataRegister_65xxx{}
    c.t            = DataRegister_65xxx{}
    c.tb           = DataRegister_65xxx{size = byte}
    c.tw           = DataRegister_65xxx{size = word}
    c.pc           = AddressRegister_65xxx{bwrap = true}
    c.sp           = AddressRegister_65xxx{bwrap = true}
    c.ab           = AddressRegister_65xxx{bwrap = true}
    c.ta           = AddressRegister_65xxx{bwrap = true}
    c.state        = .FETCH
    cpu.model      = c

    // we need global because of external musashi
    localbus   = bus
    return cpu
}

clear_irq_w65c816 :: proc(cpu: ^CPU) {
    c            := &cpu.model.(CPU_65xxx)
    c.irq         = {}
    c.irq_pending = false
}

setpc_w65c816 :: proc(cpu: ^CPU, address: u32) {
    c         := &cpu.model.(CPU_65xxx)
    c.pc.addr  = u16( address & 0x0000_FFFF       )
    c.pc.bank  = u16((address & 0x00FF_0000) >> 16)
    c.state    = .FETCH
    c.stall    = 0
    c.cycles   = 0
    return
}

delete_w65c816 :: proc(cpu: ^CPU) {
    free(cpu)
    return
}

reset_w65c816 :: proc(cpu: ^CPU) {
    c         := &cpu.model.(CPU_65xxx)
    oper_RST(c)
}

// ----------------------------------------------------------------------------
// operand execution
//
//    This particular emulation is not cycle-exact, thus all operations
//    are made at single batch and exec() routine stalls for number of
//    cycles used for particular command.
// 
//    There are multiple ways of doing that:
// 
//    1. Very simple:
//       a) if stall > 0 { stall -= 1; return }
//       b) fetch opcode to ir and execute
//       c) calculate cycles and set stall for that value
//       d) process interrupts (because they wait for end of
//          particular commands, except ABORT)
// 
//       Thus, sequence is: exec and then wait for desired cycles.
//       That is somewhat simple but does not allow to easily simulate
//       ABORT interrupt in 65c816.
// 
//    2. Less simple, with three states:
//       a) fetch    : fetch ir and calculate cycles                 -> exec
//       b) exec     : stall, process abort,do exec                  -> post-exec or fetch
//       c) post-exec: wait for an additional cycles from page-cross
//                     or branch taken                               -> fetch
// 
//       That model provides ability to simulate ABORT interrupt with
//       cost of simple inaccuracies.
// 
//    3. Almost ideal model prefers setting 'ABORT' line for cpu and
//       execute opcode, but it needs additional code that should
//       check ABORT and prevent register and memory-write operations,
//       this is more accurate but at cost of complicating simple code.
// 
//    4. Ideal model requires step-exact code, that is possible, but
//       with different algorithm or even different language - maybe 
//       in future?

// ver.1 - less accurate, more performant, without ABORT
run_w65c816 :: proc(cpu: ^CPU, ticks: u32 = 1000) {
    c := &cpu.model.(CPU_65xxx)
    current_ticks : u32 = 0

    for current_ticks <= ticks {
        step_w65c816(c)
        current_ticks += c.cycles
    }

    return
}

// ver.2 - more accurate, less performant, ABORT capable
run_v2_w65c816 :: proc(cpu: ^CPU, ticks: u32 = 1000) {
    c := &cpu.model.(CPU_65xxx)
    current_ticks : u32 = 0

    if ticks == 0 {
        step_v2_w65c816(c)
        return
    } 

    for current_ticks < ticks {
        step_v2_w65c816(c)
        if c.state == .FETCH {
            current_ticks += c.cycles
        }
    }
    return
}

// ver.1 - less accurate, but sufficient and performant
step_w65c816 :: proc(cpu: ^CPU_65xxx) {

    switch {
    case cpu.irq_pending:
        cpu.irq_pending = false
        switch {
        case .RESB   in cpu.irq:
            cpu.irq -= {.RESB}
            oper_RST(cpu)
        case .ABORTB in cpu.irq:
            cpu.irq -= {.ABORTB}
            oper_ABT(cpu)
        case .NMIB   in cpu.irq:
            cpu.irq -= {.NMIB}
            oper_NMI(cpu)
        case .IRQB   in cpu.irq:
            cpu.irq -= {.IRQB}
            if cpu.f.I { return }       // that makes "empty" call to _execute, but code is simpler
            oper_IRQ(cpu)
        }
    case cpu.in_mvn:
        oper_MVN(cpu)
        cpu.cycles      = cycles_65c816[cpu.ir] if cpu.in_mvn else 0

    case cpu.in_mvp:
        oper_MVP(cpu)
        cpu.cycles      = cycles_65c816[cpu.ir] if cpu.in_mvn else 0

    case:
        cpu.px          = false
        cpu.ir          = u8(read_m(cpu.pc, byte)) // XXX: u16?
        cpu.ab.index    = 0                        // XXX: move to addressing modes?
        cpu.ab.pwrap    = false                    // XXX: move to addressing modes?

        cpu.cycles      = cycles_65c816[cpu.ir]
        cpu.cycles     -= decCycles_flagM[cpu.ir]         if cpu.f.M             else 0
        cpu.cycles     -= decCycles_flagX[cpu.ir]         if cpu.f.X             else 0
        cpu.cycles     += incCycles_regDL_not00[cpu.ir]   if cpu.d & 0x00FF != 0 else 0

        if cpu.debug {
            if cpu.bus.debug {
                cpu.bus.debug = false
                debug_w65c816(cpu)
                cpu.bus.debug = true
            } else {
                debug_w65c816(cpu)
            }
        }

        execute_w65c816(cpu)
        cpu.cycles     += incCycles_PageCross[cpu.ir]     if cpu.px && cpu.f.X   else 0
    }
    cpu.all_cycles += cpu.cycles

    // interrupts are triggered at end of current command with exception in ABORT
    // that is triggered early and causes command to be no-op with the same cycles
    // as original - but ABORT is not implemented propelry in that variant of exec
    if cpu.bus.pic.irq_active && !cpu.f.I {
    //    //log.debugf("cpu0: irq active")
        cpu.bus.pic.irq_active = false
        cpu.irq += {.IRQB}
    }

    if cpu.irq != nil {
        cpu.irq_pending = true
    }
    return
}

// ver.2 - more accurate, suitable for kind-of ABORT, less performant
step_v2_w65c816 :: proc(cpu: ^CPU_65xxx) {
    switch cpu.state {
    case   .FETCH:
        cpu.px       = false
        cpu.ab.index = 0
        cpu.ab.pwrap = false
        cpu.ppc      = cpu.pc

        cpu.ir          = u8(read_m(cpu.pc, byte))
        cpu.cycles      = cycles_65c816[cpu.ir]
        cpu.cycles     -= decCycles_flagM[cpu.ir]         if cpu.f.M             else 0
        cpu.cycles     -= decCycles_flagX[cpu.ir]         if cpu.f.X             else 0
        cpu.cycles     += incCycles_regDL_not00[cpu.ir]   if cpu.d & 0x00FF != 0 else 0
        cpu.stall       = cpu.cycles
        cpu.state       = .EXEC
        fallthrough

    case   .EXEC:
        cpu.stall     -= 1
        if cpu.stall > 0 {
            return
        }
        // if abort ... { cpu.pc = cpu.ppc ... } - after stall but without execution opcode

        switch {
        case cpu.in_mvn:
            oper_MVN(cpu)
        case cpu.in_mvp:
            oper_MVP(cpu)
        case:
            execute_w65c816(cpu)
            cpu.stall    = incCycles_PageCross[cpu.ir]     if cpu.px && cpu.f.X   else 0
            if cpu.stall > 0 {
                cpu.cycles  += cpu.stall
                cpu.state    = .POST_EXEC
            } else {
                cpu.state    = .FETCH
            }
        }

        // if interrupt - always after opcode, exception: ABORT

        if cpu.in_mvn || cpu.in_mvp {
            cpu.stall       = cycles_65c816[cpu.ir]
            cpu.cycles     += cpu.stall
        } else {
            cpu.all_cycles += cpu.cycles
        }

    case   .POST_EXEC:
        cpu.stall -= 1
        if cpu.stall > 0 { 
            return
        }
        cpu.state = .FETCH

    }

}


debug_w65c816 :: proc(c: ^CPU_65xxx) {
    fmt.printf("IP %02x:%04x|SP %04x|DP %04x|DBR %02x|",
        c.pc.bank & 0x00ff,
        c.pc.addr & 0xffff,
        c.sp.addr & 0xffff,
        c.d       & 0xffff,
        c.dbr     % 0x00ff
    )

    fmt.printf("%s%s",
        	"n" if c.f.N else ".",
        	"v" if c.f.V else ".",
    )
	if c.f.E {
    	fmt.printf("%s%s",
			"1",
			"b" if c.f.X else ".",
		)
	} else {
    	fmt.printf("%s%s",
        	"m" if c.f.M else ".",
			"x" if c.f.X else ".",
		)
	}
    fmt.printf("%s%s%s%s %s|",
        "d" if c.f.D else ".",
        "i" if c.f.I else ".",
        "z" if c.f.X else ".",
        "c" if c.f.C else ".",
        "e" if c.f.E else "."
    )

	if c.f.M {
    	fmt.printf("A %02x %02x|",
			c.a.b   & 0xFF,
			c.a.val & 0xFF
		)
	} else {
    	fmt.printf("A  %04x|",
			c.a.val & 0xFFFF
		)
	}

	if c.f.X {
    	fmt.printf("X   %02x|Y   %02x|",
			c.x.val & 0xFF,
			c.y.val & 0xFF
		)
	} else {
    	fmt.printf("X %04x|Y %04x|",
			c.x.val & 0xFFFF,
			c.y.val & 0xFFFF
		)
	}

	// print opcode and address mode
    opdata      := CPU_w65c816_opcodes[c.ir]
    argument    := parse_argument(c, opdata.mode)
    fmt.printf("%-4s %-12s ", opdata.opcode, argument)
    delete(argument)

    fmt.printf("\n")
}
// eof
