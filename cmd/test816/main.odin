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

    //p.cpu->reset()
    p.cpu->exec(0)
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

