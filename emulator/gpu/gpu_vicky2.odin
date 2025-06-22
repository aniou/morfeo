package gpu

import "core:fmt"
import "core:log"
import "core:os"
import "core:time"

import "lib:emu"

import "emulator:pic"

// physical DIP switch 
DIP_HIRES              :: 0x_00_00_00_20  //     - real DIP postion
DIP_GAMMA              :: 0x_00_00_00_40  //     - real DIP position

// Master Control LOW
VKY2_MCR_TEXT          :: 0x_00_00_00_01  // A   - enable text mode
VKY2_MCR_TEXT_OVERLAY  :: 0x_00_00_00_02  // A   - enable text overlay
VKY2_MCR_GRAPHIC       :: 0x_00_00_00_04  // A   - enable graphic engine
VKY2_MCR_BITMAP        :: 0x_00_00_00_08  // A   - enable bitmap engine
VKY2_MCR_TILE          :: 0x_00_00_00_10  // A   - enable tile engine
VKY2_MCR_SPRITE        :: 0x_00_00_00_20  // A   - enable sprite engine
VKY2_MCR_GAMMA_ENABLE  :: 0x_00_00_00_40  // A   - enable gamma correction
VKY2_MCR_VIDEO_DISABLE :: 0x_00_00_00_80  // A   - disable video engine

// Master Control HIGH
VKY2_MODE_MASK         :: 0x_00_00_00_01  // A   - video mode: 0 - 640x480 (Clock @ 25.175Mhz), 1 - 800x600 (Clock @ 40Mhz)
VKY2_MODE_640_480      :: 0x_00_00_00_00
VKY2_MODE_800_600      :: 0x_00_00_00_01
VKY2_DOUBLE_PIXEL      :: 0x_00_00_00_02  // A   - double pixel (0 - no, 2 - yes)

VKY2_BCR_ENABLE        :: 0x_00_00_00_01  // A   -  border visible 0 - disable, 1 - enable
VKY2_BCR_X_SCROLL      :: 0x_00_00_00_70  // A   -  border scroll, at bit 4..6 (val: 0-7)

VKY2_CCR_ENABLE        :: 0x_00_00_00_01  // A   -  cursor enable
VKY2_CCR_RATE_MASK     :: 0x_00_00_00_06  // A   -  flash rate: 00 - 1/Sec, 01 - 2/Sec, 10 - 4/Sec, 11 - 5/Sec
VKY2_CCR_FONT_PAGE0    :: 0x_00_00_00_08  // A   -  font page 0 or 1
VKY2_CCR_FONT_PAGE1    :: 0x_00_00_00_10  // A   -  font page 0 or 1

// selected mouse pointer bitmap
MOUSE_PTR :: enum {
    PTR0,
    PTR1,
}

Register_vicky2 :: enum u32 {
    VKY2_MCR_L        = 0x_00_00,     // A   - master control register
    VKY2_MCR_H        = 0x_00_01,     // A   - master control register
    VKY2_GAMMA_CR     = 0x_00_02,     //     - gamma control register
                                      //     - reserved
    VKY2_BCR          = 0x_00_04,     // A   - border control register
    VKY2_BRD_COL_B    = 0x_00_05,     // A   - border color Blue
    VKY2_BRD_COL_G    = 0x_00_06,     // A   - border color Green
    VKY2_BRD_COL_R    = 0x_00_07,     // A   - border color Red
    VKY2_BRD_XSIZE    = 0x_00_08,     // A   - border X size, 0-32 (32)
    VKY2_BRD_YSIZE    = 0x_00_09,     // A   - border X size, 0-32 (32)
                                      //     - unknown
                                      //     - unknown
                                      //     - unknown
    VKY2_BGR_COL_B    = 0x_00_0D,     // A   - background color Blue
    VKY2_BGR_COL_G    = 0x_00_0E,     // A   - background color Green
    VKY2_BGR_COL_R    = 0x_00_0F,     // A   - background color Red
    VKY2_CCR          = 0x_00_10,     // A   - cursor control register
    VKY2_TXT_SAPTR    = 0x_00_11,     // A   - offset to change the Starting address of the Text Mode Buffer (in x)
    VKY2_TXT_CUR_CHAR = 0x_00_12,     // A   - text cursor character
    VKY2_TXT_CUR_CLR  = 0x_00_13,     // A   - text cursor color
    VKY2_TXT_CUR_XL   = 0x_00_14,     // A   - text cursor X position (low)
    VKY2_TXT_CUR_XH   = 0x_00_15,     // A   - text cursor X position (high)
    VKY2_TXT_CUR_YL   = 0x_00_16,     // A   - text cursor Y position (low)
    VKY2_TXT_CUR_YH   = 0x_00_17,     // A   - text cursor Y position (high)

    BM0_CONTROL_REG   = 0x_01_00,     // A   - BM0 control
    BM0_START_ADDY_L  = 0x_01_01,     // A   - Start Address Within the Video Memory (offset by $B0:0000) 
    BM0_START_ADDY_M  = 0x_01_02,     // A
    BM0_START_ADDY_H  = 0x_01_03,     // A
    BM0_X_OFFSET      = 0x_01_04,     // A   - not implemented
    BM0_Y_OFFSET      = 0x_01_05,     // A

    BM1_CONTROL_REG   = 0x_01_08,     // A   - BM1 control
    BM1_START_ADDY_L  = 0x_01_09,     // A   - Start Address Within the Video Memory (offset by $B0:0000) 
    BM1_START_ADDY_M  = 0x_01_0A,     // A
    BM1_START_ADDY_H  = 0x_01_0B,     // A
    BM1_X_OFFSET      = 0x_01_0C,     // A   - not implemented
    BM1_Y_OFFSET      = 0x_01_0D,     // A

}

VKY2_CURSOR_BLINK_RATE           :: [4]i32{1000, 500, 250, 200}


GPU_Vicky2 :: struct {
    using gpu: ^GPU,

    vram0:     [dynamic]u32,   // VRAM
    text:      [dynamic]u32,   // text memory
    tc:        [dynamic]u32,   // text color memory
    mouseptr0: [dynamic]u32,   // mouse pointer memory (16x16 bytes)
    mouseptr1: [dynamic]u32,   // mouse pointer memory (16x16 bytes)

    lut:       [dynamic]u8,    // LUT memory block (lut0 to lut7 ARGB)
    fg:        [dynamic]u32,   // text foreground LUT cache
    bg:        [dynamic]u32,   // text background LUT cache
    font:      [dynamic]u8,    // font cache       : 256 chars  * 8 lines * 8 columns
    fontmem :  [dynamic]u32,   // font memory

    mouse_lut: [256][4]u8,     // pre-calculated grayscale palette for mouse cursor
    fg_clut:    [16][4]u8,     // 16 pre-calculated RGBA colors for text fore-
    bg_clut:    [16][4]u8,     // ...and background

    starting_fb_row_pos: u32,
    text_cols:           u32,
    text_rows:           u32,
    bm0_start_addr:      u32,
    bm1_start_addr:      u32,
    pixel_size:          u32,       // 1 for normal, 2 for double - XXX: not used yet
    resolution:          u32,       // for tracking resolution changes
    cursor_enabled:      bool,
    overlay_enabled:     bool,

    pointer_selected:    MOUSE_PTR, // pointer 0 or pointer 1 selected

    gamma_dip_override:  bool,      // 0: obey dip switch,   1: software control
    gamma_applied:       bool,      // 0: gamma not applied  1: gamma applied
}

// --------------------------------------------------------------------

// NOTE: The upper left corner of the sprite is offset by 32 pixels. Using (0,0)
// will hide the sprite. Position (32,32) is mapped to the upper left corner of
// the screen.

VICKY2_SPRITE :: struct {
    enable       : bool,
    collision_en : bool, // XXX not supported yet
    lut          : u32,
    depth        : u32,  // XXX not supported yet
    address      : u32,  // u24 in memory address
    x            : u32,  // u16 x position, first visible: 32
    y            : u32,  // u16 y position, first visible: 32
}

vicky2_make :: proc(name: string, pic: ^pic.PIC, id: int, vram: int, dip: u32) -> ^GPU {
    log.infof("vicky2: gpu%d initialization start, name %s", id, name)

    gpu       := new(GPU)
    gpu.name   = name
    gpu.id     = id
    gpu.dip    = dip
    gpu.pic    = pic
    gpu.read   = vicky2_read
    gpu.write  = vicky2_write
    gpu.delete = vicky2_delete
    gpu.render = vicky2_render

    g         := GPU_Vicky2{gpu = gpu}

    g.vram0     = make([dynamic]u32,      vram) // video ram (depends from model)
    g.text      = make([dynamic]u32,    0x2000) // text memory                  0x4000 in GenX
    g.tc        = make([dynamic]u32,    0x2000) // text color memory            0x4000 in GenX
    g.fg        = make([dynamic]u32,    0x2000) // text foreground LUT cache    0x4000 in GenX
    g.bg        = make([dynamic]u32,    0x2000) // text backround  LUT cache    0x4000 in GenX
    g.lut       = make([dynamic]u8,     0x2000) // 8 * 256 * 4 colors 
    g.font      = make([dynamic]u8,  0x100*8*8) // font cache 256 chars * 8 lines * 8 columns
    g.fontmem   = make([dynamic]u32,     0x800) // font bank0 memory
    g.mouseptr0 = make([dynamic]u32,     0x100) // 16x16
    g.mouseptr1 = make([dynamic]u32,     0x100) // 16x16

    g.TFB     = new([1024*768]u32)            // text framebuffer     - for max size
    g.BM0FB   = new([1024*768]u32)            // bitmap0 framebuffer  - for max size
    g.BM1FB   = new([1024*768]u32)            // bitmap1 framebuffer  - for max size
    g.MOUSEFB = new([  16* 16]u32)            // mouse   framebuffer  - 16x16

    g.screen_x_size  = 800                if g.dip & DIP_HIRES == DIP_HIRES else 640
    g.screen_y_size  = 600                if g.dip & DIP_HIRES == DIP_HIRES else 480
    g.resolution     = VKY2_MODE_800_600  if g.dip & DIP_HIRES == DIP_HIRES else VKY2_MODE_640_480
    g.screen_resized = false

    g.pixel_size           = 1
    g.cursor_enabled       = true
    g.cursor_visible       = true
    g.bitmap_enabled       = true  // XXX: there is no way to change it in vicky2?
    g.text_enabled         = true 
    g.gamma_dip_override   = false
    g.gamma_applied        = false
    g.pointer_enabled      = true
    g.pointer_selected     = .PTR0

    g.border_color_b       = 0x20
    g.border_color_g       = 0x00
    g.border_color_r       = 0x20
    g.border_x_size        = 0x20
    g.border_y_size        = 0x20
    g.border_scroll_offset = 0x00 // XXX: not used yet
    g.starting_fb_row_pos  = 0x00
    g.text_cols            = 0x00
    g.text_rows            = 0x00
    g.bm0_start_addr       = 0x00 // relative from beginning of vram
    g.bm1_start_addr       = 0x00 // relative from beginning of vram

    g.delay                = 16 * time.Millisecond  // 16 milliseconds for ~60Hz XXX - to be checked

    // fake init
    for _, i in g.text {
        g.text[i] = 35   // u32('#')
        g.fg[i]   = 2    // green in FoenixMCP
        g.bg[i]   = 0    // black in FoenixMCP
    }

    g.mouse_lut[0] = {0,0,0,0}              // 0 is fully transparent 
    for i in u8(1) ..= 0xFF {
        g.mouse_lut[i] = {i, i, i, 0xFF}
    }

    g.fg_clut = [16][4]u8 {
                {0x00, 0x00, 0x00, 0xFF},
                {0x00, 0x00, 0x80, 0xFF},
                {0x00, 0x80, 0x00, 0xFF},
                {0x80, 0x00, 0x00, 0xFF},
                {0x00, 0x80, 0x80, 0xFF},
                {0x80, 0x80, 0x00, 0xFF},
                {0x80, 0x00, 0x80, 0xFF},
                {0x80, 0x80, 0x80, 0xFF},
                {0x00, 0x45, 0xFF, 0xFF},
                {0x13, 0x45, 0x8B, 0xFF},
                {0x00, 0x00, 0x20, 0xFF},
                {0x00, 0x20, 0x00, 0xFF},
                {0x20, 0x00, 0x00, 0xFF},
                {0x20, 0x20, 0x20, 0xFF},
                {0x60, 0x60, 0x60, 0xFF},
                {0xFF, 0xFF, 0xFF, 0xFF},
        }

    g.bg_clut = [16][4]u8 {
                {0x00, 0x00, 0x00, 0xFF},
                {0x00, 0x00, 0x80, 0xFF},
                {0x00, 0x80, 0x00, 0xFF},
                {0x80, 0x00, 0x00, 0xFF},
                {0x00, 0x20, 0x20, 0xFF},
                {0x20, 0x20, 0x00, 0xFF},
                {0x20, 0x00, 0x20, 0xFF},
                {0x20, 0x20, 0x20, 0xFF},
                {0x1E, 0x69, 0xD2, 0xFF},
                {0x13, 0x45, 0x8B, 0xFF},
                {0x00, 0x00, 0x20, 0xFF},
                {0x00, 0x20, 0x00, 0xFF},
                {0x40, 0x00, 0x00, 0xFF},
                {0x30, 0x30, 0x30, 0xFF},
                {0x40, 0x40, 0x40, 0xFF},
                {0xFF, 0xFF, 0xFF, 0xFF},
        }

    for _, color in g.bg_clut {
        log.debugf("BASE BG LUT: %2d %d %3d : %3d %3d %3d %3d %08x",
                   color, 0, 0,
                   g.bg_clut[color][0],
                   g.bg_clut[color][1],
                   g.bg_clut[color][2],
                   g.bg_clut[color][3],
                   (transmute(^u32) &g.bg_clut[color])^
        )
    }
    for _, color in g.fg_clut {
        log.debugf("BASE FG LUT: %2d %d %3d : %3d %3d %3d %3d %08x",
                   color, 0, 0,
                   g.fg_clut[color][0],
                   g.fg_clut[color][1],
                   g.fg_clut[color][2],
                   g.fg_clut[color][3],
                   (transmute(^u32) &g.fg_clut[color])^
        )
    }

    gpu.model  = g
    vicky2_recalculate_screen(g)
    return gpu
}

vicky2_delete :: proc(gpu: ^GPU) {
    g         := &gpu.model.(GPU_Vicky2)

    delete(g.text)
    delete(g.vram0)
    delete(g.tc)
    delete(g.fg)
    delete(g.bg)
    delete(g.lut)
    delete(g.font)
    delete(g.fontmem)
    delete(g.mouseptr0)
    delete(g.mouseptr1)

    free(g.TFB)
    free(g.BM0FB)
    free(g.BM1FB)
    free(g.MOUSEFB)

    free(gpu)
    return
}

vicky2_read :: proc(gpu: ^GPU, size: BITS, base, busaddr: u32, mode: emu.Region = .MAIN) -> (val: u32) {
    d    := &gpu.model.(GPU_Vicky2)
    addr := busaddr - base

    if size != .bits_8 {
        emu.unsupported_read_size(#procedure, d.name, d.id, size, busaddr)
    }


    #partial switch mode {
    case .MAIN_A: 
        val = vicky2_read_register(d, size, busaddr, addr, mode)
    case .MAIN_B: 
        val = vicky2_read_register(d, size, busaddr, addr, mode)
    case .TEXT:
        val = d.text[addr]
    case .TEXT_COLOR:
        val = d.tc[addr]
    case .TEXT_FG_LUT:
        color := addr >> 2 // every color ARGB bytes, assume 4-byte align
        pos   := addr  & 3 // position in 32-bit variable
        val = u32(d.fg_clut[color][pos])
    case .TEXT_BG_LUT:
        color := addr >> 2 // every color ARGB bytes, assume 4-byte align
        pos   := addr  & 3 // position in 32-bit variable
        val = u32(d.bg_clut[color][pos])

    case .LUT:        val = cast(u32) d.lut[addr]
    case .VRAM0:      val = d.vram0[addr]
    case .FONT_BANK0: val = d.fontmem[addr]
    case .MOUSEPTR0:  val = d.mouseptr0[addr]
    case .MOUSEPTR1:  val = d.mouseptr1[addr]

    case: 
        emu.read_not_implemented(#procedure, d.name, size, busaddr)
    }
    return
}


vicky2_write :: proc(gpu: ^GPU, size: BITS, base, busaddr, val: u32, mode: emu.Region = .MAIN) {
    d    := &gpu.model.(GPU_Vicky2)
    addr := busaddr - base

    if size != .bits_8 {
        emu.unsupported_write_size(#procedure, d.name, d.id, size, busaddr, val)
    } 

    #partial switch mode {
    case .MAIN_A: 
        vicky2_write_register(&d.model.(GPU_Vicky2), size, busaddr, addr, val, mode)

    case .MAIN_B: 
        vicky2_write_register(&d.model.(GPU_Vicky2), size, busaddr, addr, val, mode)

    case .TEXT:
        d.text[addr] = val & 0x00_00_00_ff
        //log.debugf("vicky2: %s text memory  addr %d value %d", d.name, busaddr, val)

    case .TEXT_COLOR:
        d.fg[addr] = (val & 0xf0) >> 4
        d.bg[addr] =  val & 0x0f
        d.tc[addr] =  val & 0x00_00_00_ff
        
    case .TEXT_FG_LUT:
        color := addr >> 2 // every color ARGB bytes, assume 4-byte align
        pos   := addr  & 3 // position in 32-bit variable
        if pos != 3 {      // ALPHA isn't settable, always FF (max)
            d.fg_clut[color][pos] = u8(val)
        }
        /*
        log.debugf("TEXT FG LUT: %2d %d %3d : %3d %3d %3d %3d %08x",
                   color, pos, val,
                   d.fg_clut[color][0],
                   d.fg_clut[color][1],
                   d.fg_clut[color][2],
                   d.fg_clut[color][3],
                   (transmute(^u32) &d.fg_clut[color])^
        )
        */


    case .TEXT_BG_LUT:
        color := addr >> 2 // every color ARGB bytes, assume 4-byte align
        pos   := addr  & 3 // position in 32-bit variable
        if pos != 3 {      // ALPHA isn't settable, always FF (max)
            d.bg_clut[color][pos] = u8(val)
        }
        /*
        log.debugf("TEXT BG LUT: %2d %d %3d : %3d %3d %3d %3d %08x",
                   color, pos, val,
                   d.bg_clut[color][0],
                   d.bg_clut[color][1],
                   d.bg_clut[color][2],
                   d.bg_clut[color][3],
                   (transmute(^u32) &d.bg_clut[color])^
        )
        */

    case .FONT_BANK0:
        d.fontmem[addr] = val
        vicky2_update_font_cache(d, addr, u8(val))  // every bit in font cache is mapped to byte

    case .LUT:
        /*
        lut_id := addr >> 10
        color  := val   & 0xFF
        pos    := val   & 0x03
        base   := val   & 0xFFFC
        log.debugf("BM LUT%d (%04X): color %3d position %3d val %3d : %3d %3d %3d %3d %08x",
                   lut_id, addr,
                   color, pos, val,
                   d.lut[base+0],
                   d.lut[base+1],
                   d.lut[base+2],
                   d.lut[base+3],
                   (transmute(^u32) &d.lut[base])^
        )
        */
        if (addr & 3) == 3 {      // ALPHA isn't settable, always FF (max)
            d.lut[addr] = 0xFF
        } else {
            d.lut[addr] = cast(u8) val
        }
        
    case .VRAM0:
        d.vram0[addr] = val

    case .MOUSEPTR0:
        log.debugf("vicky2: %s mouseptr0  addr %d value %d", d.name, busaddr, val)
        d.mouseptr0[addr] = val
        if d.pointer_selected == .PTR0 {
            vicky2_render_mouse(d)
        }

    case .MOUSEPTR1:
        log.debugf("vicky2: %s mouseptr1  addr %d value %d", d.name, busaddr, val)
        d.mouseptr1[addr] = val
        if d.pointer_selected == .PTR1 {
            vicky2_render_mouse(d)
        }

    case        : 
        emu.write_not_implemented(#procedure, d.name, size, busaddr, val)
    }
    return
}


@private
vicky2_write_register :: proc(d: ^GPU_Vicky2, size: BITS, busaddr, addr, val: u32, mode: emu.Region) {

    if size != .bits_8 {
        emu.unsupported_write_size(#procedure, d.name, d.id, size, busaddr, val)
        return
    }

    reg := Register_vicky2(addr)
    switch reg {
    case .VKY2_MCR_L:

        if mode == .MAIN_A {
            d.text_enabled    = (val & VKY2_MCR_TEXT )         != 0
            d.overlay_enabled = (val & VKY2_MCR_TEXT_OVERLAY ) != 0
            d.graphic_enabled = (val & VKY2_MCR_GRAPHIC )      != 0
            d.bitmap_enabled  = (val & VKY2_MCR_BITMAP )       != 0
            d.tile_enabled    = (val & VKY2_MCR_TILE )         != 0
            d.sprite_enabled  = (val & VKY2_MCR_SPRITE )       != 0
            d.gamma_enabled   = (val & VKY2_MCR_GAMMA_ENABLE)  != 0
            d.gpu_enabled     = (val & VKY2_MCR_VIDEO_DISABLE) == 0
        } else {
            emu.write_not_implemented(#procedure, ".VKY2_MCR_L/.MAIN_B", size, busaddr, val)
        }

    case .VKY2_MCR_H:
        if mode == .MAIN_A {
            if d.resolution != (val & VKY2_MODE_MASK) {

                d.resolution     = val & VKY2_MODE_MASK
                d.screen_resized = true

                switch d.resolution {
                case VKY2_MODE_640_480:     // 0
                    d.screen_x_size = 640
                    d.screen_y_size = 480
                    d.delay         = 16  * time.Millisecond   // 16 for 60Hz, 14 for 70Hz
                case VKY2_MODE_800_600:     // 1
                    d.screen_x_size = 800
                    d.screen_y_size = 600
                    d.delay         = 16  * time.Millisecond   // for 60Hz
                }
                vicky2_recalculate_screen(d)
            }
        } else {
            emu.write_not_implemented(#procedure, ".VKY2_MCR_H/.MAIN_B", size, busaddr, val)
        }

    case .VKY2_GAMMA_CR: 
        emu.write_not_implemented(#procedure, fmt.tprintf("%v", reg), size, busaddr, val)

    case .VKY2_BCR:
        d.border_enabled = (val & VKY2_BCR_ENABLE )       != 0

        if (val & VKY2_BCR_X_SCROLL) != 0 {
            emu.write_not_implemented(#procedure, "VKY2_A_BCR_X_SCROLL", size, busaddr, val)
        }

    case .VKY2_BRD_COL_B: d.border_color_b =  u8(val); if d.border_enabled do vicky2_recalculate_screen(d)
    case .VKY2_BRD_COL_G: d.border_color_g =  u8(val); if d.border_enabled do vicky2_recalculate_screen(d)
    case .VKY2_BRD_COL_R: d.border_color_r =  u8(val); if d.border_enabled do vicky2_recalculate_screen(d)
    case .VKY2_BRD_XSIZE: d.border_x_size  = i32(val); if d.border_enabled do vicky2_recalculate_screen(d)
    case .VKY2_BRD_YSIZE: d.border_y_size  = i32(val); if d.border_enabled do vicky2_recalculate_screen(d)
    case .VKY2_BGR_COL_B: d.bg_color_b     =  u8(val)
    case .VKY2_BGR_COL_G: d.bg_color_g     =  u8(val)
    case .VKY2_BGR_COL_R: d.bg_color_r     =  u8(val)

    case .VKY2_CCR:
        d.cursor_enabled   =     (val & VKY2_CCR_ENABLE    ) != 0
        d.cursor_rate      = i32((val & VKY2_CCR_RATE_MASK ) >> 1)   // XXX - why i32?

        if (val & VKY2_CCR_FONT_PAGE0) != 0 {
            emu.write_not_implemented(#procedure, "VKY2_CCR_FONT_PAGE0", size, busaddr, val)
        }
        if (val & VKY2_CCR_FONT_PAGE1) != 0 {
            emu.write_not_implemented(#procedure, "VKY2_CCR_FONT_PAGE1", size, busaddr, val)
        }

    case .VKY2_TXT_SAPTR:    emu.write_not_implemented(#procedure, "VKY2_TXT_SAPTR", size, busaddr, val)
    case .VKY2_TXT_CUR_CHAR: d.cursor_character = val

    case .VKY2_TXT_CUR_CLR:     
        d.cursor_bg        =  val & 0x0f
        d.cursor_fg        = (val & 0xf0) >> 4

    case .VKY2_TXT_CUR_XL: d.cursor_x  = val
    case .VKY2_TXT_CUR_XH: { }
    case .VKY2_TXT_CUR_YL: d.cursor_y  = val
    case .VKY2_TXT_CUR_YH: { }

    case .BM0_CONTROL_REG : 
		d.bm0_enabled           =  val & 0x01  != 0	  // bit 0
		d.bm0_lut               = (val & 0x0E) >> 1   // bit 1 to 3
		d.bm0_collision_enabled =  val & 0x40  != 0   // bit 6
        log.debugf("%s d.bm0_lut set to %d by val %d", #procedure, d.bm0_lut, val)

    case .BM0_START_ADDY_L: d.bm0_pointer = emu.assign_byte1(d.bm0_pointer, val)
    case .BM0_START_ADDY_M: d.bm0_pointer = emu.assign_byte2(d.bm0_pointer, val)
    case .BM0_START_ADDY_H: d.bm0_pointer = emu.assign_byte3(d.bm0_pointer, val)
    case .BM0_X_OFFSET    : // not implemented
    case .BM0_Y_OFFSET    : // not implemented

    case .BM1_CONTROL_REG : 
		d.bm1_enabled           =  val & 0x01  != 0	  // bit 0
		d.bm1_lut               = (val & 0x0E) >> 1   // bit 1 to 3
		d.bm1_collision_enabled =  val & 0x40  != 0   // bit 6
        log.debugf("%s d.bm1_lut set to %d by val %d", #procedure, d.bm1_lut, val)

    case .BM1_START_ADDY_L: d.bm1_pointer = emu.assign_byte1(d.bm1_pointer, val)
    case .BM1_START_ADDY_M: d.bm1_pointer = emu.assign_byte2(d.bm1_pointer, val)
    case .BM1_START_ADDY_H: d.bm1_pointer = emu.assign_byte3(d.bm1_pointer, val)
    case .BM1_X_OFFSET    : // not implemented
    case .BM1_Y_OFFSET    : // not implemented

    case                 : emu.write_not_implemented(#procedure, "UNKNOWN",         size, busaddr, val)
    }
}

@private
vicky2_read_register :: proc(d: ^GPU_Vicky2, size: BITS, busaddr, addr: u32, mode: emu.Region) -> (val: u32) {

    if size != .bits_8 {
        emu.unsupported_read_size(#procedure, d.name, d.id, size, busaddr)
        return
    }

    reg := Register_vicky2(addr)
    switch reg {
    case .VKY2_MCR_L:
        if mode == .MAIN_A {
            val |= VKY2_MCR_TEXT          if d.text_enabled    else 0           // Bit[0]
            val |= VKY2_MCR_TEXT_OVERLAY  if d.overlay_enabled else 0           // Bit[1]
            val |= VKY2_MCR_GRAPHIC       if d.graphic_enabled else 0           // Bit[2]
            val |= VKY2_MCR_BITMAP        if d.bitmap_enabled  else 0           // Bit[3]
            val |= VKY2_MCR_TILE          if d.tile_enabled    else 0           // Bit[4]
            val |= VKY2_MCR_SPRITE        if d.sprite_enabled  else 0           // Bit[5]
            val |= VKY2_MCR_GAMMA_ENABLE  if d.gamma_enabled   else 0           // Bit[6]
            val |= VKY2_MCR_VIDEO_DISABLE if ! d.gpu_enabled   else 0           // Bit[7]
        } else {
            emu.read_not_implemented(#procedure, ".VKY2_MCR_L / !.MAIN_A", size, busaddr)
        }
    case .VKY2_MCR_H:
            val |= VKY2_MODE_800_600  if  d.resolution == VKY2_MODE_800_600  else 0
            val |= VKY2_DOUBLE_PIXEL  if  d.pixel_size == 2                  else 0
    case .VKY2_GAMMA_CR:
        // GAMMA_Ctrl_Input        = $01 ; 0 = DipSwitch Chooses GAMMA on/off , 1- Software Control
        // GAMMA_Ctrl_Soft         = $02 ; 0 = GAMMA Table is read_not Applied, 1 = GAMMA Table is Applied
        // GAMMA_DP_SW_VAL         = $08 ; READ ONLY - Actual DIP Switch Value
        // HIRES_DP_SW_VAL         = $10 ; READ ONLY - 0 = Hi-Res on BOOT ON, 1 = Hi-Res on BOOT OFF
        val |= 0x01 if d.gamma_dip_override           else 0
        val |= 0x02 if d.gamma_applied                else 0
        val |= 0x08 if d.dip & DIP_GAMMA == DIP_GAMMA else 0
        val |= 0x10 if d.dip & DIP_HIRES == DIP_HIRES else 0

    case .VKY2_BCR:
        val |= VKY2_BCR_ENABLE if d.border_enabled else 0
        val |= (u32(d.border_scroll_offset) <<  4)
        
    case .VKY2_BRD_COL_B: val  =  u32(d.border_color_b)
    case .VKY2_BRD_COL_G: val  =  u32(d.border_color_g)
    case .VKY2_BRD_COL_R: val  =  u32(d.border_color_r)
    case .VKY2_BRD_XSIZE: val  =  u32(d.border_x_size)
    case .VKY2_BRD_YSIZE: val  =  u32(d.border_y_size)
    case. VKY2_BGR_COL_B: val  =  u32(d.background[2])
    case. VKY2_BGR_COL_G: val  =  u32(d.background[1])
    case. VKY2_BGR_COL_R: val  =  u32(d.background[0])

    case .VKY2_CCR:
        val |= VKY2_CCR_ENABLE if d.cursor_enabled else 0
        val |= u32(d.cursor_rate >> 1)
        // XXX: cursor font page 0 and 1 read_not implemented!

    case .VKY2_TXT_SAPTR:
        emu.read_not_implemented(#procedure, fmt.tprintf("%v", reg), size, busaddr)

    case .VKY2_TXT_CUR_CHAR: 
        val = d.cursor_character

    case .VKY2_TXT_CUR_CLR:
        val  = d.cursor_bg
        val |= d.cursor_fg << 4

    case .VKY2_TXT_CUR_XL: val = d.cursor_x
    case .VKY2_TXT_CUR_XH: val = 0
    case .VKY2_TXT_CUR_YL: val = d.cursor_y
    case .VKY2_TXT_CUR_YH: val = 0

    case .BM0_CONTROL_REG : 
        val |= 0x01 if d.bm0_enabled           else 0 // bit 0
        val |= 0x40 if d.bm0_collision_enabled else 0 // bit 6
		val |=         (d.bm0_lut & 0x05) << 1        // bit 1 - 3 

    case .BM0_START_ADDY_L: val = emu.get_byte1(d.bm0_pointer)
    case .BM0_START_ADDY_M: val = emu.get_byte2(d.bm0_pointer)
    case .BM0_START_ADDY_H: val = emu.get_byte3(d.bm0_pointer)
    case .BM0_X_OFFSET    : val = 0 // not implemented
    case .BM0_Y_OFFSET    : val = 0 // not implemented

    case .BM1_CONTROL_REG : 
        val |= 0x01 if d.bm1_enabled           else 0 // bit 0
        val |= 0x40 if d.bm1_collision_enabled else 0 // bit 6
		val |=         (d.bm1_lut & 0x05) << 1        // bit 1 - 3 

    case .BM1_START_ADDY_L: val = emu.get_byte1(d.bm1_pointer)
    case .BM1_START_ADDY_M: val = emu.get_byte2(d.bm1_pointer)
    case .BM1_START_ADDY_H: val = emu.get_byte3(d.bm1_pointer)
    case .BM1_X_OFFSET    : val = 0 // not implemented
    case .BM1_Y_OFFSET    : val = 0 // not implemented

    case                 : emu.read_not_implemented(#procedure, "UNKNOWN", size, busaddr)
    }
    return
}

@private
vicky2_b_write_register :: proc(d: ^GPU_Vicky2, size: BITS, busaddr, addr, val: u32) {
    emu.write_not_implemented(#procedure, d.name, size, busaddr, val)
}

@private
vicky2_b_read_register :: proc(d: ^GPU_Vicky2, size: BITS, busaddr, addr: u32) -> (val: u32) {
    emu.read_not_implemented(#procedure, d.name, size, busaddr)
    return
}


// GUI-specific
// updates font cache by converting bits to bytes
// position - position of indyvidual byte in font bank
// val      - particular value
@private
vicky2_update_font_cache :: proc(g: ^GPU_Vicky2, position: u32, value: u8) {
       //log.debugf("vicky2: %s update font cache position %d value %d", g.name, position, value)
       pos := position * 8
       val := value
        for j := u32(8); j > 0; j = j - 1 {          // counting down spares from shifting val left
                if (val & 1) == 1 {
                        g.font[pos + j - 1] = 1
                } else {
                        g.font[pos + j - 1] = 0
                }
                val = val >> 1
        }
}


vicky2_recalculate_screen :: proc(gpu: ^GPU) {
    g         := &gpu.model.(GPU_Vicky2)
    if g.border_enabled {
            g.starting_fb_row_pos = u32(g.screen_x_size) * u32(g.border_y_size) + u32(g.border_x_size)
            g.text_rows = u32((g.screen_y_size - g.border_y_size*2) / 8)
    } else {
            g.starting_fb_row_pos = 0
            g.text_rows = u32(g.screen_y_size / 8)
    }

    g.text_cols = u32(g.screen_x_size / 8)
    //g.text_rows = u32(g.screen_y_size / 8)

    log.debugf("vicky2: %s text_rows: %d", g.name, g.text_rows)
    log.debugf("vicky2: %s text_cols: %d", g.name, g.text_cols)
    log.debugf("vicky2: %s border: %v %d %d", g.name, g.border_enabled, g.border_x_size, g.border_y_size)
    log.debugf("vicky2: %s resolution %08x", g.name, g.resolution)
    return
}

vicky2_render :: proc(gpu: ^GPU) {
    if gpu.id == 0 {
        gpu.pic->trigger(.VICKY_A_SOF)
    } else {
        gpu.pic->trigger(.VICKY_B_SOF)
    }
    if gpu.text_enabled do vicky2_render_text(gpu)
    if gpu.bm0_enabled  do vicky2_render_bm0(gpu)
    if gpu.bm1_enabled  do vicky2_render_bm1(gpu)
    return
}

vicky2_render_mouse :: proc(d: ^GPU_Vicky2) {
    source  := d.mouseptr0 if d.pointer_selected == .PTR0 else d.mouseptr1

    for i : u32 = 0; i <= 0xFF; i += 1 {
        color        := source[i]
        d.MOUSEFB[i]  = (transmute(^u32) &d.mouse_lut[color])^
    }

    d.pointer_updated = true
}

vicky2_render_bm0 :: proc(gpu: ^GPU) {
    g         := &gpu.model.(GPU_Vicky2)
   
    max      := u32(g.screen_x_size * g.screen_y_size)
    lut_addr := g.bm0_lut * 1024
    for i := u32(0); i < max; i += 1 {
        lut_index    := g.vram0[g.bm0_pointer + i]
        lut_position := lut_addr + (4 * lut_index)
        g.BM0FB[i] = (transmute(^u32) &g.lut[lut_position])^
    }

}

vicky2_render_bm1 :: proc(gpu: ^GPU) {
    g         := &gpu.model.(GPU_Vicky2)
   
    max      := u32(g.screen_x_size * g.screen_y_size)
    lut_addr := g.bm1_lut * 1024
    for i := u32(0); i < max; i += 1 {
        lut_index    := g.vram0[g.bm1_pointer + i]
        lut_position := lut_addr + (4 * lut_index)
        g.BM1FB[i] = (transmute(^u32) &g.lut[lut_position])^
    }

}

vicky2_render_text :: proc(gpu: ^GPU) {
        g         := &gpu.model.(GPU_Vicky2)

        cursor_x, cursor_y: u32 // row and column of cursor
        text_row_pos:       u32 // beginning of current text row in text memory
        fb_row_pos:         u32 // beginning of current FB   row in memory
        font_pos:           u32 // position in font array (char * 64 + char_line * 8)
        fb_pos:             u32 // position in destination framebuffer
        font_row_pos:       u32 // position of line in current font (=font_line*8 because every line has 8 bytes)

        // that particular counters are used in loops and are mentione here for reference
        //i:                  u32 // counter
        //text_x, text_y:     u32 // row and column of text
        //font_line:          u32 // line in current font

        // placeholders recalculated per row of text, holds values for text_cols loop
        // current max size is 128 columns for 1024x768
        fnttmp: [128]u32    // position in font array, from char value
        fgctmp: [128]u32    // foreground color cache (rgba) for one line
        bgctmp: [128]u32    // background color cache (rgba) for one line
        dsttmp: [128]u32    // position in destination memory array

        // XXX: it should be rather updated on register write?
        // cursor_x       = u32(g.mem[ CURSOR_X_H ]) << 16 | u32(g.mem[ CURSOR_X_L ])
        // cursor_y       = u32(g.mem[ CURSOR_Y_H ]) << 16 | u32(g.mem[ CURSOR_Y_L ])
        // XXX: fix it to g.cursor_x/y in code
        cursor_x = g.cursor_x
        cursor_y = g.cursor_y

        // render text - start
        // I prefer to keep it because it allow to simply re-drawing single line in future,
        // by manupipulating starting point (now 0) and end clause (now <g.text_rows)
        // xxx - bad workaround
            if g.border_enabled {
            g.starting_fb_row_pos = u32(g.screen_x_size) * u32(g.border_y_size) + u32(g.border_x_size)
    } else {
            g.starting_fb_row_pos = 0
    }
        fb_row_pos = g.starting_fb_row_pos
        //fb_row_pos = 0
        //fmt.printf("border %v text_rows %d text_cols %d\n", g.border_enabled, g.text_rows, g.text_cols)
        for text_y in u32(0) ..< g.text_rows { // over lines of text
                text_row_pos = text_y * g.text_cols
                for text_x in u32(0) ..< g.text_cols { // pre-calculate data for x-axis
                        fnttmp[text_x] = g.text[text_row_pos+text_x] * 64 // position in font array
                        dsttmp[text_x] = text_x * 8                     // position of char in dest FB

                        f := g.fg[text_row_pos+text_x] // fg and bg colors
                        b := g.bg[text_row_pos+text_x]

                        if g.cursor_visible && g.cursor_enabled && (cursor_y == text_y) && (cursor_x == text_x) {
                                f = g.cursor_fg
                                b = g.cursor_bg
                                fnttmp[text_x] = g.cursor_character * 64 // XXX precalculate?
                        }

                        //fgctmp[text_x] = g.fg_clut[f]
                        fgctmp[text_x] = (transmute(^u32) &g.fg_clut[f])^
                        if g.overlay_enabled == false {
                                //bgctmp[text_x] = g.bg_clut[b]
                                bgctmp[text_x] = (transmute(^u32) &g.bg_clut[b])^
                        } else {
                                bgctmp[text_x] = 0x000000FF                    // full alph
                        }
                }
                for font_line in u32(0)..<8 { // for every line of text - over 8 lines of font
                        font_row_pos = font_line * 8
                        for text_x in u32(0)..<g.text_cols { // for each line iterate over columns of text
                                font_pos = fnttmp[text_x] + font_row_pos
                                fb_pos   = dsttmp[text_x] + fb_row_pos
                                for i in u32(0)..<8 { // for every font iterate over 8 pixels of font
                                        if g.font[font_pos+i] == 0 {
                                                /*
                                                if g.text_cols == 128 {
//                                                    fmt.printf("fb_row_pos %d pos %d text_x %d i %d\n", fb_row_pos, fb_pos+i, text_x, i)
                                                }*/
                                                g.TFB[fb_pos+i] = bgctmp[text_x]
                                        } else {
                                                g.TFB[fb_pos+i] = fgctmp[text_x]
                                        }
                                }
                        }
                        fb_row_pos += u32(g.screen_x_size)
                }
        }
        // render text - end
}
