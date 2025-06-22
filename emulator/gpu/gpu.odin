package gpu

import "core:time"

import "lib:emu"

import "emulator:pic"

BITS :: emu.Bitsize
GPU  :: struct {
    read:    proc(^GPU, BITS, u32, u32, emu.Region) -> u32,
    write:   proc(^GPU, BITS, u32, u32, u32,    emu.Region),
    delete:  proc(^GPU            ),
    render:  proc(^GPU            ),

    //dma_read8:   proc(^GPU, u32) -> u32,
    //dma_write8:  proc(^GPU, u32,    u32),

    name:               string,     // textual name of instance
    id:                 int,        // id of instance
    pic:                ^pic.PIC,

    TFB:     ^[1024*768]u32,        // text    framebuffer (max resolution)
    BM0FB:   ^[1024*768]u32,        // bitmap0 framebuffer (max resolution)
    BM1FB:   ^[1024*768]u32,        // bitmap1 framebuffer (max resolution)
    MOUSEFB: ^[  16* 16]u32,        // mouse pointer framebuffer

    gpu_enabled:       bool,
    text_enabled:      bool,
    graphic_enabled:   bool,
    bitmap_enabled:    bool,
    border_enabled:    bool,
    sprite_enabled:    bool,
    tile_enabled:      bool,
    gamma_enabled:     bool,
    pointer_updated:   bool,
    pointer_enabled:   bool,

    border_color_b:       u8,
    border_color_g:       u8,
    border_color_r:       u8,
    border_x_size:        i32,
    border_y_size:        i32,
    border_scroll_offset: i32,

    bg_color_b:        u8,
    bg_color_g:        u8,
    bg_color_r:        u8,

    screen_resized:    bool,
    screen_x_size:     i32,
    screen_y_size:     i32,

    cursor_enabled:    bool,
    cursor_rate:       i32,
    cursor_visible:    bool,     // set by timer in main GUI, for blinking
    cursor_x:          u32,
    cursor_y:          u32,
    cursor_character:  u32,
    cursor_fg:         u32,
    cursor_bg:         u32,

    bm0_enabled:           bool,
    bm0_collision_enabled: bool,
    bm0_pointer:           u32,
    bm0_lut:               u32,

    bm1_enabled:           bool,
    bm1_collision_enabled: bool,
    bm1_pointer:           u32,
    bm1_lut:               u32,

    dip:               u32,                // copy of status of DIP switch
    background:        [3]u8,              // r, g, b
    frames:            u32,                // number of generated frames, for TIMER*
    delay:             time.Duration,      // number of milliseconds to wait between frames
                                           // 16 for 60Hz, 14 for 70Hz
    last_tick:         time.Tick,          // when last tick was made

    model: union {GPU_Vicky2, GPU_Vicky3, GPU_tVicky}
}

// not used - it is a separated approach, alternative to vtable
// when gpu.render(gpu) is called (or simply render, but we need
// a way to differentiate calls like 'read')
//
// so read_gpu :: proc {switch g in gpu...}
//    read_bus :: proc {switch b in bus...}
//    read     :: proc {read_bus, read_gpu} ?

// render :: #force_inline proc(gpu: ^GPU) {
//     switch g in gpu.model {
//     case GPU_Vicky3: vicky3_render_text(g)
//     case GPU_Vicky2: 
//     case GPU_tVicky:
//     }
// }
 
