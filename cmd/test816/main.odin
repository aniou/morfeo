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
    c    := &p.cpu.model.(cpu.CPU_65C816)

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
    }

    // step 2: prepare memory
    for entry in state.ram {
        p.bus.ram0->write(.bits_8, entry[0], entry[1])
    }

    return
}

verify_test :: proc(p: ^platform.Platform, state: CPU_State) -> (err: bool) {
    c    := &p.cpu.model.(cpu.CPU_65C816)

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
    c    := &c.model.(cpu.CPU_65C816)

    state_flags := cpu_flags(state.p, state.e)
    log.errorf("data: PC %02x:%04x|SP %04x|A %04x|X %04x|Y %04x|DBR %02x|D: %02x|%s|AB %02x:%04x %04x|wrap: %t|fD %t|fM %t",
        state.pbr, state.pc, state.s, state.a, state.x, state.y, state.dbr, state.d, state_flags,
        c.ab.bank, c.ab.addr, c.ab.index, c.ab.wrap, c.f.D, c.f.M)

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


do_test :: proc(p: ^platform.Platform, mode: string, name: string) -> (ok: bool) {
    // raw data

    ok = true
    fname := fmt.aprintf("external/tests-65816/v1/%s.%s.json", name, mode)
    //log.infof("reading file %s ", fname)
    data, status := os.read_entire_file_from_filename(fname)
    if !status {
        log.error("Failed to load the file!")
        ok = false
        return
    }
    defer delete(data)
    defer delete(fname)

    // parsed tests
    //log.info("parsing...")
    tests: [dynamic]CPU_Test
    err := json.unmarshal(data, &tests, .MJSON)             // XXX: memleak here
    if err != nil {
        log.error("Error in json.unmarshal:", err)
        ok = false
        return 
    }
    //fmt.println(tests)
    defer delete(tests)

    // do work
    //log.info("testing...")
    start := time.tick_now() 
    count := 0
    c     := &p.cpu.model.(cpu.CPU_65C816) 
    for test in tests {
        prepare_test(p, test.initial)
        for {
            c->exec(0)
            if (!c.in_mvn) && (!c.in_mvp) do break
        }
        fail := verify_test(p, test.final)
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
    log.infof("mode %s opcode %s tests %d time %i μs", mode, name, count, ms_elapsed)
    return
}

main_loop :: proc(p: ^platform.Platform) -> (err: bool) {

    codes :: [?]string {
        //"a1", "a3", "a5", "a7", "a9", "ad", "af",           // lda
        //"b1", "b2", "b3", "b5", "b7", "b9", "bd", "bf",     // lda
        //"90", "b0", "f0", "30", "d0",                       // bcc, bcs, beq, bmi, bne 
        //"10", "80", "50", "70", "82",                       // bpl, bra, bvc, bvs, brl
        //"a2", "a6", "ae", "b6", "be",                       // ldx 
        //"a0", "a4", "ac", "b4", "bc",                       // ldy
        //"fb"                                                // xce
        //"4c", "5c", "6c", "7c", "dc",                       // jmp
        
        "22", "20", "fc",                                   // jsl, jsr
        "41", "43", "45", "47", "49", "4d", "4f",           // eor
        "51", "52", "53", "55", "57", "59", "5d", "5f",     // eor
        "01", "03", "05", "07", "09", "0d", "0f",           // ora
        "11", "12", "13", "15", "17", "19", "1d", "1f",     // ora
        "21", "23", "25", "27", "29", "2d", "2f",           // and
        "31", "32", "33", "35", "37", "39", "3d", "3f",     // and

        //"06", "0a", "0e", "16", "1e",                       // asl
        //"26", "2a", "2e", "36", "3e",                       // rol
        //"46", "4a", "4e", "56", "5e",                       // lsr
        //"66", "6a", "6e", "76", "7e",                       // ror
        //"1a", "e6", "ee", "f6", "fe", "e8", "c8"            // inc, inx, iny
        //"3a", "36", "ce", "d6", "de", "ca", "88"            // dec, dex, dey
        //"c1", "c3", "c5", "c7", "c9", "cd", "cf",           // cmp
        //"d1", "d2", "d3", "d5", "d7", "d9", "dd", "df",     // cmp
        //"e0", "e4", "ec",                                   // cpx
        //"c0", "c4", "cc"                                    // cpy
        //"18", "d8", "58", "b8", "38", "f8", "78"            // clc, sec etc.
        //"81", "83", "85", "87", "8d", "8f",                 // sta
        //"91", "92", "93", "95", "97", "99", "9d", "9f",     // sta
        //"86", "8e", "96",                                   // stx
        //"84", "8c", "94",                                   // sty
        //"64", "74", "9c", "9e"                              // stz
        //"aa", "a8", "ba", "8a", "9a", "9b", "98", "bb",     // tax, tay etc.
        //"eb",                                               // xba
        //"5b", "1b", "7b", "3b"                              // tcd, tcs, tdc, tsc
        //"48", "da", "5a",                                   // pha, phx, phy
        //"68", "fa", "7a",                                   // pla, plx, ply
        //"8b", "0b", "4b", "08", "ab", "2b", "28"            // phb, phd, phk, php, plb, pld, plp
        //"6b", "60", "40"                                    // rtl, rts, rti
        //"f4", "d4", "62"                                    // pea, pei, per
        //"24", "2c", "34", "3c", "89"                        // bit
        //"00", "02",                                         // brk, cop
        //"ea", "42",                                         // nop, wdm
        //"14", "1c", "04", "0c",                             // trb, tsb
        //"c2", "e2",                                         // rep, sep
        //"db", "cb",                                         // stp, wai
        //"61", "63", "65", "67", "69", "6d", "6f",           // adc
        //"71", "72", "73", "75", "77", "79", "7d", "7f",     // adc
        //"e1", "e3", "e5", "e7", "e9", "ed", "ef",           // sbc
        //"f1", "f2", "f3", "f5", "ff", "f9", "fd", "ff",     // sbc
        //"54",                                               // mvn - broken tests
        //"44",                                               // mvp - broken tests

    }

    for name in codes {
        do_test(p, "e", name) or_break
        do_test(p, "n", name) or_break
    }

    return
}


main :: proc() {
    logger_options := log.Options{.Level};
    context.logger  = log.create_console_logger(opt = logger_options) 

    // init -------------------------------------------------------------
    //log.info("Running...")
    p := platform.test816_make()
    
    // running ----------------------------------------------------------
    main_loop(p)

    // exiting ----------------------------------------------------------
    p->delete()
    //log.info("Exiting...")
    log.destroy_console_logger(context.logger)
    os.exit(0)
}

