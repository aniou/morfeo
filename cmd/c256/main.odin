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
    log.infof("config: reading config file %s", file_path)
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

// set dip value according to key/val 
parse_dip :: proc(c: ^emu.Config, key, val: string) {

    lower_val := strings.to_lower(val)
    switch lower_val {
    case "n", "0", "off", "no",  "false": 
        switch key {
        case "dip1": c.dipoff += {.DIP1}
        case "dip2": c.dipoff += {.DIP2}
        case "dip3": c.dipoff += {.DIP3}
        case "dip4": c.dipoff += {.DIP4}
        case "dip5": c.dipoff += {.DIP5}
        case "dip6": c.dipoff += {.DIP6}
        case "dip7": c.dipoff += {.DIP7}
        case "dip8": c.dipoff += {.DIP8}
        case       : log.errorf("config: unknown DIP: %s", key)
        }
    case "y", "1", "on",  "yes", "true" : 
        switch key {
        case "dip1": c.dipoff -= {.DIP1}
        case "dip2": c.dipoff -= {.DIP2}
        case "dip3": c.dipoff -= {.DIP3}
        case "dip4": c.dipoff -= {.DIP4}
        case "dip5": c.dipoff -= {.DIP5}
        case "dip6": c.dipoff -= {.DIP6}
        case "dip7": c.dipoff -= {.DIP7}
        case "dip8": c.dipoff -= {.DIP8}
        case       : log.errorf("config: unknown DIP: %s", key)
        }
    }
    delete(lower_val)
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
        for k in keys {
            val := strings.clone(iniconf["platform"][k])
            key := strings.to_lower(k)

            switch {
            case strings.has_prefix(key, "file"): append(&c.files, val)
            case strings.has_prefix(key, "dip") : parse_dip(c, key, val)
                                                  delete(val)
            case key == "disk0"                 : c.disk0 = val
            case key == "disk1"                 : c.disk0 = val
            }
            delete(key)
        }
        delete(keys)
        log.debugf("config: DIP enabled is %v", ~c.dipoff)
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

    // ---------------------------------------------------------------------------------------------
    command : emu.CMD
    valid   : bool

    if "key" in iniconf {
        for k in iniconf["key"] {
            kname   := strings.clone(k)
            cmdsets := strings.split(iniconf["key"][kname], ";")
            for cmds in cmdsets {
                valid = true
                cmd := strings.split(strings.trim(cmds, " "), " ")
                switch cmd[0] {
                case "quit"          : command = .QUIT
                case "load"          : command = .LOAD
                case "reset"         : command = .RESET
                case "toggle_gpu"    : command = .TOGGLE_GPU
                case "toggle_busdump": command = .TOGGLE_BUSDUMP
                case "toggle_disasm" : command = .TOGGLE_DISASM
                case                 : log.errorf("%s key %s : unknown command %s", #procedure, kname, cmd[0])
                                       valid = false
                }
                if kname not_in c.key {
                    c.key[kname] = make([dynamic]emu.Command)
                }
                
                params := make([dynamic]string)
                for param in cmd[1:] {
                    append(&params, strings.clone(param))
                }
                append(&c.key[kname], emu.Command{command, params})
                delete(cmd)
            }
            delete(cmdsets)

            if !valid {
                delete_key(&c.key, kname)
                delete(kname)
            }
        }
    }

    log.debugf("%s %v", #procedure, c)
    return
}

read_args :: proc() -> (c: ^emu.Config, args_ok: bool = true) {
    payload: string
    ok:      bool

    c        = new(emu.Config)
    c.dipoff = {.DIP1, .DIP2, .DIP3, .DIP4, .DIP5, .DIP6, .DIP7, .DIP8}

    argp := getargs.make_getargs()
    getargs.add_arg(&argp, "d",     "disasm",  .None)
    getargs.add_arg(&argp, "b",     "busdump", .None)
    getargs.add_arg(&argp, "n",     "nocfg",   .None)
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
    getargs.add_arg(&argp, "disk1", "",        .Required)
    getargs.add_arg(&argp, "scale", "",        .Required)
    getargs.add_arg(&argp, "h",     "help",    .None)

    getargs.read_args(&argp, os.args)

    if getargs.get_flag(&argp, "h") {
        args_ok = false
        fmt.printf("\nUsage: %s [-d] [-b] [-n] [--cfg filename.ini] [--dipX on] file1.hex [file2.hex]\n", emu.TARGET)
        return
    }

    // flag '-n' means 'no config'
    if !getargs.get_flag(&argp, "n") {
        // ini file is loaded at very beginning...
        payload, ok = getargs.get_payload(&argp, "cfg")
        if ok {
            parse_ini(c, payload)
        } else {
            parse_ini(c, DEFAULT_CFG)
        }
    }

    // set GUI scaling to sane(?) default value
    if c.gui_scale == 0 do c.gui_scale = 2

    // ...and particular settings are overrided by cli switches
    c.disasm  = getargs.get_flag(&argp, "d")    // XXX not in ini yet
    c.busdump = getargs.get_flag(&argp, "b")    // XXX not in ini yer

    // disks
    payload, ok = getargs.get_payload(&argp, "disk0")
    if ok {
        c.disk0 = payload
    }

    payload, ok = getargs.get_payload(&argp, "disk1")
    if ok {
        c.disk1 = payload
    }

    // dest for dip-switches from CLI
    dipnames :: [?]string{"dip1", "dip2", "dip3", "dip4", "dip5", "dip6", "dip7", "dip8"} 
    for dip in dipnames {
        payload, ok = getargs.get_payload(&argp, dip)
        if !ok {
            continue
        }
        parse_dip(c, dip, payload)   
    }


    // files to load (kernels, interpreters - loaded in order)
    for ; argp.arg_idx < len(os.args) ; argp.arg_idx += 1 {
        append(&c.files, os.args[argp.arg_idx])
    }

    getargs.destroy(&argp)
    //args_ok = false
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

        if gui.reset {
            p.cpu->reset()
            gui.reset = false
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

cleanup_config :: proc(config: ^emu.Configuration) {
    for k in config.key {
        for cmd in config.key[k] {
            for param in cmd.params {
                delete(param)
            }
            delete(cmd.params)
        }
        delete(config.key[k])
        delete(k)
    }
    delete(config.key)
    delete(config.disk0)
    delete(config.disk1)
    for f in config.files {
        delete(f)
    }
    delete(config.files)
    free(config)
}


main :: proc() {
    logger_options := log.Options{.Level};
    context.logger  = log.create_console_logger(opt = logger_options) 

    // init -------------------------------------------------------------
    config, ok := read_args()
    log.debugf("%s %v", #procedure, config)
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
    // last parameter denotes where is a "flash" code located, in
    // FoenixIDE that bank ($18:0000 or $38:) is moved to $00:0000
    for f in config.files {
        log.info(f)
        ok = platform.read_intel_hex(p.bus, p.cpu, f, emu.FLASHSRC)
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
    cleanup_config(config)

    os.exit(0)
}

