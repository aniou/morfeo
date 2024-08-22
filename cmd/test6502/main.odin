package test816

import "lib:emu"
import "lib:getargs"

import "emulator:platform"
import "emulator:bus"
import "emulator:cpu"
import "emulator:gpu"

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:os"
import "core:prof/spall"
import "core:slice"
import "core:strconv"
import "core:time"

CPU_State :: struct {
    pc:  u16,
    s:   u16,
    p:    u8,       // 8 x bool
    a:   u16,
    x:   u16,
    y:   u16,
    ram: [dynamic][2]u32,
}

CPU_Test :: struct {
    initial: CPU_State,
    final:   CPU_State,
    name:    string,
    cycles: [dynamic][3]json.Value
}

prepare_test :: proc(p: ^platform.Platform, state: CPU_State) {
    c    := &p.cpu.model.(cpu.CPU_65C816)

    // step 1: prepare CPU values
    c.pc.addr  = state.pc
    c.sp.addr  = state.s
    c.a.val    = state.a
    c.a.b      = state.a & 0xFF00
    c.x.val    = state.x
    c.y.val    = state.y
    c.cycles   = 0

    c.f.N = true  if state.p  & 0x80 == 0x80 else false
    c.f.V = true  if state.p  & 0x40 == 0x40 else false
    c.f.M = true  if state.p  & 0x20 == 0x20 else false     // does not exist in 6502
    c.f.X = true  if state.p  & 0x10 == 0x10 else false     // in fact: B
    c.f.D = true  if state.p  & 0x08 == 0x08 else false
    c.f.I = true  if state.p  & 0x04 == 0x04 else false
    c.f.Z = true  if state.p  & 0x02 == 0x02 else false
    c.f.C = true  if state.p  & 0x01 == 0x01 else false
    c.f.E = true                                            // always, it is a 65c02

    if c.f.E == true {
        c.sp.addr &= 0x00FF
        c.sp.addr |= 0x0100
        c.sp.size  = cpu.byte
    } else {
        c.sp.size  = cpu.word
    }

    // step 2: prepare memory
    for entry in state.ram {
        p.bus.ram0->write(.bits_8, entry[0], entry[1])
    }

    return
}

verify_test :: proc(p: ^platform.Platform, cycles: int, state: CPU_State) -> (err: bool) {
    c    := &p.cpu.model.(cpu.CPU_65C816)

    if c.cycles != u32(cycles) {
        log.errorf("CYCLES  %d expected %d", c.cycles, cycles)
        err = true
    }

    if c.pc.addr != state.pc {
        log.errorf("PC       %04x expected      %04x", c.pc.addr, state.pc)
        err = true
    }

    // on 6502 SP is a 8bit register - index on page 1 (01) thus tests
    // expects value 00xx in SP
    // because my code is built upon 65c816-compatible routines then
    // D(irect page) register is 16bit with high byte forced to 0x01
    // when E flag is set (and for 6502 emulation and "native" code it
    // is set always)
    //
    // Thus we mask high byte in SP 
    //
    if (c.sp.addr & 0x00FF) != state.s {
        log.errorf("SP  %06x expected %06x", c.sp.addr, state.s)
        err = true
    }

    a := cpu.read_r( c.a, cpu.word )
    if state.a != a {
        log.errorf("A     %04x expected   %04x", a, state.a)
        err = true
    }

    if c.x.val != state.x {
        log.errorf("X     %04x expected   %04x", c.x.val, state.x)
        err = true
    }

    if c.y.val != state.y {
        log.errorf("Y     %04x expected   %04x", c.y.val, state.y)
        err = true
    }

    final_N := true  if state.p  & 0x80 == 0x80 else false
    final_V := true  if state.p  & 0x40 == 0x40 else false
    final_M := true  if state.p  & 0x20 == 0x20 else false
    final_X := true  if state.p  & 0x10 == 0x10 else false
    final_D := true  if state.p  & 0x08 == 0x08 else false
    final_I := true  if state.p  & 0x04 == 0x04 else false
    final_Z := true  if state.p  & 0x02 == 0x02 else false
    final_C := true  if state.p  & 0x01 == 0x01 else false

    if c.f.N != final_N {
        log.errorf("N   %6t expected %6t", c.f.N, final_N)
        err = true
    }

    if c.f.V != final_V {
        log.errorf("V   %6t expected %6t", c.f.V, final_V)
        err = true
    }

    if c.f.M != final_M {
        log.errorf("M   %6t expected %6t", c.f.M, final_M)
        err = true
    }

    // that test doesn't make sense because value is accesible
    // only by pushing values on stack and that is tested in 
    // php
    //if c.f.X != final_X {
    //    log.errorf("B   %6t expected %6t", c.f.X, final_X)
    //    err = true
    //}

    if c.f.D != final_D {
        log.errorf("D   %6t expected %6t", c.f.D, final_D)
        err = true
    }

    if c.f.I != final_I {
        log.errorf("I   %6t expected %6t", c.f.I, final_I)
        err = true
    }

    if c.f.Z != final_Z {
        log.errorf("Z   %6t expected %6t", c.f.Z, final_Z)
        err = true
    }

    if c.f.C != final_C {
        log.errorf("C   %6t expected %6t", c.f.C, final_C)
        err = true
    }

    // step 3: check memory
    val : u32
    for entry in state.ram {
        val = p.bus.ram0->read(.bits_8, entry[0])
        if val != entry[1] {
            log.errorf("MEM   %06x  %02x expected   %02x", entry[0], val, entry[1])
            err = true
        } else {
            p.bus.ram0->write(.bits_8, entry[0], 0)
        }
    }

    // step 4: check if all memory is empty
    // XXX: todo

    return
}

cpu_flags :: proc(p: u8) -> (result: string) {
    result = fmt.aprintf("%s%s%s%s%s%s%s%s   ",
        "n" if p  & 0x80 == 0x80 else ".",
        "v" if p  & 0x40 == 0x40 else ".",
        "1" if p  & 0x20 == 0x20 else ".",
        "b" if p  & 0x10 == 0x10 else ".",
        "d" if p  & 0x08 == 0x08 else ".",
        "i" if p  & 0x04 == 0x04 else ".",
        "z" if p  & 0x02 == 0x02 else ".",
        "c" if p  & 0x01 == 0x01 else ".",
    )
    return
}

print_state :: proc(state: CPU_State, c: ^cpu.CPU) {
    c    := &c.model.(cpu.CPU_65C816)

    state_flags := cpu_flags(state.p)
    log.errorf("data: PC %04x|SP %04x|A %04x|X %04x|Y %04x|%s|AB %02x:%04x %04x|%s %s %s|",
        state.pc, state.s, state.a, state.x, state.y, state_flags,
        c.ab.bank, c.ab.addr, c.ab.index, 
        "bw" if c.ab.bwrap else "..",
        "pw" if c.ab.bwrap else "..",
        "px" if c.px       else ".."
    )

    addr := make([dynamic]u32, 0)
    mem  := make(map[u32]u32)

    for m in state.ram {
        append(&addr, m[0])
        mem[m[0]] = m[1]
    }
    slice.sort(addr[:])

    for m in addr {
        log.errorf("addr: %06x %02x", m, mem[m])
    }

    delete(addr)
    delete(mem)
}


do_test :: proc(p: ^platform.Platform, curr_test, all_tests: int, name: int) -> (ok: bool) {
    // reading raw data
    ok = true
    fname := fmt.aprintf("external/tests-6502/wdc65c02/v1/%02x.json", name)
    data, status := os.read_entire_file_from_filename(fname)
    if !status {
        log.errorf("Failed to load the file: %s", fname)
        ok = false
        return
    }
    defer delete(data)
    defer delete(fname)

    // parsing
    tests: [dynamic]CPU_Test
    err := json.unmarshal(data, &tests, .MJSON)             // XXX: memleak here
    if err != nil {
        log.error("Error in json.unmarshal:", err)
        ok = false
        return 
    }
    defer delete(tests)

    // do work
    count       := 0
    c           := &p.cpu.model.(cpu.CPU_65C816) 
    start       := time.tick_now() 
    test_cycles :  int
    for test in tests {
        prepare_test(p, test.initial)
        for {
            c->run(0)
            if (!c.in_mvn) && (!c.in_mvp) do break
        }
        test_cycles  = len(test.cycles)
        if name == 0x5C do test_cycles = 8   // correction for current test data
        fail := verify_test(p, test_cycles, test.final)
        if fail {
            log.error("test: ", test.name)
            print_state(test.initial, p.cpu)
            print_state(test.final, p.cpu)
            ok = false
            break
        }
        count += 1
    }
    ms_elapsed := u64(time.tick_since(start) / time.Microsecond)
    if curr_test != -1 {
        opdata := cpu.CPU_W65C06_opcodes[name]
        log.infof("test %03i/%03i mode %s opcode %02x %-4s %8s tests %d time %i μs", 
              curr_test, all_tests, "n", name, 
              opdata.opcode, 
              cpu.CPU_65xxx_mode_name[opdata.mode],
              count, ms_elapsed
        )
    }
    return
}




main_loop :: proc(p: ^platform.Platform) -> (err: bool) {

    codes :: [?]int {
        0x54,                                               // 
        0x44,                                               // 
        0xa1, 0xa3, 0xa5, 0xa7, 0xa9, 0xad, 0xaf,           // lda
        0xb1, 0xb2, 0xb3, 0xb5, 0xb7, 0xb9, 0xbd, 0xbf,     // lda
        0x90, 0xb0, 0xf0, 0x30, 0xd0,                       // bcc, bcs, beq, bmi, bne 
        0x10, 0x80, 0x50, 0x70, 0x82,                       // bpl, bra, bvc, bvs, brl
        0xa2, 0xa6, 0xae, 0xb6, 0xbe,                       // ldx 
        0xa0, 0xa4, 0xac, 0xb4, 0xbc,                       // ldy
        0xfb,                                               // xce
        0x4c, 0x5c, 0x6c, 0x7c, 0xdc,                       // jmp
        0x22, 0x20, 0xfc,                                   // jsl, jsr
        0x41, 0x43, 0x45, 0x47, 0x49, 0x4d, 0x4f,           // eor
        0x51, 0x52, 0x53, 0x55, 0x57, 0x59, 0x5d, 0x5f,     // eor
        0x01, 0x03, 0x05, 0x07, 0x09, 0x0d, 0x0f,           // ora
        0x11, 0x12, 0x13, 0x15, 0x17, 0x19, 0x1d, 0x1f,     // ora
        0x21, 0x23, 0x25, 0x27, 0x29, 0x2d, 0x2f,           // and
        0x31, 0x32, 0x33, 0x35, 0x37, 0x39, 0x3d, 0x3f,     // and
        0x06, 0x0a, 0x0e, 0x16, 0x1e,                       // asl
        0x26, 0x2a, 0x2e, 0x36, 0x3e,                       // rol
        0x46, 0x4a, 0x4e, 0x56, 0x5e,                       // lsr
        0x66, 0x6a, 0x6e, 0x76, 0x7e,                       // ror
        0x1a, 0xe6, 0xee, 0xf6, 0xfe, 0xe8, 0xc8,           // inc, inx, iny
        0x3a, 0xc6, 0xce, 0xd6, 0xde, 0xca, 0x88,           // dec, dex, dey
        0xc1, 0xc3, 0xc5, 0xc7, 0xc9, 0xcd, 0xcf,           // cmp
        0xd1, 0xd2, 0xd3, 0xd5, 0xd7, 0xd9, 0xdd, 0xdf,     // cmp
        0xe0, 0xe4, 0xec,                                   // cpx
        0xc0, 0xc4, 0xcc,                                   // cpy
        0x18, 0xd8, 0x58, 0xb8, 0x38, 0xf8, 0x78,           // clc, sec etc.
        0x81, 0x83, 0x85, 0x87, 0x8d, 0x8f,                 // sta
        0x91, 0x92, 0x93, 0x95, 0x97, 0x99, 0x9d, 0x9f,     // sta
        0x86, 0x8e, 0x96,                                   // stx
        0x84, 0x8c, 0x94,                                   // sty
        0x64, 0x74, 0x9c, 0x9e,                             // stz
        0xaa, 0xa8, 0xba, 0x8a, 0x9a, 0x9b, 0x98, 0xbb,     // tax, tay etc.
        0xeb,                                               // xba
        0x5b, 0x1b, 0x7b, 0x3b,                             // tcd, tcs, tdc, tsc
        0x48, 0xda, 0x5a,                                   // pha, phx, phy
        0x68, 0xfa, 0x7a,                                   // pla, plx, ply
        0x24, 0x2c, 0x34, 0x3c, 
        0x89,
        0xea, 0x42,                                         // nop, wdm
        0x14, 0x1c, 0x04, 0x0c,                             // trb, tsb
        0xc2, 0xe2,                                         // rep, sep
        0x71, 0x72, 0x73, 0x75, 0x77, 0x79, 0x7d, 0x7f,     // adc
        0x8b, 0x0b, 0x4b, 0x08,                             // phb, phd, phk, php, 
        0xab, 0x2b, 0x28,                                   // plb, pld, plp
        0x6b, 0x60, 0x40,                                   // rtl, rts, rti
        0xf4, 0xd4, 0x62,                                   // pea, pei, per
        0x00, 0x02,                                         // brk, cop
        0x61, 0x63, 0x65, 0x67, 0x69, 0x6d, 0x6f,           // adc
        0xe1, 0xe3, 0xe5, 0xe7, 0xe9, 0xed, 0xef,           // sbc
        0xf1, 0xf2, 0xf3, 0xf5, 0xf7, 0xf9, 0xfd, 0xff,     // sbc
        //"db"                                                // STP has no json test
        //"cb"                                                // WAI has no json test
    }

    do_test(p, -1, -1, 0xEA) or_return          // CPU warm-up
    tests_count  := len(codes)
    current_test := 1
    for name in codes {
        do_test(p, current_test, tests_count, name) or_break
        current_test += 1
    }

    return
}


main :: proc() {
    logger_options := log.Options{.Level};
    context.logger  = log.create_console_logger(opt = logger_options) 

    // init -------------------------------------------------------------
    //log.info("Running...")
    p := platform.make_simple6502()
    
    // running ----------------------------------------------------------
    main_loop(p)

    // exiting ----------------------------------------------------------
    p->delete()
    //log.info("Exiting...")
    log.destroy_console_logger(context.logger)
    os.exit(0)
}

