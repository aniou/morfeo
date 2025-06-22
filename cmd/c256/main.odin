package morfeo

import "lib:emu"
import "lib:getargs"
import ini "lib:odin-ini-parser"

import "emulator:platform"
import "emulator:bus"
import "emulator:cpu"
import "emulator:gpu"

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:prof/spall"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:time"

import "vendor:sdl2"

DEFAULT_CFG :: "conf/" + emu.TARGET + ".ini"

read_ini :: proc(file_path: string) -> Maybe(ini.INI) {
    bytes, ok := os.read_entire_file_from_filename(file_path)
    defer delete(bytes)

    if !ok {
        log.errorf("read_ini: could not read %q\n", file_path)
        return nil
    }

    ini, res := ini.parse(bytes)
    using res.pos
    switch res.err {
    case .EOF:              return ini
    case .IllegalToken:     log.errorf("Illegal token encountered in %q at %d:%d", file_path, line+1, col+1)
    case .KeyWithoutEquals: log.errorf("Key token found, but not assigned in %q at %d:%d", file_path, line+1, col+1)
    case .ValueWithoutKey:  log.errorf("Value token found, but not preceeded by a key token in %q at %d:%d", file_path, line+1, col+1)
    case .UnexpectedEquals: log.errorf("Equals sign found in an unexpected location in %q at %d:%d", file_path, line+1, col+1)
    }

    return nil
}

parse_ini :: proc(c: ^emu.Config, file_path: string) {
    iniconf, ok := read_ini(file_path).?
    defer ini.ini_delete(&iniconf)
    if !ok {
        return
    }
    
    // ---------------------------------------------------------------------------------------------
    // warning: DIPs have "inverted" logic - physical OFF means logical "1"
    //
    if "platform" in iniconf {
        keys := make([dynamic]string, 0)
        for key in iniconf["platform"] {
            append(&keys, key)
        }
        slice.sort(keys[:])
        for key in keys {
            switch strings.to_lower(key) {
            case "dip1" : c.dip &= 0xFE if strings.to_lower(iniconf["platform"][key]) == "on" else 0
            case "dip2" : c.dip &= 0xFD if strings.to_lower(iniconf["platform"][key]) == "on" else 0
            case "dip3" : c.dip &= 0xEF if strings.to_lower(iniconf["platform"][key]) == "on" else 0 // yes, in that order
            case "dip4" : c.dip &= 0xF7 if strings.to_lower(iniconf["platform"][key]) == "on" else 0 // yes, in that order
            case "dip5" : c.dip &= 0xFB if strings.to_lower(iniconf["platform"][key]) == "on" else 0 // yes, in that order
            case "dip6" : c.dip &= 0xDF if strings.to_lower(iniconf["platform"][key]) == "on" else 0
            case "dip7" : c.dip &= 0xBF if strings.to_lower(iniconf["platform"][key]) == "on" else 0
            case "dip8" : c.dip &= 0x7F if strings.to_lower(iniconf["platform"][key]) == "on" else 0
            case "disk0": c.disk0 = strings.clone(iniconf["platform"][key])
            case "disk1": c.disk1 = strings.clone(iniconf["platform"][key])
            case:
                if strings.has_prefix(key, "file") {
                    append(&c.files, strings.clone(iniconf["platform"][key]))
                }
            }
        }
        delete(keys)
        log.debugf("CONFIG: DIP value is %02x", c.dip)
    }

    // ---------------------------------------------------------------------------------------------
    if "gui" in iniconf {
        if "scale" in iniconf["gui"] {
            c.gui_scale, ok = strconv.parse_int(iniconf["gui"]["scale"])
        }
        if !ok {
            log.errorf("invalid gui/scale parameter: %s", iniconf["gui"]["scale"])
            c.gui_scale = 0
        }
    }


    return
}

read_args :: proc() -> (c: ^emu.Config, args_ok: bool = true) {
    payload: string
    ok:      bool

    c       = new(emu.Config)
    c.dip   = 0xFF              // 'off' physical switch means 0 in logical bits

    argp := getargs.make_getargs()
    getargs.add_arg(&argp, "d",     "disasm",  .None)
    getargs.add_arg(&argp, "b",     "busdump", .None)
    getargs.add_arg(&argp, "cfg",   "",        .Required)
    getargs.add_arg(&argp, "dip1",  "",        .Required)
    getargs.add_arg(&argp, "dip2",  "",        .Required)
    getargs.add_arg(&argp, "dip3",  "",        .Required)
    getargs.add_arg(&argp, "dip4",  "",        .Required)
    getargs.add_arg(&argp, "dip5",  "",        .Required)
    getargs.add_arg(&argp, "dip6",  "",        .Required)
    getargs.add_arg(&argp, "dip7",  "",        .Required)
    getargs.add_arg(&argp, "dip8",  "",        .Required)
    getargs.add_arg(&argp, "disk0", "",        .Required)
    getargs.add_arg(&argp, "scale", "",        .Required)
    getargs.add_arg(&argp, "h",     "help",    .None)

    getargs.read_args(&argp, os.args)

    if getargs.get_flag(&argp, "h") {
        args_ok = false
        fmt.printf("\nUsage: %s [-d] [-b] [--cfg filename.ini] file1.hex [file2.hex]\n", emu.TARGET)
        return
    }

    // ini file is loaded at very beginning...
    payload, ok = getargs.get_payload(&argp, "cfg")
    if ok {
        parse_ini(c, payload)
    } else {
        parse_ini(c, DEFAULT_CFG)
    }

    // set GUI scaling to sane(?) default value
    if c.gui_scale == 0 do c.gui_scale = 2

    // ...and particular settings are overrided by cli switches
    c.disasm  = getargs.get_flag(&argp, "d")    // XXX not in ini yet
    c.busdump = getargs.get_flag(&argp, "b")    // XXX not in ini yer

    payload, ok = getargs.get_payload(&argp, "disk0")
    if ok {
        c.disk0 = payload
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
    switch_busdump  := false

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

        // XXX why return when I have access to GUI? insane...
        if switch_disasm {
            c.debug = false if c.debug else true
            gui.switch_disasm = false
        }

        if gui.switch_busdump {
            p.bus.debug = false if p.bus.debug else true
            gui.switch_busdump = false
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
        log.info(f)
        ok = platform.read_intel_hex(p.bus, p.cpu, f)
        if !ok {
            log.errorf("Cannot load hex file %s", f)
            p->delete()
            free(config)
            os.exit(1)
        }
    }
    
    // init graphics ----------------------------------------------------
    init_sdl(p, config)
    
    // running ----------------------------------------------------------
    main_loop(p, config)

    // exiting ----------------------------------------------------------
    cleanup_sdl()
    p->delete()
    free(config)
    os.exit(0)
}

