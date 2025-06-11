package morfeo

import "lib:emu"
import "lib:getargs"

import "emulator:platform"
import "emulator:bus"
import "emulator:cpu"
import "emulator:gpu"

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:prof/spall"
import "core:strconv"
import "core:time"

import "vendor:sdl2"

read_args :: proc() -> (c: ^emu.Config, args_ok: bool = true) {
    payload: string
    ok:      bool

    c = new(emu.Config)
    argp := getargs.make_getargs()
    getargs.add_arg(&argp, "d",     "disasm",  .None)
    getargs.add_arg(&argp, "b",     "busdump", .None)
    getargs.add_arg(&argp, "model", "",        .Required)
    getargs.add_arg(&argp, "dip",   "",        .Required)
    getargs.add_arg(&argp, "disk0", "",        .Required)
    getargs.add_arg(&argp, "gpu",   "",        .Required)
    getargs.add_arg(&argp, "h",     "help",    .None)

    getargs.read_args(&argp, os.args)

    if ((len(os.args) == 1) || (getargs.get_flag(&argp, "h"))) {
        args_ok = false
        fmt.printf("\nUsage: morfeo [-d] [-b] [--model fmx|u|u+] [--dip ...] [--gpu=0 or 1] [--disk0 path-to-image] file1.hex [file2.hex]\n")
        return
    }

    c.disasm  = getargs.get_flag(&argp, "d") 
    c.busdump = getargs.get_flag(&argp, "b")

    // GPU number
    payload      = getargs.get_payload(&argp, "gpu") or_else "0"
    c.gpu_id, ok = strconv.parse_int(payload)
    if !ok {
        log.errorf("Invalid gpu number (should be 0 or 1)")
        args_ok  = false
        c.gpu_id = 0
    }

    payload = getargs.get_payload(&argp, "model") or_else "fmx"
    switch payload {
        case "fmx": c.model = .C256FMX
        case "u"  : c.model = .C256U
        case "u+" : c.model = .C256UPLUS
        case      : log.errorf("Unknown model %s, should be fmx, u or u+)", payload)
                    args_ok = false
    }

    payload, ok = getargs.get_payload(&argp, "disk0")
    if ok {
        c.disk0 = payload
    }

    payload, ok = getargs.get_payload(&argp, "dip")
    if ok {
        for character in payload {
            switch character {
                case '1': c.dip |= 0x01
                case '2': c.dip |= 0x02
                case '3': c.dip |= 0x04
                case '4': c.dip |= 0x08
                case '5': c.dip |= 0x10
                case '6': c.dip |= 0x20
                case '7': c.dip |= 0x40
                case '8': c.dip |= 0x80
                case    : log.errorf("DIP enable should be a number 1 to 8, got %v", character)
                          args_ok = false
            }
        }
    }
    // files to load (kernels, interpreters - loaded in order)
    for ; argp.arg_idx < len(os.args) ; argp.arg_idx += 1 {
        append(&c.files, os.args[argp.arg_idx])
    }

    getargs.destroy(&argp)
    return 
}


main_loop :: proc(p: ^platform.Platform, config: ^emu.Config,) {

    loops           := u32(0)
    ms_elapsed      := u32(0)
    cpu_ticks       := time.tick_now()      // CPU timer
    debug_ticks     := time.tick_now()      // counter for general emulator timer
    CPU_SPEED       := u32(14000)
    desired_cycles  := CPU_SPEED
    should_close    := false
    switch_disasm   := false

    c       := &p.cpu.model.(cpu.CPU_65xxx)
    c.debug  = config.disasm
    p.bus.debug = config.busdump

    p->init()
    p.cpu->reset()
    for !should_close {

        // Step 1: execute CPU and measure delays
        // XXX: move cpu_ticks into cpu's own structure, like for GPU
        // XXX: that algorithm is terrible, do the proper math...
        //      btw: typical delay on current imp. is abou 1800 micros.
        ms_elapsed = u32(time.tick_since(cpu_ticks) / time.Microsecond)
        if ms_elapsed >= 500 {
            cpu_ticks = time.tick_now()

            if ms_elapsed < 1500 {
                desired_cycles = CPU_SPEED
            } else {
                desired_cycles = 2 * CPU_SPEED
            }
            p.cpu->run(desired_cycles)
        }

        // Step 2: process keyboard in (XXX: do it - mouse)
        should_close, switch_disasm = render_gui(p)

        if switch_disasm {
            c.debug = false if c.debug else true
            gui.switch_disasm = false
        }

        // Step  3: print some information
        loops += 1
        if time.tick_since(debug_ticks) > time.Second {
            debug_ticks  = time.tick_now()
            speed, unit := emu.show_cpu_speed(p.cpu.all_cycles)
            log.debugf("loops %d cpu cycles %d speed %d %s ms_elapsed %d desired_cycles %d",
                            loops,
                            p.cpu.all_cycles,
                            speed,
                            unit,
                            ms_elapsed,
                            desired_cycles
            )

            loops        = 0
            p.cpu.all_cycles = 0
        }
    }
    return
}


main :: proc() {
    logger_options := log.Options{.Level};
    context.logger  = log.create_console_logger(opt = logger_options) 

    // init -------------------------------------------------------------
    config, ok := read_args()
    if !ok {
        free(config)
        os.exit(1)
    }

    // create and configure platform ------------------------------------
    p : ^platform.Platform
    p, ok  = platform.c256_make(config)
    if !ok {
        free(config)
        os.exit(1)
    }

    // ...disk images to attach
    if config.disk0 != "" {
        ok = p.bus.ata0->attach(0, config.disk0)
        if !ok {
            log.errorf("Cannot attach disk0 from file %s", config.disk0)
            p->delete()
            free(config)
            os.exit(1)
        }
    }

    // ...program files to load 
    for f in config.files {
        ok = platform.read_intel_hex(p.bus, p.cpu, f)
        if !ok {
            log.errorf("Cannot load hex file %s", f)
            p->delete()
            free(config)
            os.exit(1)
        }
    }
    
    // init graphics ----------------------------------------------------
    init_sdl(p, config.gpu_id)
    
    // running ----------------------------------------------------------
    main_loop(p, config)

    // exiting ----------------------------------------------------------
    cleanup_sdl()
    p->delete()
    free(config)
    os.exit(0)
}

