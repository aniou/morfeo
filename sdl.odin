
package morfeo

import "core:log"
import "vendor:sdl2"
import "emulator:gpu"
import "emulator:platform"

WINDOW_NAME ::  "morfeo"

GUI :: struct {
    window:      ^sdl2.Window,
    renderer:    ^sdl2.Renderer,
    texture_txt: ^sdl2.Texture,
    texture_bm0: ^sdl2.Texture,
    texture_bm1: ^sdl2.Texture,

    orig_mode:   ^sdl2.DisplayMode,     // for return from fullscreen

    fullscreen:  bool,
    scale_mult:  i32,                   // scale factor, 1 or 2
    x_size:      i32,                   // emulated x screen size
    y_size:      i32,                   // emulated y screen size

    active_gpu:  u8,                    // GPU number

    should_close: bool,
    switch_gpu:   bool,
    current_gpu:  int,
    gpu:          ^gpu.GPU,             // currently active GPU

}

gui: GUI

create_texture :: proc() -> ^sdl2.Texture {
    texture := sdl2.CreateTexture(
               gui.renderer,
               sdl2.PixelFormatEnum.ARGB8888,
               sdl2.TextureAccess.STREAMING, 
               gui.x_size, 
               gui.y_size
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

// XXX add some parameters about screen size
init_sdl :: proc(gpu_number: int = 1) -> (ok: bool) {
    gui = GUI{}

    gui.x_size      = 800
    gui.y_size      = 600
    gui.scale_mult  = 2
	gui.fullscreen  = false
    gui.current_gpu = 0 if gpu_number == 0 else 1

    // init
    if sdl_res := sdl2.Init(sdl2.INIT_EVERYTHING); sdl_res < 0 {
        log.errorf("sdl2.init returned %v.", sdl_res)
        return false
    }

    // windows
    gui.window = sdl2.CreateWindow(
                 WINDOW_NAME, 
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

	ok = new_renderer_and_texture()
    return ok
}

new_renderer_and_texture :: proc() -> (ok: bool) {
    gui.renderer = sdl2.CreateRenderer(gui.window, -1, {.ACCELERATED})
    if gui.renderer == nil {
        log.errorf("sdl2.CreateRenderer failed.")
        return false
    }

    gui.texture_txt = create_texture()
    gui.texture_bm0 = create_texture()
    gui.texture_bm1 = create_texture()

    // XXX workaround - I don't get that
    sdl2.SetTextureBlendMode(gui.texture_bm0, sdl2.BlendMode.NONE)

    sdl2.SetHint("SDL_HINT_RENDER_BATCHING", "1")
	
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

process_input :: proc(p: ^platform.Platform) {
    e: sdl2.Event

    for sdl2.PollEvent(&e) {
        #partial switch(e.type) {
        case .QUIT:
            gui.should_close = true
        case .KEYDOWN:
            #partial switch(e.key.keysym.sym) {
            case .F12:
                gui.should_close = true
            case .F8:
                gui.switch_gpu = true
            case:
                send_key_to_ps2(p, e.key.keysym.scancode, e.type)
            }
        case .KEYUP:
            #partial switch(e.key.keysym.sym) {
            case .F12: // mask key
            case .F8:  // mask key
            case: 
                send_key_to_ps2(p, e.key.keysym.scancode, e.type)
            }
        }
    }
}
