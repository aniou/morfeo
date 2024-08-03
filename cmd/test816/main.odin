package test816

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
            p.cpu->exec(desired_cycles)
        }

        // Step 2: process keyboard in (XXX: do it - mouse)
        //should_close = render_gui(p)

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
            should_close = true
        }
    }
    return
}


main :: proc() {
    logger_options := log.Options{.Level};
    context.logger  = log.create_console_logger(opt = logger_options) 

    // init -------------------------------------------------------------
    p := platform.test816_make()
    
    // running ----------------------------------------------------------
    main_loop(p)

    // exiting ----------------------------------------------------------
    p->delete()
    log.info("Exiting...")
    log.destroy_console_logger(context.logger)
    os.exit(0)
}

