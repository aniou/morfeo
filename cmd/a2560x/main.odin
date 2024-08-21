package morfeo

TARGET :: #config(TARGET, "a2560x")

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

Config :: struct {
    disk0:  string,             // XXX: todo
    disk1:  string,             // XXX: todo
    gpu_id: int,
    files:  [dynamic]string,    // XXX: todo
}


read_args :: proc(p: ^platform.Platform) -> (c: ^Config, args_ok: bool = true) {
    payload: string
    ok:      bool

    c = new(Config)
    argp := getargs.make_getargs()
    getargs.add_arg(&argp, "disk0", "",       .Optional)
    getargs.add_arg(&argp, "gpu",   "",       .Optional)
    getargs.add_arg(&argp, "h",     "help",   .None)

    getargs.read_args(&argp, os.args)

    if ((len(os.args) == 1) || (getargs.get_flag(&argp, "h"))) {
        args_ok = false
        fmt.printf("\nUsage: morfeo [--gpu=0 or 1] [--disk0 path-to-image] file1.hex [file2.hex]\n")
        return
    }

    // GPU number
    payload      = getargs.get_payload(&argp, "gpu") or_else "1"
    c.gpu_id, ok = strconv.parse_int(payload)
    if !ok {
        log.errorf("Invalid gpu number (should be 0 or 1)")
        args_ok  = false
        c.gpu_id = 1
    }

    // disk0 attach - XXX maybe should be moved to outside?
    payload, ok = getargs.get_payload(&argp, "disk0")
    if ok {
        ok = p.bus.ata0->attach(0, payload)
        if !ok {
            args_ok = false
        }
    }

    // files to load - XXX maybe should be moved to outside?
    for ; argp.arg_idx < len(os.args) ; argp.arg_idx += 1 {
        platform.read_intel_hex(p.bus, p.cpu, os.args[argp.arg_idx])
    }

    getargs.destroy(&argp)
    return
}

main_loop :: proc(p: ^platform.Platform) {

    loops           := u32(0)
    ms_elapsed      := u32(0)
    cpu_ticks       := time.tick_now()      // CPU timer
    debug_ticks     := time.tick_now()      // counter for general emulator timer
    CPU_SPEED       := u32(33000)
    desired_cycles  := CPU_SPEED
    should_close    := false

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
        should_close = render_gui(p)

        // Step  3: print some information
        loops += 1
        if time.tick_since(debug_ticks) > time.Second {
            debug_ticks  = time.tick_now()
            speed, unit := emu.show_cpu_speed(p.cpu.cycles)
            log.debugf("loops %d cpu cycles %d speed %d %s ms_elapsed %d desired_cycles %d",
                            loops,
                            p.cpu.cycles,
                            speed,
                            unit,
                            ms_elapsed,
                            desired_cycles
            )

            loops        = 0
            p.cpu.cycles = 0
        }
    }
    return
}


main :: proc() {
    logger_options := log.Options{.Level};
    context.logger  = log.create_console_logger(opt = logger_options) 

    // init -------------------------------------------------------------
    p := platform.a2560x_make()

    config, ok := read_args(p)
    if !ok do os.exit(1)

    init_sdl(p, config.gpu_id)
    
    // running ----------------------------------------------------------
    main_loop(p)

    // exiting ----------------------------------------------------------
    cleanup_sdl()
    p->delete()
    free(config)
    os.exit(0)
}

