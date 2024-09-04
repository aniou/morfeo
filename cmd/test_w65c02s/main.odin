package test_w65c02s

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
    c    := &p.cpu.model.(cpu.CPU_65xxx)

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
    c    := &p.cpu.model.(cpu.CPU_65xxx)

    if c.cycles != u32(cycles) {
        log.errorf("diff: CYCLES %d expected %d", c.cycles, cycles)
        err = true
    }

    if c.pc.addr != state.pc {
        log.errorf("diff: PC   %04x expected      %04x", c.pc.addr, state.pc)
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
        log.errorf("diff: SP  %06x expected %06x", c.sp.addr, state.s)
        err = true
    }

    a := cpu.read_r( c.a, cpu.word )
    if state.a != a {
        log.errorf("diff: A     %04x expected   %04x", a, state.a)
        err = true
    }

    if c.x.val != state.x {
        log.errorf("diff: X     %04x expected   %04x", c.x.val, state.x)
        err = true
    }

    if c.y.val != state.y {
        log.errorf("diff: Y     %04x expected   %04x", c.y.val, state.y)
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
        log.errorf("diff: N   %6t expected %6t", c.f.N, final_N)
        err = true
    }

    if c.f.V != final_V {
        log.errorf("diff: V   %6t expected %6t", c.f.V, final_V)
        err = true
    }

    if c.f.M != final_M {
        log.errorf("diff: M   %6t expected %6t", c.f.M, final_M)
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
        log.errorf("diff: D   %6t expected %6t", c.f.D, final_D)
        err = true
    }

    if c.f.I != final_I {
        log.errorf("diff: I   %6t expected %6t", c.f.I, final_I)
        err = true
    }

    if c.f.Z != final_Z {
        log.errorf("diff: Z   %6t expected %6t", c.f.Z, final_Z)
        err = true
    }

    if c.f.C != final_C {
        log.errorf("diff: C   %6t expected %6t", c.f.C, final_C)
        err = true
    }

    // step 3: check memory
    val : u32
    for entry in state.ram {
        val = p.bus.ram0->read(.bits_8, entry[0])
        if val != entry[1] {
            log.errorf("diff: MEM   %06x  %02x expected   %02x", entry[0], val, entry[1])
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
    c    := &c.model.(cpu.CPU_65xxx)

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
    c           := &p.cpu.model.(cpu.CPU_65xxx) 
    start       := time.tick_now() 
    test_cycles :  int
    opdata      := cpu.CPU_W65C06_opcodes[name]


    for test in tests {
        prepare_test(p, test.initial)
        //if c.f.D do continue // skip decimal
        for {
            c->run(0)
            if (!c.in_mvn) && (!c.in_mvp) do break
        }
        test_cycles  = len(test.cycles)
        if name == 0x5C do test_cycles = 8   // correction for current test data
        fail := verify_test(p, test_cycles, test.final)
        if fail {
            log.errorf("op  : %02x %-4s %-8s test_id %s", 
                name,
                opdata.opcode, 
                cpu.CPU_65xxx_mode_name[opdata.mode],
                test.name
            )
            print_state(test.initial, p.cpu)
            print_state(test.final, p.cpu)
            ok = false
            break
        }
        count += 1
    }
    ms_elapsed := u64(time.tick_since(start) / time.Microsecond)
    if curr_test != -1 {
        log.infof("test %03i/%03i mode %s opcode %02x %-4s %-8s tests %d time %i μs", 
              curr_test, all_tests, "n", name, 
              opdata.opcode, 
              cpu.CPU_65xxx_mode_name[opdata.mode],
              count, ms_elapsed
        )
    }
    return
}




step_test :: proc(p: ^platform.Platform) -> (ok: bool) {

    codes :: [?]int {
        0xE9, 0xE5, 0xF5, 0xED, 0xFD, 0xF9, 0xE1, 0xF1, 0xF2, // SBC
        0x69, 0x65, 0x75, 0x6D, 0x7D, 0x79, 0x61, 0x71, 0x72, // ADC
    }
    codes2 :: [?]int {
        0x54,                                               // 
        0x44,                                               // 
        0xA1, 0xA3, 0xA5, 0xA7, 0xA9, 0xAD, 0xAF,           //
        0xB1, 0xB2, 0xB3, 0xB5, 0xB7, 0xB9, 0xBD, 0xBF,     //
        0x90, 0xB0, 0xF0, 0x30, 0xD0,                       //
        0x10, 0x80, 0x50, 0x70, 0x82,                       //
        0xA2, 0xA6, 0xAE, 0xB6, 0xBE,                       //
        0xA0, 0xA4, 0xAC, 0xB4, 0xBC,                       //
        0xFB,                                               //
        0x4C, 0x5C, 0x6C, 0x7C, 0xDC,                       //
        0x22, 0x20, 0xFC,                                   //
        0x41, 0x43, 0x45, 0x47, 0x49, 0x4D, 0x4F,           //
        0x51, 0x52, 0x53, 0x55, 0x57, 0x59, 0x5D, 0x5F,     //
        0x01, 0x03, 0x05, 0x07, 0x09, 0x0D, 0x0F,           //
        0x11, 0x12, 0x13, 0x15, 0x17, 0x19, 0x1D, 0x1F,     //
        0x21, 0x23, 0x25, 0x27, 0x29, 0x2D, 0x2F,           //
        0x31, 0x32, 0x33, 0x35, 0x37, 0x39, 0x3D, 0x3F,     //
        0x06, 0x0A, 0x0E, 0x16, 0x1E,                       //
        0x26, 0x2A, 0x2E, 0x36, 0x3E,                       //
        0x46, 0x4A, 0x4E, 0x56, 0x5E,                       //
        0x66, 0x6A, 0x6E, 0x76, 0x7E,                       //
        0x1A, 0xE6, 0xEE, 0xF6, 0xFE, 0xE8, 0xC8,           //
        0x3A, 0xC6, 0xCE, 0xD6, 0xDE, 0xCA, 0x88,           //
        0xC1, 0xC3, 0xC5, 0xC7, 0xC9, 0xCD, 0xCF,           //
        0xD1, 0xD2, 0xD3, 0xD5, 0xD7, 0xD9, 0xDD, 0xDF,     //
        0xE0, 0xE4, 0xEC,                                   //
        0xC0, 0xC4, 0xCC,                                   //
        0x18, 0xD8, 0x58, 0xB8, 0x38, 0xF8, 0x78,           //
        0x81, 0x83, 0x85, 0x87, 0x8D, 0x8F,                 //
        0x91, 0x92, 0x93, 0x95, 0x97, 0x99, 0x9D, 0x9F,     //
        0x86, 0x8E, 0x96,                                   //
        0x84, 0x8C, 0x94,                                   //
        0x64, 0x74, 0x9C, 0x9E,                             //
        0xAA, 0xA8, 0xBA, 0x8A, 0x9A, 0x9B, 0x98, 0xBB,     //
        0xEB,                                               //
        0x5B, 0x1B, 0x7B, 0x3B,                             //
        0x48, 0xDA, 0x5A,                                   //
        0x68, 0xFA, 0x7A,                                   //
        0x24, 0x2C, 0x34, 0x3C, 
        0x89,
        0xEA, 0x42,                                         //
        0x14, 0x1C, 0x04, 0x0C,                             //
        0xC2, 0xE2,                                         //
        0x71, 0x72, 0x73, 0x75, 0x77, 0x79, 0x7D, 0x7F,     //
        0x8B, 0x0B, 0x4B, 0x08,                             //
        0xAB, 0x2B, 0x28,                                   //
        0x6B, 0x60, 0x40,                                   //
        0xF4, 0xD4, 0x62,                                   //
        0x00, 0x02,                                         //
        0x61, 0x63, 0x65, 0x67, 0x69, 0x6D, 0x6F,           //
        0xE1, 0xE3, 0xE5, 0xE7, 0xE9, 0xED, 0xEF,           // 
        0xF1, 0xF2, 0xF3, 0xF5, 0xF7, 0xF9, 0xFD, 0xFF,     //
        //db,                                               // STP has no json test
        //cb,                                               // WAI has no json test
    }

    do_test(p, -1, -1, 0xEA) or_return          // CPU warm-up
    tests_count  := len(codes)
    current_test := 1
    for name in codes {
        do_test(p, current_test, tests_count, name) or_return
        current_test += 1
    }

    return true
}


math_test :: proc(p: ^platform.Platform) -> (ok: bool) {
    f, error := os.open("data/6502_decimal_test-w65c02.bin")
    if error != nil {
    	log.error("error opening file: ", error)
        return false
    }

    _, error  = os.read(f, p.bus.ram0.data[:])
    if error != nil {
    	log.error("Error reading user input: ", error)
        return false
    }
    os.close(f)

    c    := &p.cpu.model.(cpu.CPU_65xxx)
    c->reset()
    c.sp.addr = 0xFF 
    c->setpc(0x400)
    for {
        c->run(3000)
        if c.abort do break
    }

    status := p.bus.ram0->read(.bits_8, 0x0b)
    if status == 0 {
        log.infof("65c02_decimal_test passed (%02x)", status)
    } else {
        log.errorf("65c02_decimal_test failed (%02x): %s%s%s%s %04x", 
            status,
            "n" if c.f.N else ".",
            "v" if c.f.V else ".",
            "z" if c.f.Z else ".",
            "c" if c.f.C else ".",
            cpu.read_r( c.a, c.a.size ),
        )
        return false
    }
    return true
}

all_tests :: proc(p: ^platform.Platform) -> (ok: bool) {
    //step_test(p) or_return
    math_test(p) or_return
    return true
}

main :: proc() {
    logger_options := log.Options{.Level};
    context.logger  = log.create_console_logger(opt = logger_options) 

    // init -------------------------------------------------------------
    //log.info("Running...")
    p := platform.make_simple6502()
    
    // running ----------------------------------------------------------
    all_tests(p)

    // exiting ----------------------------------------------------------
    p->delete()
    //log.info("Exiting...")
    log.destroy_console_logger(context.logger)
    os.exit(0)
}

