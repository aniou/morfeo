package cpu

import "base:runtime"
import "core:fmt"
import "core:log"
import "emulator:bus"
import "emulator:pic"

import "lib:emu"

import "core:prof/spall"

// from Musashi - unfortunately Odin cannot import enums from .h 
// files, like Golang

/* CPU types for use in m68k_set_cpu_type() */
CPU_type :: enum {
        M68K_CPU_TYPE_INVALID,
        M68K_CPU_TYPE_68000,
        M68K_CPU_TYPE_68010,
        M68K_CPU_TYPE_68EC020,
        M68K_CPU_TYPE_68020,
        M68K_CPU_TYPE_68EC030,
        M68K_CPU_TYPE_68030,
        M68K_CPU_TYPE_68EC040,
        M68K_CPU_TYPE_68LC040,
        M68K_CPU_TYPE_68040,
        M68K_CPU_TYPE_SCC68070
};

M68K_INT_ACK_AUTOVECTOR  ::  0xffffffff
M68K_INT_ACK_SPURIOUS    ::  0xfffffffe

/* Registers used by m68k_get_reg() and m68k_set_reg() */
Register :: enum {
        /* Real registers */
        M68K_REG_D0,            /* Data registers */
        M68K_REG_D1,
        M68K_REG_D2,
        M68K_REG_D3,
        M68K_REG_D4,
        M68K_REG_D5,
        M68K_REG_D6,
        M68K_REG_D7,
        M68K_REG_A0,            /* Address registers */
        M68K_REG_A1,
        M68K_REG_A2,
        M68K_REG_A3,
        M68K_REG_A4,
        M68K_REG_A5,
        M68K_REG_A6,
        M68K_REG_A7,
        M68K_REG_PC,            /* Program Counter */
        M68K_REG_SR,            /* Status Register */
        M68K_REG_SP,            /* The current Stack Pointer (located in A7) */
        M68K_REG_USP,           /* User Stack Pointer */
        M68K_REG_ISP,           /* Interrupt Stack Pointer */
        M68K_REG_MSP,           /* Master Stack Pointer */
        M68K_REG_SFC,           /* Source Function Code */
        M68K_REG_DFC,           /* Destination Function Code */
        M68K_REG_VBR,           /* Vector Base Register */
        M68K_REG_CACR,          /* Cache Control Register */
        M68K_REG_CAAR,          /* Cache Address Register */

        /* Assumed registers */
        /* These are cheat registers which emulate the 1-longword prefetch
         * present in the 68000 and 68010.
         */
        M68K_REG_PREF_ADDR,     /* Last prefetch address */
        M68K_REG_PREF_DATA,     /* Last prefetch data */

        /* Convenience registers */
        M68K_REG_PPC,           /* Previous value in the program counter */
        M68K_REG_IR,            /* Instruction register */
        M68K_REG_CPU_TYPE       /* Type of CPU being run */
}


foreign import musashi {
    "../../external/Musashi/m68kcpu.o",
    "../../external/Musashi/m68kdasm.o", 
    "../../external/Musashi/m68kops.o",
    "../../external/Musashi/softfloat/softfloat.o",
}

@(default_calling_convention="c")
foreign musashi {
    m68k_init         :: proc() ---
    m68k_pulse_reset  :: proc() ---
    m68k_execute      :: proc(uint) -> uint ---
    m68k_set_reg      :: proc(Register, uint) ---
    m68k_set_cpu_type :: proc(CPU_type)       ---
    m68k_set_irq      :: proc(uint) ---
}

CPU_m68k :: struct {
    using cpu: ^CPU, 

    type:   CPU_type
}


// XXX - parametrize CPU type!
m68k_make :: proc (name: string, bus: ^bus.Bus) -> ^CPU {

    cpu       := new(CPU)
    cpu.name   = name
    cpu.delete = m68k_delete
    cpu.setpc  = m68k_setpc
    cpu.reset  = m68k_reset
    cpu.run    = m68k_exec
    cpu.clear_irq   = m68k_clear_irq
    cpu.bus    = bus
    cpu.all_cycles = 0
    c         := CPU_m68k{cpu = cpu, type = CPU_type.M68K_CPU_TYPE_68EC030}
    cpu.model  = c

    // we need global because of external musashi (XXX - maybe whole CPU?)
    localbus   = bus
    ctx        = context

    m68k_init();
    m68k_set_cpu_type(c.type)

    return cpu
}

m68k_delete :: proc (cpu: ^CPU) {
    free(cpu)
    return
}

m68k_setpc :: proc(cpu: ^CPU, address: u32) {
    m68k_set_reg(Register.M68K_REG_PC, uint(address))
    return 
}


m68k_reset :: proc(cpu: ^CPU) {

        // just for test
        // C.m68k_write_memory_32(0,           0x08_0000)    // stack
        // C.m68k_write_memory_32(4,           0x20_0000)    // instruction pointer
        // C.m68k_write_memory_16(0x20_0000,      0x7042)    // moveq  #41, D0
        // C.m68k_write_memory_16(0x20_0002,      0x13C0)    // move.b D0, $AFA000
        // C.m68k_write_memory_32(0x20_0004, 0x00AF_A000)    // ...
        // C.m68k_write_memory_32(0x20_0004, 0x00A0_A000)    // ...
        // C.m68k_write_memory_32(0x20_0008, 0x60F6_4E71)    // bra to 20_0000

        // normal
        m68k_pulse_reset()
        return
}

m68k_clear_irq :: proc(cpu: ^CPU) {
    if localbus.pic.irq_clear {
        log.debugf("%s IRQ clear", cpu.name)
        localbus.pic.irq_clear  = false
        localbus.pic.irq_active = false
        localbus.pic.current    = pic.IRQ.NONE
        m68k_set_irq(uint(pic.IRQ.NONE))
    }
}

m68k_exec :: proc(cpu: ^CPU, ticks: u32 = 1000) {
    context = ctx
    current_ticks : u32 = 0

    for current_ticks < ticks {
        // 1. check if there is irq to clear
        if localbus.pic.irq_clear {
            log.debugf("%s IRQ clear", cpu.name)
            localbus.pic.irq_clear  = false
            localbus.pic.irq_active = false
            localbus.pic.current    = pic.IRQ.NONE
            m68k_set_irq(uint(pic.IRQ.NONE))
        }

        // 2. recalculate interupts
        // XXX: implement it

        // 3. check if there is a pending irq?
        if localbus.pic.irq_active == false && localbus.pic.current != pic.IRQ.NONE {
            log.debugf("%s IRQ should be set!", cpu.name)
            localbus.pic.irq_active = true
            log.debugf("IRQ active from exec %v irq %v", localbus.pic.irq_active, localbus.pic.irq)
            m68k_set_irq(localbus.pic.irq)
        }

        cycles          := m68k_execute(1000)
        cpu.all_cycles  += u32(cycles)
        current_ticks   += 1000
        //log.debugf("%s execute %d cycles", cpu.name, current_ticks)
    }
    //log.debugf("%s execute %d cycles", cpu.name, cpu.cycles)
    return
}

@export
m68k_cpu_irq_ack :: proc "c" (level: uint) -> uint {
    context = ctx
    log.debugf("IRQ active from ACK %v", localbus.pic.irq_active)
    if localbus.pic.irq_active == false {
        return M68K_INT_ACK_SPURIOUS
    }
    log.debugf("cpu0 IRQ ACK requested %d responded %d", level, localbus.pic.vector)
    return localbus.pic.vector
}

@export
m68k_read_disassembler_16 :: proc "c" (address: uint) -> uint {
    context = ctx

    val := uint(localbus->read(.bits_16, u32(address)))
    return val
}

@export
m68k_read_disassembler_32 :: proc "c" (address: uint) -> uint {
    context = ctx

    val := uint(localbus->read(.bits_32, u32(address)))
    return val
}

@export
m68k_read_memory_8 :: proc "c" (address: uint) -> uint {
    context = ctx
    //spall.SCOPED_EVENT(&bus.spall_ctx, &bus.spall_buffer, #procedure)

    val := uint(localbus->read(.bits_8, u32(address)))

    return val
}

@export
m68k_read_memory_16 :: proc "c" (address: uint) -> uint {
    context = ctx
    //spall.SCOPED_EVENT(&bus.spall_ctx, &bus.spall_buffer, #procedure)

    val := uint(localbus->read(.bits_16, u32(address)))
    return val
}

@export
m68k_read_memory_32 :: proc "c" (address: uint) -> uint {
    context = ctx
    //spall.SCOPED_EVENT(&bus.spall_ctx, &bus.spall_buffer, #procedure)

    val := uint(localbus->read(.bits_32, u32(address)))
    return val
}

@export
m68k_write_memory_8 :: proc "c" (address: uint, value: uint) {
    context = ctx

    localbus->write(.bits_8, u32(address), u32(value))
    return
}

@export
m68k_write_memory_16 :: proc "c" (address: uint, value: uint) {
    context = ctx

    localbus->write(.bits_16, u32(address), u32(value))

    return
}

@export
m68k_write_memory_32 :: proc "c" (address: uint, value: uint) {
    context = ctx

    localbus->write(.bits_32, u32(address), u32(value))

    return
}

