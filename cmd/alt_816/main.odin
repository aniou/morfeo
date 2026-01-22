package alt_816

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:prof/spall"
import "core:slice"
import "core:strconv"
import "core:time"

import "lib:emu"
import "lib:getargs"

import "emulator:platform"
import "emulator:bus"
import "emulator:cpu"

CPU_Pins :: struct {
    addr: u32,
    value: u32,
    outputs: string
}

CPU_State :: struct {
    pc:  u16,
    s:   u16,
    p:    u8,       // 8 x bool
    a:   u16,
    x:   u16,
    y:   u16,
    dbr: u16,       // in fact: u8
    d:   u16,
    pbr: u16,       // in fact: u8
    e:   int,       // in fact: bool
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
    c.dbr      = state.dbr
    c.d        = state.d
    c.pc.bank  = state.pbr
    c.cycles   = 0

    c.f.E = false if state.e         ==    0 else true
    c.f.N = true  if state.p  & 0x80 == 0x80 else false
    c.f.V = true  if state.p  & 0x40 == 0x40 else false
    c.f.M = true  if state.p  & 0x20 == 0x20 else false
    c.f.X = true  if state.p  & 0x10 == 0x10 else false
    c.f.D = true  if state.p  & 0x08 == 0x08 else false
    c.f.I = true  if state.p  & 0x04 == 0x04 else false
    c.f.Z = true  if state.p  & 0x02 == 0x02 else false
    c.f.C = true  if state.p  & 0x01 == 0x01 else false

    if c.f.X == cpu.byte {
        c.x.size = cpu.byte
        c.y.size = cpu.byte
    } else {
        c.x.size = cpu.word
        c.y.size = cpu.word
    }

    if c.f.M == cpu.byte {
        c.a.size = cpu.byte
        c.t.size = cpu.byte
    } else {
        c.a.size = cpu.word
        c.t.size = cpu.word
    }

    if c.f.E == true {
        c.sp.addr &= 0x00FF
        c.sp.addr |= 0x0100
        c.sp.size  = cpu.byte
    } else {
        c.sp.size  = cpu.word
    }

    // step 2: prepare memory
    for entry in state.ram {
        p.bus->write(.mode_8, entry[0], entry[1])
    }

    return
}

verify_test :: proc(p: ^platform.Platform, cycles: int, state: CPU_State) -> (err: bool) {
    c    := &p.cpu.model.(cpu.CPU_65xxx)

    if c.cycles != u32(cycles) {
        log.errorf("CYCLES  %d expected %d", c.cycles, cycles)
        err = true
    }

    if c.pc.addr != state.pc {
        log.errorf("PC  %02x:%04x expected %02x:%04x", c.pc.bank, c.pc.addr, state.pbr, state.pc)
        err = true
    }

    if c.sp.addr != state.s {
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

    if c.dbr != state.dbr {
        log.errorf("DBR     %02x expected   %02x", c.dbr, state.dbr)
        err = true
    }

    if c.d != state.d {
        log.errorf("D     %04x expected   %04x", c.d, state.d)
        err = true
    }

    if c.pc.bank != state.pbr {
        log.errorf("PBR     %02x expected   %02x", c.pc.bank, state.pbr)
        err = true
    }

    final_E := false if state.e         ==    0 else true
    final_N := true  if state.p  & 0x80 == 0x80 else false
    final_V := true  if state.p  & 0x40 == 0x40 else false
    final_M := true  if state.p  & 0x20 == 0x20 else false
    final_X := true  if state.p  & 0x10 == 0x10 else false
    final_D := true  if state.p  & 0x08 == 0x08 else false
    final_I := true  if state.p  & 0x04 == 0x04 else false
    final_Z := true  if state.p  & 0x02 == 0x02 else false
    final_C := true  if state.p  & 0x01 == 0x01 else false

    if c.f.E != final_E {
        log.errorf("E   %6t expected %6t", c.f.E, final_E)
        err = true
    }

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

    if c.f.X != final_X {
        log.errorf("X   %6t expected %6t", c.f.X, final_X)
        err = true
    }

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
        val = p.bus->read(.mode_8, entry[0])
        if val != entry[1] {
            log.errorf("MEM   %06x  %02x expected   %02x", entry[0], val, entry[1])
            err = true
        } else {
            p.bus->write(.mode_8, entry[0], 0)
        }
    }

    // step 4: check if all memory is empty
    // XXX: todo

    return
}

cpu_flags :: proc(p: u8, e: int) -> (result: string) {
    result = fmt.aprintf("%s%s%s%s%s%s%s%s %s",
        "n" if p  & 0x80 == 0x80 else ".",
        "v" if p  & 0x40 == 0x40 else ".",
        "m" if p  & 0x20 == 0x20 else ".",
        "x" if p  & 0x10 == 0x10 else ".",
        "d" if p  & 0x08 == 0x08 else ".",
        "i" if p  & 0x04 == 0x04 else ".",
        "z" if p  & 0x02 == 0x02 else ".",
        "c" if p  & 0x01 == 0x01 else ".",
        "e" if e         != 0    else "."
    )
    return
}

print_state :: proc(state: CPU_State, c: ^cpu.CPU) {
    c    := &c.model.(cpu.CPU_65xxx)

    state_flags := cpu_flags(state.p, state.e)
    log.errorf("data: PC %02x:%04x|SP %04x|A %04x|X %04x|Y %04x|DBR %02x|D: %04x|%s|AB %02x:%04x %04x|%s %s %s|",
        state.pbr, state.pc, state.s, state.a, state.x, state.y, state.dbr, state.d, state_flags,
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


do_test :: proc(p: ^platform.Platform, curr_test, all_tests: int, mode: string, name: int) -> (ok: bool) {
    // reading raw data
    ok = true
    fname := fmt.aprintf("external/tests-65816/v1/%02x.%s.json", name, mode)
    data, status := os.read_entire_file_from_filename(fname)
    if !status {
        log.error("Failed to load the file!")
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
    c.in_stp     = false
    start       := time.tick_now() 
    test_cycles :  int
    opdata      := cpu.CPU_w65c816_opcodes[name]

    for test in tests {
        prepare_test(p, test.initial)
        //if c.f.D do continue // skip decimal
        for {
            c->run(0)
            c.in_stp = false
            c.in_wai = false
            if (!c.in_mvn) && (!c.in_mvp) do break
        }
        test_cycles  = len(test.cycles)
        if name == 0xdb do test_cycles -= 1              // correction for current test data
        if name == 0xcb do test_cycles -= 1              // correction for current test data
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
        log.infof("test %03i/%03i mode %s opcode %02x %-4s %-8s tests %d time %i μs", 
                    curr_test, all_tests, mode, name, 
                    opdata.opcode,
                    cpu.CPU_65xxx_mode_name[opdata.mode],
                    count, ms_elapsed)
    }
    return
}




step_test :: proc(p: ^platform.Platform) -> (ok: bool) {

    codes :: [?]int {
        0xe1, 0xe3, 0xe5, 0xe7, 0xe9, 0xed, 0xef,           // sbc
        0xf1, 0xf2, 0xf3, 0xf5, 0xf7, 0xf9, 0xfd, 0xff,     // sbc
        0x61, 0x63, 0x65, 0x67, 0x69, 0x6d, 0x6f,           // 0xadc
        0x71, 0x72, 0x73, 0x75, 0x77, 0x79, 0x7d, 0x7f,     // 0xadc
        //54,                                               // mvn - 0xbroken tests
        //44,                                               // mvp - 0xbroken tests
        0xdb, 0xcb,                                         // stp, wai
        0xa1, 0xa3, 0xa5, 0xa7, 0xa9, 0xad, 0xaf,           // lda
        0xb1, 0xb2, 0xb3, 0xb5, 0xb7, 0xb9, 0xbd, 0xbf,     // lda
        0x90, 0xb0, 0xf0, 0x30, 0xd0,                       // 0xbcc, 0xbcs, 0xbeq, 0xbmi, 0xbne 
        0x10, 0x80, 0x50, 0x70, 0x82,                       // 0xbpl, 0xbra, 0xbvc, 0xbvs, 0xbrl
        0xa2, 0xa6, 0xae, 0xb6, 0xbe,                       // ldx 
        0xa0, 0xa4, 0xac, 0xb4, 0xbc,                       // ldy
        0xfb,                                               // xce
        0x4c, 0x5c, 0x6c, 0x7c, 0xdc,                       // jmp
        0x22, 0x20, 0xfc,                                   // jsl, jsr
        0x41, 0x43, 0x45, 0x47, 0x49, 0x4d, 0x4f,           // 0xeor
        0x51, 0x52, 0x53, 0x55, 0x57, 0x59, 0x5d, 0x5f,     // 0xeor
        0x01, 0x03, 0x05, 0x07, 0x09, 0x0d, 0x0f,           // ora
        0x11, 0x12, 0x13, 0x15, 0x17, 0x19, 0x1d, 0x1f,     // ora
        0x21, 0x23, 0x25, 0x27, 0x29, 0x2d, 0x2f,           // 0xand
        0x31, 0x32, 0x33, 0x35, 0x37, 0x39, 0x3d, 0x3f,     // 0xand
        0x06, 0x0a, 0x0e, 0x16, 0x1e,                       // 0xasl
        0x26, 0x2a, 0x2e, 0x36, 0x3e,                       // rol
        0x46, 0x4a, 0x4e, 0x56, 0x5e,                       // lsr
        0x66, 0x6a, 0x6e, 0x76, 0x7e,                       // ror
        0x1a, 0xe6, 0xee, 0xf6, 0xfe, 0xe8, 0xc8,           // inc, inx, iny
        0x3a, 0xc6, 0xce, 0xd6, 0xde, 0xca, 0x88,           // 0xdec, 0xdex, 0xdey
        0xc1, 0xc3, 0xc5, 0xc7, 0xc9, 0xcd, 0xcf,           // 0xcmp
        0xd1, 0xd2, 0xd3, 0xd5, 0xd7, 0xd9, 0xdd, 0xdf,     // 0xcmp
        0xe0, 0xe4, 0xec,                                   // 0xcpx
        0xc0, 0xc4, 0xcc,                                   // 0xcpy
        0x18, 0xd8, 0x58, 0xb8, 0x38, 0xf8, 0x78,           // 0xclc, sec 0xetc.
        0x81, 0x83, 0x85, 0x87, 0x8d, 0x8f,                 // sta
        0x91, 0x92, 0x93, 0x95, 0x97, 0x99, 0x9d, 0x9f,     // sta
        0x86, 0x8e, 0x96,                                   // stx
        0x84, 0x8c, 0x94,                                   // sty
        0x64, 0x74, 0x9c, 0x9e,                             // stz
        0xaa, 0xa8, 0xba, 0x8a, 0x9a, 0x9b, 0x98, 0xbb,     // tax, tay 0xetc.
        0xeb,                                               // xba
        0x5b, 0x1b, 0x7b, 0x3b,                             // tcd, tcs, tdc, tsc
        0x48, 0xda, 0x5a,                                   // pha, phx, phy
        0x68, 0xfa, 0x7a,                                   // pla, plx, ply
        0x8b, 0x0b, 0x4b, 0x08,                             // phb, phd, phk, php, 
        0xab, 0x2b, 0x28,                                   // plb, pld, plp
        0x6b, 0x60, 0x40,                                   // rtl, rts, rti
        0xf4, 0xd4, 0x62,                                   // pea, pei, per
        0x24, 0x2c, 0x34, 0x3c, 0x89,                       // 0xbit
        0xea, 0x42,                                         // nop, wdm
        0x14, 0x1c, 0x04, 0x0c,                             // trb, tsb
        0xc2, 0xe2,                                         // rep, sep
        0x00, 0x02,                                         // 0xbrk, 0xcop
    }

    do_test(p, -1, -1, "n", 0xea) or_return          // CPU warm-up
    tests_count  := len(codes) * 2
    current_test := 1
    for name in codes {
        do_test(p, current_test, tests_count, "n", name) or_return
        current_test += 1
        do_test(p, current_test, tests_count, "e", name) or_return
        current_test += 1
    }

    return true
}

math_test :: proc(p: ^platform.Platform) -> (ok: bool) {
    f, error := os.open("data/6502_decimal_test-65c816.bin")
    if error != nil {
        log.error("error opening file: ", error)
        return false
    }

    _, error  = os.read(f, p.bus.aram0.data[:])
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
        if c.in_stp do break  // we use modified code, STP is used to finish
    }

    status := p.bus->read(.mode_8, 0x0b)
    if status == 0 {
        log.infof("65c816_decimal_test passed (%02x)", status)
    } else {
        log.errorf("65c818_decimal_test failed (%02x): %s%s%s%s %04x",
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

// a simple, but unreliable due to impact from cpu cache,
// test for a bus speed (even if a this routine shows an
// improvement like 50% then real load may be 20% slower)
//
bus_test :: proc(p: ^platform.Platform, name: string) {
    val : u32
    rounds := 100_000_000
    start_time := time.tick_now()
    for ra in 0..<rounds {
        val = p.bus->read(.mode_8, 0x0 + u32(ra & 0xFF_FFFF))
        p.bus->write(.mode_8, 0xFF_FFFF - u32(ra & 0xFF_FFFF), val)
    }
    elapsed := time.tick_since(start_time)
    log.infof("%s rounds %d : elapsed %5.5f : %.3e/sec", name,
            rounds, time.duration_milliseconds(elapsed), f64(rounds) / time.duration_seconds(elapsed))
}

all_tests :: proc(p: ^platform.Platform) -> (ok: bool) {
    bus_test(p, "bus_speed")
    math_test(p) or_return
    step_test(p) or_return
    return true
}

main :: proc() {
	// https://gist.github.com/karl-zylinski/4ccf438337123e7c8994df3b03604e33
    /*
	when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
                if len(track.allocation_map) > 0 {
                        fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                        for _, entry in track.allocation_map {
                                fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                        }
                }
                if len(track.bad_free_array) > 0 {
                        fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                        for entry in track.bad_free_array {
                                fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                        }
                }
                mem.tracking_allocator_destroy(&track)
        }
	}
    */

    logger_options := log.Options{.Level};
    context.logger  = log.create_console_logger(opt = logger_options) 

    // init -------------------------------------------------------------
    p       := platform.make_alt816()
    c       := &p.cpu.model.(cpu.CPU_65xxx) 
    c.debug  = false
    
    // running ----------------------------------------------------------
    all_tests(p)

    // exiting ----------------------------------------------------------
    p->delete()
    log.destroy_console_logger(context.logger)
}

