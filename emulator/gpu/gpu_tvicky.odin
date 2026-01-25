package gpu

import "core:fmt"
import "core:log"
import "core:os"
import "core:time"

import "lib:emu"

import "emulator:pic"
import "emulator:ram"

Register_tVicky :: enum u32 {         //       $D000
    TVKY_MCR_L         = 0x_00_00,    // A   - master control register
    TVKY_MCR_H         = 0x_00_01,    // A   - master control register
                                      //     - reserved
                                      //     - reserved
    TVKY_BCR           = 0x_00_04,    // A   - border control register
    TVKY_BRD_COL_B     = 0x_00_05,    // A   - border color Blue
    TVKY_BRD_COL_G     = 0x_00_06,    // A   - border color Green
    TVKY_BRD_COL_R     = 0x_00_07,    // A   - border color Red
    TVKY_BRD_XSIZE     = 0x_00_08,    // A   - border X size, 0-32 (32)
    TVKY_BRD_YSIZE     = 0x_00_09,    // A   - border X size, 0-32 (32)
                                      //     - unknown
                                      //     - unknown
                                      //     - unknown
    TVKY_BGR_COL_B     = 0x_00_0D,    // A   - background color Blue    - graphics mode only
    TVKY_BGR_COL_G     = 0x_00_0E,    // A   - background color Green   - graphics mode only
    TVKY_BGR_COL_R     = 0x_00_0F,    // A   - background color Red     - graphics mode only
    TVKY_CCR           = 0x_00_10,    // A   - cursor control register
    TVKY_TXT_SAPTR     = 0x_00_11,    // A   - offset to change the Starting address of the Text Mode Buffer (in x)
    TVKY_TXT_CUR_CHAR  = 0x_00_12,    // A   - text cursor character
    TVKY_TXT_CUR_CLR   = 0x_00_13,    // A   - text cursor color
    TVKY_TXT_CUR_XL    = 0x_00_14,    // A   - text cursor X position (low)
    TVKY_TXT_CUR_XH    = 0x_00_15,    // A   - text cursor X position (high)
    TVKY_TXT_CUR_YL    = 0x_00_16,    // A   - text cursor Y position (low)
    TVKY_TXT_CUR_YH    = 0x_00_17,    // A   - text cursor Y position (high)

    VKY_LINE_ICR       = 0x_00_18,    // A   -  [0] - Enable Line 0 - WRITE ONLY
    VKY_LINE_CMP_VAL_L = 0x_00_19,    // A   -  Write Only [7:0]
    VKY_LINE_CMP_VAL_H = 0x_00_1A,    // A   -  Write Only [3:0]

    VKY_PIXEL_X_POS_L  = 0x_00_18,    // A    - This is Where on the video line is the Pixel
    VKY_PIXEL_X_POS_H  = 0x_00_19,    // A    - Or what pixel is being displayed when the register is read
    VKY_LINE_Y_POS_L   = 0x_00_1A,    // A    - This is the Line Value of the Raster
    VKY_LINE_Y_POS_H   = 0x_00_1B,
}

// Master Control LOW
TVKY_MCR_TEXT          :: 0x_00_00_00_01  // A   - enable text mode
TVKY_MCR_TEXT_OVERLAY  :: 0x_00_00_00_02  // A   - enable text overlay
TVKY_MCR_GRAPHIC       :: 0x_00_00_00_04  // A   - enable graphic engine
TVKY_MCR_BITMAP        :: 0x_00_00_00_08  // A   - enable bitmap engine
TVKY_MCR_TILE          :: 0x_00_00_00_10  // A   - enable tile engine
TVKY_MCR_SPRITE        :: 0x_00_00_00_20  // A   - enable sprite engine
TVKY_MCR_GAMMA_ENABLE  :: 0x_00_00_00_40  // A   - enable gamma correction
TVKY_MCR_VIDEO_DISABLE :: 0x_00_00_00_80  // A   - disable video engine

// XXX: check it
TVKY_CCR_ENABLE        :: 0x_00_00_00_01  // A   -  cursor enable
TVKY_CCR_RATE_MASK     :: 0x_00_00_00_06  // A   -  flash rate: 00 - 1/Sec, 01 - 2/Sec, 10 - 4/Sec, 11 - 5/Sec

TVKY_BCR_ENABLE        :: 0x_00_00_00_01
TVKY_BCR_X_SCROLL      :: 0x_00_00_00_70  // A   -  border scroll, at bit 4..6 (val: 0-7)  


//CURSOR_BLINK_RATE           :: [4]i32{1000, 500, 250, 200}
CURSOR_BLINK_RATE           := [4]time.Duration{1000 * time.Millisecond,
                                                 500 * time.Millisecond,
                                                 250 * time.Millisecond,
                                                 200 * time.Millisecond}


GPU_tVicky :: struct {
    using gpu: ^GPU,

    text:    [dynamic]u32,   // text memory
    tc:      [dynamic]u32,   // text color memory
    fg:      [dynamic]u32,   // text foreground LUT cache
    bg:      [dynamic]u32,   // text background LUT cache

    m_tclut_fg: [64]u8,
    m_tclut_bg: [64]u8,
    c_tclut_fg: [16]u32, // 16 pre-calculated RGBA colors for text fore-
    c_tclut_bg: [16]u32, // ...and background

    font:    [dynamic]u8,    // font cache       : 256 chars  * 8 lines * 8 columns
    // To Be Checked:
    pointer: [dynamic]u8,    // pointer memory (16 x 16 x 4 bytes)
    lut:     [dynamic]u8,    // LUT memory block (lut0 to lut7 ARGB)
    blut:    [dynamic]u32,   // bitmap LUT cache : 256 colors * 8 banks (lut0 to lut7)


    starting_fb_row_pos: u32,
    text_cols:           u32,
    text_rows:           u32,
    bm0_blut_pos:        u32,
    bm1_blut_pos:        u32,
    bm0_start_addr:      u32,
    bm1_start_addr:      u32,
    pixel_size:          u32,      // 1 for normal, 2 for double - XXX: not used yet
    resolution:          u32,      // for tracking resolution changes
    cursor_enabled:      bool,
    overlay_enabled:     bool,

    pointer_enabled:    bool,
    pointer_selected:   bool,
}

// --------------------------------------------------------------------

make_tvicky :: proc(name: string, dcb: ^emu.DeviceConfig, pic: ^pic.PIC) -> ^GPU {
    log.infof("tvicky: gpu%d initialization start, name %s", 0, name)

    gpu       := new(GPU)
    gpu.name   = name
    gpu.req    = dcb.req
    gpu.pic    = pic

    gpu.read  =    read_tvicky
    gpu.write =   write_tvicky
    gpu.delete = delete_tvicky
    gpu.render = render_tvicky
    g         := GPU_tVicky{gpu = gpu}

    g.text    = make([dynamic]u32,    0x2000)
    g.tc      = make([dynamic]u32,    0x2000)
    g.fg      = make([dynamic]u32,    0x2000) // text foreground LUT cache
    g.bg      = make([dynamic]u32,    0x2000) // text backround  LUT cache
    g.font    = make([dynamic]u8,  0x100*8*8) // font cache 256 chars * 8 lines * 8 columns

    g.TFB     = new([1024*768]u32)            // text    framebuffer (max size)
    g.BM0FB   = new([1024*768]u32)            // bitmap0 framebuffer (max size)
    g.BM1FB   = new([1024*768]u32)            // bitmap1 framebuffer (max size)

    // initial values - XXX - should be memory updated too? 
    // maybe they should be set by tvicky_write?
    g.screen_x_size  = 640
    g.screen_y_size  = 480
    g.resolution     = 2 << 8  
    g.screen_resized = false

    // ok
    g.cursor_rate      = 1
    g.cursor_rate_ms   = CURSOR_BLINK_RATE[g.cursor_rate]
    g.text_enabled     = true
    g.overlay_enabled  = false
    g.graphic_enabled  = false
    g.bitmap_enabled   = true
    g.tile_enabled     = false
    g.sprite_enabled   = false
    g.gamma_enabled    = false
    g.gpu_enabled      = true

    g.pixel_size     = 1
    g.cursor_enabled = true
    g.cursor_visible = true

    g.border_color_b      = 0x20
    g.border_color_g      = 0x00
    g.border_color_r      = 0x20
    g.border_x_size       = 0x20
    g.border_y_size       = 0x20
    g.starting_fb_row_pos = 0x00
    g.text_cols           = 0x00
    g.text_rows           = 0x00
    g.bm0_blut_pos        = 0x00
    g.bm1_blut_pos        = 0x00
    g.bm0_start_addr      = 0x00 // relative from beginning of vram
    g.bm1_start_addr      = 0x00 // relative from beginning of vram
    g.delay               = 16 * time.Millisecond  // 16 milliseconds for ~60Hz

    // looks like tvicky has embedded font
    //font := #load("aniou-sanserif.bin")
    //font := #load("f256jr_font_micah_jan25th.bin")
    font := #load("aniou-f256.bin")
    for val, addr in font {
        tvicky_update_font_cache(&g, u32(addr), u8(val))  // every bit in font cache is mapped to byte
    }

    // fake init
    for _, i in g.text {
        g.text[i] = 35   // u32('#')
        g.fg[i]   = 4    // yellow(?)
        g.bg[i]   = 0    // black
    }

    // initial character (text) foreground LUT
    g.c_tclut_fg = [16]u32 {
		0xff000000,
		0xff800000,
		0xff008000,
		0xff000080,
		0xff808000,
		0xff008080,
		0xff800080,
		0xff808080,
		0xffff4500,
		0xff8b4513,
		0xff200000,
		0xff002000,
		0xff000020,
		0xff202020,
		0xff606060,
		0xffffffff,
    }

    g.c_tclut_bg = [16]u32 {
		0xff000000,
		0xff800000,
		0xff008000,
		0xff000080,
		0xff202000,
		0xff002020,
		0xff200020,
		0xff202020,
		0xffd2691e,
		0xff8b4513,
		0xff200000,
		0xff002000,
		0xff000040,
		0xff303030,
		0xff404040,
		0xffffffff,
    }

    gpu.model  = g
    tvicky_recalculate_screen(g)
    return gpu
}

delete_tvicky :: proc(gpu: ^GPU) {
    g         := &gpu.model.(GPU_tVicky)

    delete(g.text)
    //delete(g.vram1)
    delete(g.tc)
    delete(g.fg)
    delete(g.bg)
    delete(g.lut)
    delete(g.blut)
    delete(g.font)
    delete(g.pointer)

    free(g.TFB)
    free(g.BM0FB)
    free(g.BM1FB)

    //free(g.gpu)
    free(gpu)

    return
}

read_tvicky :: proc(gpu: ^GPU, mode: MODE, addr, ra: u32, region: REGION) -> (out: u32) {
    d    := &gpu.model.(GPU_tVicky)

    if mode != .mode_8 {
        emu.error_read(d.name, .BAD_MODE, mode, addr, ra)
    }

    #partial switch region {
    case .MAIN:         out = read_tvicky_register(d, mode, addr, ra)                                                              
    case .TEXT:         out = d.text[addr]
    case .TEXT_COLOR:   out = d.tc[addr]
    case .TEXT_FG_LUT:  out = u32(d.m_tclut_fg[addr])
    case .TEXT_BG_LUT:  out = u32(d.m_tclut_bg[addr])
    //case .LUT:        out = cast(u32) d.lut[addr]
    //case .VRAM0:      out = d.vram0[addr]
    //case .FONT_BANK0: out = d.fontmem[addr]
    //case .MOUSEPTR0:  out = d.mouseptr0[addr]
    //case .MOUSEPTR1:  out = d.mouseptr1[addr]
    //case .TILEMAP:    out = vicky2_read_tilemap(d, size, busaddr, addr, mode)
    //case .TILESET:    out = vicky2_read_tileset(d, size, busaddr, addr, mode)


    /*
    case .LUT:
        switch size {
        case .mode_8:
            out = cast(u32) d.lut[addr]
        case .mode_16be:
            ptr := transmute(^u16be) &d.lut[addr]
            out  = cast(u32) ptr^
        case .mode_32be:
            ptr := transmute(^u32be) &d.lut[addr]
            out  = cast(u32) ptr^
        }
    */
    case: 
        emu.error_read(d.name, .NOT_IMPL, mode, addr, ra)
    }
    return
}

write_tvicky :: proc(gpu: ^GPU, mode: MODE, addr, ra, val: u32, region: REGION) {
    d    := &gpu.model.(GPU_tVicky)
    if mode != .mode_8 {
        emu.error_write(d.name, .BAD_MODE, mode, addr, ra, val)
    }

    #partial switch region {
    case .MAIN:   
        write_tvicky_register(d, mode, addr, ra, val)
    case .TEXT:                         // IO bank 1
        d.text[addr] = val & 0xff
    case .TEXT_COLOR:                   // IO bank 2
        d.fg[addr] = (val & 0xf0) >> 4
        d.bg[addr] =  val & 0x0f
        d.tc[addr] =  val & 0xff
    case .TEXT_FG_LUT:
        cpos                := addr  & 0xFFFC   // align to every four bytes
        cnum                := addr >> 2        // number of color in LUT cache
        d.m_tclut_fg[cpos+3] = 0xff             // 4th byte of RGBA always 0xFF
        d.m_tclut_fg[addr]   = u8(val)
        d.c_tclut_fg[cnum]   = (transmute(^u32) &d.m_tclut_fg[cpos])^
        //log.debugf("fg_lut %v color %08x addr %d cpos %d", d.m_tclut_fg[cpos:cpos+4], d.c_tclut_fg[cnum], addr, cpos)
    case .TEXT_BG_LUT:
        cpos                := addr  & 0xFFFC   // align to every four bytes
        cnum                := addr >> 2        // number of color in LUT cache
        d.m_tclut_bg[cpos+3] = 0xff             // 4th byte of RGBA always 0xFF
        d.m_tclut_bg[addr]   = u8(val)
        d.c_tclut_bg[cnum]   = (transmute(^u32) &d.m_tclut_bg[cpos])^
        //log.debugf("bg_lut %v color %08x addr %d cpos %d", d.m_tclut_bg[cpos:cpos+4], d.c_tclut_bg[cnum], addr, cpos)

    /*
    case .FONT_BANK0:
        log.debugf("font called %2x", val)
        tvicky_update_font_cache(d, addr, u8(val))  // every bit in font cache is mapped to byte

    case .LUT:
        switch size {
        case .mode_8:
            d.lut[addr] = cast(u8) val
        case .mode_16be:
            (transmute(^u16be) &d.lut[addr])^ = cast(u16be) val
        case .mode_32be:
            (transmute(^u32be) &d.lut[addr])^ = cast(u32be) val
        }
    */
        
    case: 
        emu.error_read(d.name, .NOT_IMPL, mode, addr, ra)
    }
    return
}


@private
write_tvicky_register :: proc(d: ^GPU_tVicky, mode: MODE, addr, ra, val: u32) {                                      
    if mode != .mode_8 {
        emu.error_write(d.name, .BAD_MODE, mode, addr, ra, val)
        return
    }

    register  := Register_tVicky(addr)
    #partial switch register {
    case .TVKY_MCR_L:
        d.text_enabled    = (val & TVKY_MCR_TEXT )         != 0
        d.overlay_enabled = (val & TVKY_MCR_TEXT_OVERLAY ) != 0
        d.graphic_enabled = (val & TVKY_MCR_GRAPHIC )      != 0
        d.bitmap_enabled  = (val & TVKY_MCR_BITMAP )       != 0
        d.tile_enabled    = (val & TVKY_MCR_TILE )         != 0
        d.sprite_enabled  = (val & TVKY_MCR_SPRITE )       != 0
        d.gamma_enabled   = (val & TVKY_MCR_GAMMA_ENABLE)  != 0
        d.gpu_enabled     = (val & TVKY_MCR_VIDEO_DISABLE) == 0
    case .TVKY_BCR:
        d.border_enabled = (val & TVKY_BCR_ENABLE )       != 0

        if (val & TVKY_BCR_X_SCROLL) != 0 {                                                                                                 
            emu.error_read(d.name, .NOT_IMPL, mode, addr, ra)
        }

    case .TVKY_BRD_COL_B: d.border_color_b =  u8(val); if d.border_enabled do tvicky_recalculate_screen(d)
    case .TVKY_BRD_COL_G: d.border_color_g =  u8(val); if d.border_enabled do tvicky_recalculate_screen(d)
    case .TVKY_BRD_COL_R: d.border_color_r =  u8(val); if d.border_enabled do tvicky_recalculate_screen(d)
    case .TVKY_BRD_XSIZE: d.border_x_size  = i32(val); if d.border_enabled do tvicky_recalculate_screen(d)
    case .TVKY_BRD_YSIZE: d.border_y_size  = i32(val); if d.border_enabled do tvicky_recalculate_screen(d)
    case .TVKY_BGR_COL_B: d.bg_color_b     =  u8(val)
    case .TVKY_BGR_COL_G: d.bg_color_g     =  u8(val)
    case .TVKY_BGR_COL_R: d.bg_color_r     =  u8(val)

    case .TVKY_CCR:
        d.cursor_enabled   = (val & TVKY_CCR_ENABLE    ) != 0
        d.cursor_rate      = (val & TVKY_CCR_RATE_MASK ) >> 1
        d.cursor_rate_ms   = CURSOR_BLINK_RATE[d.cursor_rate]
    case .TVKY_TXT_CUR_CHAR:
        d.cursor_character = val
    case .TVKY_TXT_CUR_CLR:                         // warning: in tvicky it does nothing
        d.cursor_bg        =  val & 0x0f
        d.cursor_fg        = (val & 0xf0) >> 4
    case .TVKY_TXT_CUR_XL:
        d.cursor_x        &= 0xFF00
        d.cursor_x        |= (val & 0xFF)
    case .TVKY_TXT_CUR_XH:
        d.cursor_x        &= 0x00FF
        d.cursor_x        |= (val << 8)
    case .TVKY_TXT_CUR_YL:
        d.cursor_y        &= 0xFF00
        d.cursor_y        |= (val & 0xFF)
    case .TVKY_TXT_CUR_YH:
        d.cursor_y        &= 0x00FF
        d.cursor_y        |= (val << 8)

    /*
    TVKY_TXT_SAPTR     = 0x_00_11,    // A   - offset to change the Starting address of the Text Mode Buffer (in x)
    ; Line Interrupt 
    VKY_LINE_IRQ_CTRL_REG   = $D018 ;[0] - Enable Line 0 - WRITE ONLY
    VKY_LINE_CMP_VALUE_LO  = $D019 ;Write Only [7:0]
    VKY_LINE_CMP_VALUE_HI  = $D01A ;Write Only [3:0]
    */
    case:    emu.error_write(d.name, .NOT_IMPL, mode, addr, ra, val)

    }
}

@private
read_tvicky_register :: proc(d: ^GPU_tVicky, mode: MODE, addr, ra: u32) -> (out: u32) {
    if mode != .mode_32be {
        emu.error_read(d.name, .BAD_MODE, mode, addr, ra)
        return
    }

    reg  := Register_tVicky(addr)
    #partial switch reg {
    case                 :
        emu.error_read(d.name, .NOT_IMPL, mode, addr, ra)
    }
    return
}

// GUI-specific
// updates font cache by converting bits to bytes
// position - position of indyvidual byte in font bank
// val      - particular value
@private
tvicky_update_font_cache :: proc(g: ^GPU_tVicky, position: u32, value: u8) {
       log.debugf("tvicky: %s update font cache position %04x value %08b", g.name, position, value)
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


tvicky_recalculate_screen :: proc(gpu: ^GPU) {
    g         := &gpu.model.(GPU_tVicky)
    if g.border_enabled {
            g.starting_fb_row_pos = u32(g.screen_x_size) * u32(g.border_y_size) + u32(g.border_x_size)
            g.text_rows = u32((g.screen_y_size - g.border_y_size*2) / 8)
    } else {
            g.starting_fb_row_pos = 0
            g.text_rows = u32(g.screen_y_size / 8)
    }

    g.text_cols = u32(g.screen_x_size / 8)
    //g.text_rows = u32(g.screen_y_size / 8)

    log.debugf("tvicky: %s text_rows: %d", g.name, g.text_rows)
    log.debugf("tvicky: %s text_cols: %d", g.name, g.text_cols)
    log.debugf("tvicky: %s border: %v %d %d", g.name, g.border_enabled, g.border_x_size, g.border_y_size)
    log.debugf("tvicky: %s resolution %08x", g.name, g.resolution)
    log.debugf("tvicky: %s text_enabled %v", g.name, g.text_enabled)
    return
}

render_tvicky :: proc(gpu: ^GPU) {
    gpu.pic->trigger(.VICKY_A_SOF)
    if gpu.text_enabled do tvicky_render_text(gpu)
    //if gpu.bm0_enabled  do tvicky_render_bm0(gpu)
    //if gpu.bm1_enabled  do tvicky_render_bm1(gpu)
    return
}

/*
tvicky_render_bm0 :: proc(gpu: ^GPU) {
    g         := &gpu.model.(GPU_tVicky)
   
    max := u32(g.screen_x_size * g.screen_y_size)
    for i := u32(0); i < max; i += 1 {
        lut_index    := u32(g.vram0[g.bm0_pointer + i])
        lut_position := (g.bm0_lut * 256) + 4 * lut_index
        g.BM0FB[i] = (transmute(^u32) &g.lut[lut_position])^
    }

}

tvicky_render_bm1 :: proc(gpu: ^GPU) {
    g         := &gpu.model.(GPU_tVicky)
   
    max := u32(g.screen_x_size * g.screen_y_size)
    for i := u32(0); i < max; i += 1 {
        lut_index    := u32(g.vram0[g.bm1_pointer + i])
        lut_position := (g.bm1_lut * 256) + 4 * lut_index
        g.BM0FB[i] = (transmute(^u32) &g.lut[lut_position])^
    }

}
*/

tvicky_render_text :: proc(gpu: ^GPU) {
        g         := &gpu.model.(GPU_tVicky)
        
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

                        if g.cursor_visible && g.cursor_enabled && (g.cursor_y == text_y) && (g.cursor_x == text_x) {
                                //f = g.cursor_fg - on tiny vicky there is no separate cursor color
                                //b = g.cursor_bg
                                fnttmp[text_x] = g.cursor_character * 64 // XXX precalculate?
                        }

                        fgctmp[text_x] = g.c_tclut_fg[f]
                        if g.overlay_enabled == false {
                                bgctmp[text_x] = g.c_tclut_bg[b]
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
//                                              fmt.printf("fb_row_pos %d pos %d text_x %d i %d\n", fb_row_pos, fb_pos+i, text_x, i)
                                            } */
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
