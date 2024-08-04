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
import "core:strconv"
import "core:time"

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
        log.errorf("A      %04x expected   %04x", a, state.a)
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


print_state :: proc(state: CPU_State, c: ^cpu.CPU) {
    c    := &c.model.(cpu.CPU_65C816)
    log.errorf("PC %02x:%04x SP %04x A %04x X %04x Y %04x DBR %02x AB %02x:%04x %04x wrap: %t",
        state.pbr, state.pc, state.s, state.a, state.x, state.y, state.dbr, 
        c.ab.bank, c.ab.addr, c.ab.index, c.ab.wrap)
    for mem in state.ram {
        log.errorf("addr: %06x %02x", mem[0], mem[1])
    }
}


main_loop :: proc(p: ^platform.Platform) {

    // raw data
    log.info("reading file...")
    data, ok := os.read_entire_file_from_filename("/home/aniou/a2560x/src/65816/v1/a9.n.json")
    if !ok {
        log.error("Failed to load the file!")
        return
    }
    defer delete(data)

    // parsed tests
    log.info("parsing...")
    tests: [dynamic]CPU_Test
    err := json.unmarshal(data, &tests, .MJSON)             // so, !err or !ok?
    if err != nil {
        log.error("Error in json.unmarshal:", err)
        return
    }
    defer delete(tests)

    // do work
    log.info("testing...")
    count := 0
    for test in tests {
        prepare_test(p, test.initial)
        p.cpu->exec(0)
        fail := verify_test(p, test.final)
        if fail {
            log.error("test: ", test.name)
            print_state(test.initial, p.cpu)
            print_state(test.final, p.cpu)
            break
        }
        count += 1
    }
    log.infof("%d tests passed", count)
    return
}


main :: proc() {
    logger_options := log.Options{.Level};
    context.logger  = log.create_console_logger(opt = logger_options) 

    // init -------------------------------------------------------------
    log.info("Running...")
    p := platform.test816_make()
    
    // running ----------------------------------------------------------
    main_loop(p)

    // exiting ----------------------------------------------------------
    p->delete()
    log.info("Exiting...")
    log.destroy_console_logger(context.logger)
    os.exit(0)
}

