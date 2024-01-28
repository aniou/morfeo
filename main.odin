package morfeo

TARGET :: #config(TARGET, "a2560x")

import "lib:emu"
import "lib:getargs"

import "emulator:platform"
import "emulator:bus"
import "emulator:cpu"
import "emulator:gpu"

import "core:fmt"
import "core:log"
import "core:os"
import "core:prof/spall"
import "core:runtime"
import "core:strconv"
import "core:time"

import "vendor:sdl2"

Config :: struct {
    disk0:  string,             // XXX: todo
    disk1:  string,             // XXX: todo
    gpu_id: int,
    files:  [dynamic]string,    // XXX: todo
}


show_cpu_speed :: proc(cycles: u32) -> (u32, string) {
        switch {
        case cycles > 1000000:
                return cycles / 1000000, "MHz"
        case cycles > 1000:
                return cycles / 100, "kHz"
        case:
                return cycles, "Hz"
        }
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
    debug_ticks     := sdl2.GetTicks()
    ticks           := debug_ticks       // overkill for 1ms precision?
    current_ticks   := debug_ticks       // helper variable for time calc
    CPU_SPEED       := u32(33000)
    desired_cycles  := CPU_SPEED
    gui.should_close = false
    g               := p.bus.gpu0 if gui.current_gpu == 0 else p.bus.gpu1
    sdl2.SetWindowTitle(gui.window, fmt.ctprintf("morfeo: gpu%d", gui.current_gpu))

    p.cpu->reset()
    for !gui.should_close {

        // Step 1: execute CPU and measure delays
        //
        current_ticks = sdl2.GetTicks()
        if current_ticks > ticks {
            ms_elapsed := current_ticks - ticks
            ticks = current_ticks
            if ms_elapsed < 5 {
                desired_cycles = ms_elapsed * CPU_SPEED
            } else {
                desired_cycles =          5 * CPU_SPEED
            }
            p.cpu->exec(desired_cycles)
        }

        // Step 2: process keyboard in (XXX: do it - mouse)
        //
        process_input(p)

        // Step 2a: handle GPU switching
        if gui.switch_gpu {
            gui.current_gpu = 1          if gui.current_gpu == 0 else 0
            g               = p.bus.gpu0 if gui.current_gpu == 0 else p.bus.gpu1
            gui.switch_gpu  = false
            g.screen_resized = true
            sdl2.SetWindowTitle(gui.window, fmt.ctprintf("morfeo: gpu%d", gui.current_gpu))
        }

        // Step 3: handle screen resize
        //
		if g.screen_resized {
				gui.x_size = g.screen_x_size
				gui.y_size = g.screen_y_size
				g.screen_resized = false
				update_window_size()
		}

        // Step 4: call active GPU to render things
        //         XXX: frames should be ticked at Start Of Frame, thus on ->render 
        g->render()

        current_ticks = sdl2.GetTicks()
        if current_ticks >  p.bus.gpu0.last_tick + p.bus.gpu0.delay {
            p.bus.gpu0.frames += 1
            p.bus.gpu0.last_tick = current_ticks
        }

        if current_ticks >  p.bus.gpu1.last_tick + p.bus.gpu1.delay {
            p.bus.gpu1.frames += 1
            p.bus.gpu1.last_tick = current_ticks
        }

        // Step 5 : draw to screen
        //

        // Step 5a: background
        //
		sdl2.SetRenderDrawColor(gui.renderer, g.bg_color_r, g.bg_color_g, g.bg_color_b, sdl2.ALPHA_OPAQUE)
        sdl2.RenderClear(gui.renderer)

        // Step 5b: bitmap 0 and 1
        //
		if g.bitmap_enabled & g.graphic_enabled {
		    if g.bm0_enabled {
                sdl2.UpdateTexture(gui.texture_bm0, nil, g.BM0FB, gui.x_size*4)
                sdl2.RenderCopy(gui.renderer, gui.texture_bm0, nil, nil)
			}
		    if g.bm1_enabled {
                sdl2.UpdateTexture(gui.texture_bm1, nil, g.BM1FB, gui.x_size*4)
                sdl2.RenderCopy(gui.renderer, gui.texture_bm1, nil, nil)
			}
		}

        // Step 5c: text
        //
        if g.text_enabled {
            sdl2.UpdateTexture(gui.texture_txt, nil, g.TFB, gui.x_size*4)
            sdl2.RenderCopy(gui.renderer, gui.texture_txt, nil, nil)
        }

        // Step 5d: border
        //
		if g.border_enabled do draw_border(g)

        // Step  6: present to screen
        sdl2.RenderPresent(gui.renderer)


        // Step  7: print some information
        loops += 1
        if sdl2.GetTicks() - debug_ticks > 1000 {
            debug_ticks  = sdl2.GetTicks()
            speed, unit := show_cpu_speed(p.cpu.cycles)
            log.debugf("loops %d cpu cycles %d speed %d %s", loops, p.cpu.cycles, speed, unit)

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
    when TARGET == "a2560x" {
        p := platform.a2560x_make()
    } else {
        #panic("Unknown TARGET")
    }

    config, ok := read_args(p)
    if !ok do os.exit(1)

    init_sdl(config.gpu_id)
    
    // running ----------------------------------------------------------
    main_loop(p)

    // exiting ----------------------------------------------------------
    cleanup_sdl()
    p->delete()
    free(config)
    os.exit(0)
}

