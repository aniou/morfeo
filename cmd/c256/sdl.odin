
package morfeo

import "core:fmt"
import "core:log"
import "core:time"

import "vendor:sdl2"
import "emulator:gpu"
import "emulator:platform"
import "emulator:joy"

import "lib:emu"


GUI :: struct {
    window:        ^sdl2.Window,
    renderer:      ^sdl2.Renderer,
    texture_txt:   ^sdl2.Texture,
    texture_bm0:   ^sdl2.Texture,
    texture_bm1:   ^sdl2.Texture,
    texture_mouse: ^sdl2.Texture,

    mouse_rectangle: sdl2.Rect,         // rectangle for mouse cursor definition

    orig_mode:   ^sdl2.DisplayMode,     // for return from fullscreen

    fullscreen:  bool,
    scale_mult:  i32,                   // scale factor, 1 or 2
    x_size:      i32,                   // emulated x screen size
    y_size:      i32,                   // emulated y screen size
    mouse_x:     i32,                   // X mouse cursor (SDL, that means * scale_mult)
    mouse_y:     i32,                   // Y mouse cursor (SDL, that means * scale_mult)

    active_gpu:  u8,                    // GPU number

    switch_disasm:  bool,
    switch_busdump: bool,
    should_close:   bool,
    switch_gpu:     bool,
    reset:          bool,
    current_gpu:    int,
    g:             ^gpu.GPU,             // currently active GPU
    gpu0:          ^gpu.GPU,             // first GPU
    gpu1:          ^gpu.GPU,             // second GPU
}

gui: GUI

create_texture :: proc(x_size, y_size: i32) -> ^sdl2.Texture {
    texture := sdl2.CreateTexture(
               gui.renderer,
               sdl2.PixelFormatEnum.ARGB8888,
               sdl2.TextureAccess.STREAMING, 
               x_size, 
               y_size
    )
    if texture == nil {
        error := sdl2.GetError()
        log.errorf("sdl2.CreateTexture failed: %s", error)
        return nil
    }
    err := sdl2.SetTextureBlendMode(texture, sdl2.BlendMode.BLEND)
    if err != 0 {
        error := sdl2.GetError()
        log.errorf("sdl2.SetTextureBlendMode failed: %s", error)
    }
    return texture
}

init_sdl :: proc(p: ^platform.Platform, config: ^emu.Config) -> (ok: bool) {
    gui = GUI{}

    gui.gpu0        = p.bus.gpu0  // first GPU
    gui.gpu1        = p.bus.gpu1  // second
    gui.g           = p.bus.gpu0  // current active GPU
    gui.current_gpu = 0

    gui.x_size      = gui.g.screen_x_size    // at this moment GPU is already initialised
    gui.y_size      = gui.g.screen_y_size
    gui.scale_mult  = i32(config.gui_scale)
    gui.fullscreen  = false
    gui.mouse_x     = 32 * gui.scale_mult
    gui.mouse_y     = 32 * gui.scale_mult

    // init
    if sdl_res := sdl2.Init(sdl2.INIT_EVERYTHING); sdl_res < 0 {
        log.errorf("sdl2.init returned %v.", sdl_res)
        return false
    }

    // windows
    gui.window = sdl2.CreateWindow(
                 fmt.ctprintf("morfeo (%s): gpu%d", emu.TARGET, gui.current_gpu),
                 sdl2.WINDOWPOS_UNDEFINED, 
                 sdl2.WINDOWPOS_UNDEFINED, 
                 gui.x_size * gui.scale_mult, 
                 gui.y_size * gui.scale_mult,
                 sdl2.WINDOW_SHOWN
                 //sdl2.WINDOW_SHOWN|sdl2.WINDOW_OPENGL
    )
    if gui.window == nil {
        log.errorf("sdl2.CreateWindow failed.")
        return false
    }

    // preserve original resolution
    display_index := sdl2.GetWindowDisplayIndex(gui.window)

    gui.orig_mode = new(sdl2.DisplayMode)
    if sdl_res := sdl2.GetCurrentDisplayMode(display_index, gui.orig_mode); sdl_res < 0 {
        log.errorf("sdl2.GetCurrentDisplayMode returned %v.", sdl_res)
        return false
    }

    // single instance, should be recalculated if scale_mult changes
    gui.mouse_rectangle = sdl2.Rect{gui.mouse_x, gui.mouse_y, 16 * gui.scale_mult, 16 * gui.scale_mult}

    ok = new_renderer_and_texture()
    return ok
}

new_renderer_and_texture :: proc() -> (ok: bool) {
    gui.renderer = sdl2.CreateRenderer(gui.window, -1, {.ACCELERATED})
    if gui.renderer == nil {
        log.errorf("sdl2.CreateRenderer failed.")
        return false
    }

    gui.texture_txt   = create_texture(gui.x_size, gui.y_size)
    gui.texture_bm0   = create_texture(gui.x_size, gui.y_size)
    gui.texture_bm1   = create_texture(gui.x_size, gui.y_size)
    gui.texture_mouse = create_texture(16,16)
    gui.g.pointer_updated = true // force re-create texture for mouse pointer

    // XXX workaround - I don't get that
    sdl2.SetTextureBlendMode(gui.texture_bm0, sdl2.BlendMode.NONE)

    sdl2.SetHint("SDL_HINT_RENDER_BATCHING", "1")

    sdl2.ShowCursor(0)
    
    return true
}

update_window_size :: proc() {
    scale: i32

    // exit from fullscreen if necessary
    if gui.fullscreen {
            //gui.window.SetDisplayMode(orig_mode)
            //gui.window.SetFullscreen(0)
            scale = 1                       // we do not scale in fullscreen
    } else {
            scale = gui.scale_mult
    }

    sdl2.DestroyRenderer(gui.renderer)
    sdl2.DestroyTexture(gui.texture_txt)
    sdl2.DestroyTexture(gui.texture_bm0)
    sdl2.DestroyTexture(gui.texture_bm1)
    sdl2.DestroyTexture(gui.texture_mouse)

    sdl2.SetWindowSize(gui.window, gui.x_size * scale, gui.y_size * scale)

    _ = new_renderer_and_texture()

    // return to fullscreen if necessary
    /*
    if gui.fullscreen {
            sdl.SetWindowFullscreen(gui.window)
    }
    */
}

// XXX - move scaling code into gpu recalculate window to avoid unneccessary multiplication
draw_border :: proc(g: ^gpu.GPU) {
    sdl2.SetRenderDrawColor(gui.renderer, g.border_color_r, g.border_color_g, g.border_color_b, sdl2.ALPHA_OPAQUE)
    if gui.fullscreen {
        x := [?]sdl2.Rect {
                    sdl2.Rect{0, 
                              0, 
                              gui.x_size, 
                              g.border_y_size},

                    sdl2.Rect{0, 
                              gui.y_size - g.border_y_size, 
                              gui.x_size, 
                              g.border_y_size},

                    sdl2.Rect{0, 
                              g.border_y_size,  
                              g.border_x_size, 
                              gui.y_size - g.border_y_size},

                    sdl2.Rect{gui.x_size - g.border_x_size, 
                              g.border_y_size, 
                              g.border_x_size, 
                              gui.y_size - g.border_y_size}
                }
        sdl2.RenderFillRects(gui.renderer, raw_data(x[:]), 4)

    } else {
        x :=  [?]sdl2.Rect{
                    sdl2.Rect{0, 
                              0, 
                              gui.x_size                   * gui.scale_mult, 
                              g.border_y_size              * gui.scale_mult},

                    sdl2.Rect{0, 
                              (gui.y_size-g.border_y_size) * gui.scale_mult, 
                              gui.x_size                   * gui.scale_mult, 
                              g.border_y_size              * gui.scale_mult},

                    sdl2.Rect{0,
                              g.border_y_size              * gui.scale_mult,  
                              g.border_x_size              * gui.scale_mult, 
                              (gui.y_size-g.border_y_size) * gui.scale_mult},

                    sdl2.Rect{(gui.x_size-g.border_x_size) * gui.scale_mult, 
                              g.border_y_size              * gui.scale_mult, 
                              g.border_x_size              * gui.scale_mult, 
                              (gui.y_size-g.border_y_size) * gui.scale_mult}
                }
        sdl2.RenderFillRects(gui.renderer, raw_data(x[:]), 4)
    }
    return
}

cleanup_sdl :: proc() {
        sdl2.DestroyWindow(gui.window)
        sdl2.DestroyRenderer(gui.renderer)
        sdl2.DestroyTexture(gui.texture_txt)
        sdl2.DestroyTexture(gui.texture_bm0)
        sdl2.DestroyTexture(gui.texture_bm1)
        sdl2.QuitSubSystem(sdl2.INIT_EVERYTHING)
        sdl2.Quit()
}

call_command :: proc(p: ^platform.Platform, k: string) -> (pass: bool = true) {
    if k not_in p.cfg.key {
        return  // do nothing, pass key to emulator
    }

 	for cmd in p.cfg.key[k] {
        switch cmd.command {
        case .QUIT : 
            gui.should_close = true
        case .RESET: 
            p.cpu->reset()
        case .LOAD : 
            for fname in cmd.params do platform.read_intel_hex(p.bus, p.cpu, fname, emu.FLASHSRC)
        case .TOGGLE_GPU:
            gui.switch_gpu = true
        case .TOGGLE_BUSDUMP:
            gui.switch_busdump = true
        case .TOGGLE_DISASM:
            gui.switch_disasm = true
        }
	}
    return
}

process_input :: proc(p: ^platform.Platform) {
    e: sdl2.Event

    for sdl2.PollEvent(&e) {
        #partial switch(e.type) {
        case .MOUSEMOTION:
            //log.debugf("SDL: mouse_motion x: %d y: %d", e.motion.x, e.motion.y)
            gui.mouse_x = e.motion.x
            gui.mouse_y = e.motion.y
        case .QUIT:
            gui.should_close = true
        case .KEYDOWN:
            #partial switch(e.key.keysym.sym) {
			case .F1 : if pass := call_command(p, "f1");  pass do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F2 : if pass := call_command(p, "f2");  pass do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F3 : if pass := call_command(p, "f3");  pass do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F4 : if pass := call_command(p, "f4");  pass do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F5 : if pass := call_command(p, "f5");  pass do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F6 : if pass := call_command(p, "f6");  pass do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F7 : if pass := call_command(p, "f7");  pass do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F8 : if pass := call_command(p, "f8");  pass do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F9 : if pass := call_command(p, "f9");  pass do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F10: if pass := call_command(p, "f10"); pass do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F11: if pass := call_command(p, "f11"); pass do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F12: if pass := call_command(p, "f12"); pass do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			/*
            case .F12:
                gui.should_close = true
            case .F11:
                gui.reset = true
            case .F10:
                gui.switch_disasm = true
            case .F9:
                gui.switch_busdump = true
            case .F8:
                gui.switch_gpu = true
            case .F7:
                platform.read_intel_hex(p.bus, p.cpu, "data/tetris.hex", emu.FLASHSRC)
                p.cpu->reset()
			*/
            case .KP_1:
                p.bus.joy0.state += {.DOWN, .LEFT}
            case .KP_2:
                p.bus.joy0.state += {.DOWN}
            case .KP_3:
                p.bus.joy0.state += {.DOWN, .RIGHT}
            case .KP_4:
                p.bus.joy0.state += {.LEFT}
            case .KP_5:
                p.bus.joy0.state += {.BUTTON0}
            case .KP_6:
                p.bus.joy0.state += {.RIGHT}
            case .KP_7:
                p.bus.joy0.state += {.LEFT, .UP}
            case .KP_8:
                p.bus.joy0.state += {.UP}
            case .KP_9:
                p.bus.joy0.state += {.RIGHT, .UP}
            case .KP_0:
                p.bus.joy0.state += {.BUTTON1}
            case:
                send_key_to_ps2(p, e.key.keysym.scancode, e.type)
            }
        case .KEYUP:
            #partial switch(e.key.keysym.sym) {
			case .F1 : if "f1"  not_in p.cfg.key do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F2 : if "f2"  not_in p.cfg.key do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F3 : if "f3"  not_in p.cfg.key do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F4 : if "f4"  not_in p.cfg.key do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F5 : if "f5"  not_in p.cfg.key do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F6 : if "f6"  not_in p.cfg.key do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F7 : if "f7"  not_in p.cfg.key do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F8 : if "f8"  not_in p.cfg.key do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F9 : if "f9"  not_in p.cfg.key do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F10: if "f10" not_in p.cfg.key do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F11: if "f11" not_in p.cfg.key do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
			case .F12: if "f12" not_in p.cfg.key do send_key_to_ps2(p, e.key.keysym.scancode, e.type)
            case .KP_1:
                p.bus.joy0.state -= {.DOWN, .LEFT}
            case .KP_2:
                p.bus.joy0.state -= {.DOWN}
            case .KP_3:
                p.bus.joy0.state -= {.DOWN, .RIGHT}
            case .KP_4:
                p.bus.joy0.state -= {.LEFT}
            case .KP_5:
                p.bus.joy0.state -= {.BUTTON0}
            case .KP_6:
                p.bus.joy0.state -= {.RIGHT}
            case .KP_7:
                p.bus.joy0.state -= {.LEFT, .UP}
            case .KP_8:
                p.bus.joy0.state -= {.UP}
            case .KP_9:
                p.bus.joy0.state -= {.RIGHT, .UP}
            case .KP_0:
                p.bus.joy0.state -= {.BUTTON1}
            case: 
                send_key_to_ps2(p, e.key.keysym.scancode, e.type)
            }
        }
    }
}

render_gui :: proc(p: ^platform.Platform) -> (bool, bool) {

        // Step 1: process keyboard in (XXX: do it - mouse)
        process_input(p)

        // Step 2: handle GPU switching
        if gui.switch_gpu {
            gui.current_gpu        = 1        if gui.current_gpu == 0 else 0
            gui.g                  = gui.gpu0 
            gui.g                  = gui.gpu0 if gui.current_gpu == 0 else gui.gpu1
            gui.switch_gpu         = false
            gui.g.screen_resized   = true
            sdl2.SetWindowTitle(gui.window, fmt.ctprintf("morfeo : %s : gpu%d", emu.TARGET, gui.current_gpu))
        }

        // Step 3: handle screen resize
        if gui.g.screen_resized {
                gui.x_size = gui.g.screen_x_size
                gui.y_size = gui.g.screen_y_size

                gui.g.screen_resized = false
                update_window_size()
        }

        // Step 4: call active GPU to render things
        //         XXX: support two windows and rendering of two monitors at once
        if time.tick_since(gui.gpu0.last_tick) >= gui.gpu0.delay {
            if gui.current_gpu   == 0 do gui.g->render()
            gui.gpu0.frames      += 1
            gui.gpu0.last_tick    = time.tick_now()
            p.bus.timer2->tick()
        }

        if time.tick_since(gui.gpu1.last_tick) >= gui.gpu1.delay {
            if gui.current_gpu   == 1 do gui.g->render()
            gui.gpu1.frames      += 1
            gui.gpu1.last_tick    = time.tick_now()
        }

        // Step 5 : draw to screen
        // Step 5a: background
        //
        sdl2.SetRenderDrawColor(gui.renderer, gui.g.bg_color_r,
                                              gui.g.bg_color_g,
                                              gui.g.bg_color_b,
                                              sdl2.ALPHA_OPAQUE)
        sdl2.RenderClear(gui.renderer)

        // Step 5b: bitmap 0 and 1
        //
        if gui.g.bitmap_enabled & gui.g.graphic_enabled {
            if gui.g.bm0_enabled {
                sdl2.UpdateTexture(gui.texture_bm0, nil, gui.g.BM0FB, gui.x_size*4)
                sdl2.RenderCopy(gui.renderer, gui.texture_bm0, nil, nil)
            }
            if gui.g.bm1_enabled {
                sdl2.UpdateTexture(gui.texture_bm1, nil, gui.g.BM1FB, gui.x_size*4)
                sdl2.RenderCopy(gui.renderer, gui.texture_bm1, nil, nil)
            }
        }

        // Step 5c: text
        //
        if gui.g.text_enabled {
            sdl2.UpdateTexture(gui.texture_txt, nil, gui.g.TFB, gui.x_size*4)
            sdl2.RenderCopy(gui.renderer, gui.texture_txt, nil, nil)
        }

        // Step 5d: border
        //
        if gui.g.border_enabled do draw_border(gui.g)

        // Step 5e: mouse pointer (over border)
        if gui.g.pointer_enabled {
            if gui.g.pointer_updated {
                sdl2.UpdateTexture(gui.texture_mouse, nil, gui.g.MOUSEFB, 16*4)
                gui.g.pointer_updated = false
            }
            gui.mouse_rectangle.x = gui.mouse_x
            gui.mouse_rectangle.y = gui.mouse_y
            sdl2.RenderCopy(gui.renderer, gui.texture_mouse, nil, &gui.mouse_rectangle)
            //sdl2.RenderCopy(gui.renderer, gui.texture_mouse, nil, nil)
        }

        // Step  6: present to screen
        sdl2.RenderPresent(gui.renderer)

        // Step 7: back to main loop
        return gui.should_close, gui.switch_disasm
}
