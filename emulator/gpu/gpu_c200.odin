package gpu

import "core:fmt"
import "core:log"
import "core:os"
import "core:time"

import "lib:emu"

import "emulator:pic"

// Master Control LOW
C200_MCR_TEXT          :: 0x_01           // A   - enable text mode

// Master Control HIGH
C200_MODE_MASK         :: 0x_01           // A   - video mode: 0 - 640x480 (Clock @ 25.175Mhz), 1 - 800x600 (Clock @ 40Mhz)
C200_MODE_640_480      :: 0x_00
C200_MODE_800_600      :: 0x_01
C200_DOUBLE_PIXEL      :: 0x_02           // A   - double pixel (0 - no, 2 - yes)

C200_BCR_ENABLE        :: 0x_01           // A   -  border visible 0 - disable, 1 - enable
C200_BCR_X_SCROLL      :: 0x_70           // A   -  border scroll, at bit 4..6 (val: 0-7)

C200_CCR_ENABLE        :: 0x_01           // A   -  cursor enable
C200_CCR_RATE_MASK     :: 0x_06           // A   -  flash rate: 00 - 1/Sec, 01 - 2/Sec, 10 - 4/Sec, 11 - 5/Sec
C200_CCR_FONT_PAGE0    :: 0x_08           // A   -  font page 0 or 1 - in reality not supported
C200_CCR_FONT_PAGE1    :: 0x_10           // A   -  font page 0 or 1 - in reality not supported:

// Base: 0xAE_0000 Read Only (32 Bytes Card ID - READ ONLY)
ID_CARD_Register :: enum u32 {
    ID_NAME_ASCII      = 0x_0000,    // 15 Characters + $00
    ID_NAME_ASCII_END  = 0x_000F,    // 15 Characters + $00 - last character
    ID_VENDOR_ID_Lo    = 0x_0010,    // Foenix Project Reserved ID: $F0E1
    ID_VENDOR_ID_Hi    = 0x_0011,
    ID_CARD_ID_Lo      = 0x_0012,    // $9236 - C200-EVID 
    ID_CARD_ID_Hi      = 0x_0013,
    //ID_CARD_CLASS_Lo   = 0x_0014,    // TBD
    //ID_CARD_CLASS_Hi   = 0x_0015,    // TBD
    //ID_CARD_SUBCLSS_Lo = 0x_0016,    // TBD
    //ID_CARD_SUBCLSS_Hi = 0x_0017,    // TBD
    //ID_CARD_UNDEFINED0 = 0x_0018,    // TBD
    //ID_CARD_UNDEFINED1 = 0x_0019,    // TBD
    ID_CARD_HW_Rev     = 0x_001A,    // 00 - in Hex
    ID_CARD_FPGA_Rev   = 0x_001B,    // 00 - in Hex
    //ID_CARD_UNDEFINED2 = 0x_001C,    // TBD
    //ID_CARD_UNDEFINED3 = 0x_001D,    // TBD
    //ID_CARD_CHKSUM0    = 0x_001E,    // Not Supported Yet
    //ID_CARD_CHKSUM1    = 0x_001F,    // Not Supported Ye
}

// base 0xAE_1E00
C200_Register :: enum u32 {
    C200_MCR_L         = 0x_00_00,    // A   - master control register
    C200_MCR_H         = 0x_00_01,    // A   - master control register

    C200_BCR           = 0x_00_04,    // A   - border control register
    C200_BRD_COL_B     = 0x_00_05,    // A   - border color Blue
    C200_BRD_COL_G     = 0x_00_06,    // A   - border color Green
    C200_BRD_COL_R     = 0x_00_07,    // A   - border color Red
    C200_BRD_XSIZE     = 0x_00_08,    // A   - border X size, 0-32 (32)
    C200_BRD_YSIZE     = 0x_00_09,    // A   - border X size, 0-32 (32)

    C200_CCR           = 0x_00_10,    // A   - cursor control register
    C200_TXT_CUR_CHAR  = 0x_00_12,    // A   - text cursor character
    C200_TXT_CUR_CLR   = 0x_00_13,    // A   - text cursor color
    C200_TXT_CUR_XL    = 0x_00_14,    // A   - text cursor X position (low)
    C200_TXT_CUR_XH    = 0x_00_15,    // A   - text cursor X position (high)
    C200_TXT_CUR_YL    = 0x_00_16,    // A   - text cursor Y position (low)
    C200_TXT_CUR_YH    = 0x_00_17,    // A   - text cursor Y position (high)

    C200_CHIP_NUM_L    = 0x_00_1C,     //     - read only value
    C200_CHIP_NUM_H    = 0x_00_1D,     //     - read only value
    C200_CHIP_VER_L    = 0x_00_1E,     //     - read only value
    C200_CHIP_VER_H    = 0x_00_1F,     //     - read only value

}

GPU_C200 :: struct {
    using gpu: ^GPU,

    text:      [dynamic]u32,    // text  memory
    tc:        [dynamic]u32,    // color memory
    fontmem :   [dynamic]u32,    // font memory
    font:        [dynamic]u8,    // font cache       : 256 chars  * 8 lines * 8 columns

    fg_clut:     [16][4]u8,    // 16 pre-calculated RGBA colors for text fore-
    bg_clut:     [16][4]u8,    // ...and background

    fg:          [dynamic]u32,    // text foreground LUT cache
    bg:          [dynamic]u32,    // text background LUT cache



    starting_fb_row_pos: u32,
    text_cols:           u32,
    text_rows:           u32,
    resolution:          u32,   // for tracking resolution changes
    cursor_enabled:      bool,
    bm0_enabled:         bool,
    bm1_enabled:         bool,
    overlay_enabled:     bool,

    evid_name:          [0x10]u32,

}

// --------------------------------------------------------------------

// XXX - vram amount isn't used at all - maybe it should be passed in Config?
C200_make :: proc(name: string, pic: ^pic.PIC, id: int, vram: int, c: ^emu.Config) -> ^GPU {
    log.infof("C200: gpu%d initialization start, name %s", id, name)

    gpu       := new(GPU)
    gpu.name   = name
    gpu.id     = id
    gpu.pic    = pic            // not used in C200
    gpu.read   = C200_read
    gpu.write  = C200_write
    gpu.delete = C200_delete
    gpu.render = C200_render

    g         := GPU_C200{gpu = gpu}

    g.text      = make([dynamic]u32,    0x2000) // text memory
    g.tc        = make([dynamic]u32,    0x2000) // text color memory
    g.fg        = make([dynamic]u32,    0x2000) // text foreground LUT cache
    g.bg        = make([dynamic]u32,    0x2000) // text backround  LUT cache
    g.font      = make([dynamic]u8,  0x100*8*8) // font cache 256 chars * 8 lines * 8 columns
    g.fontmem   = make([dynamic]u32,     0x800) // font bank0 memory

    g.TFB     = new([1024*768]u32)            // text framebuffer     - for max size

    g.screen_x_size      = 800                if .DIP6 not_in c.dipoff else 640
    g.screen_y_size      = 600                if .DIP6 not_in c.dipoff else 480
    g.resolution         = C200_MODE_800_600  if .DIP6 not_in c.dipoff else C200_MODE_640_480
    g.screen_resized     = false

    g.cursor_enabled     = true
    g.cursor_visible     = true
    g.text_enabled       = true 
    g.bm0_enabled        = false        // no BM0 in C200
    g.bm1_enabled        = false        // no BM0 in C200
    g.overlay_enabled    = false        // always false in C200

    g.border_color_b       = 0x20
    g.border_color_g       = 0x00
    g.border_color_r       = 0x20
    g.border_x_size        = 0x20
    g.border_y_size        = 0x20
    g.border_scroll_offset = 0x00 // XXX: not used yet
    g.starting_fb_row_pos  = 0x00
    g.text_cols            = 0x00
    g.text_rows            = 0x00

    g.evid_name            = {'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','\000'}
    g.delay                = 16 * time.Millisecond  // 16 milliseconds for ~60Hz XXX - to be checked

    // fake init just for showin something right after up
    for _, i in g.text {
        g.text[i] = 35   // u32('#')
        g.fg[i]   = 2    // green in FoenixMCP
        g.bg[i]   = 0    // black in FoenixMCP
    }

    // initial character (text) foreground LUT
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

    // initial character (text) background LUT
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

    gpu.model  = g
    C200_recalculate_screen(g)
    return gpu
}

C200_delete :: proc(gpu: ^GPU) {
    g         := &gpu.model.(GPU_C200)

    delete(g.text)
    delete(g.tc)
    delete(g.fg)
    delete(g.bg)
    delete(g.font)
    delete(g.fontmem)

    free(g.TFB)
    free(gpu)
    return
}

C200_read :: proc(gpu: ^GPU, size: BITS, base, busaddr: u32, mode: emu.Region = .MAIN) -> (val: u32) {
    d    := &gpu.model.(GPU_C200)
    addr := busaddr - base

    if size != .bits_8 {
        emu.unsupported_read_size(#procedure, d.name, d.id, size, busaddr)
    }

    #partial switch mode {
    case .MAIN:       val = C200_read_register(d, size, busaddr, addr, mode)
    case .TEXT:       val = d.text[addr]
    case .TEXT_COLOR: val = d.tc[addr]
    case .FONT_BANK0: val = d.fontmem[addr]
    case .ID_CARD:    val = C200_read_id_card(d, size, busaddr, addr, mode)
    case .TEXT_FG_LUT:
        color := addr >> 2 // every color ARGB bytes, assume 4-byte align
        pos   := addr  & 3 // position in 32-bit variable
        val = u32(d.fg_clut[color][pos])

    case .TEXT_BG_LUT:
        color := addr >> 2 // every color ARGB bytes, assume 4-byte align
        pos   := addr  & 3 // position in 32-bit variable
        val = u32(d.bg_clut[color][pos])

    case: 
        emu.read_not_implemented(#procedure, d.name, size, busaddr)
    }
    return
}


C200_write :: proc(gpu: ^GPU, size: BITS, base, busaddr, val: u32, mode: emu.Region = .MAIN) {
    d    := &gpu.model.(GPU_C200)
    addr := busaddr - base

    if size != .bits_8 {
        emu.unsupported_write_size(#procedure, d.name, d.id, size, busaddr, val)
    } 

    #partial switch mode {
    case .MAIN:    C200_write_register(&d.model.(GPU_C200), size, busaddr, addr, val, mode)
    case .TEXT:    d.text[addr] = val & 0x00_00_00_ff
    case .TILEMAP: C200_write_register(d, size, busaddr, addr, val, mode)
    case .TILESET: C200_write_register(d, size, busaddr, addr, val, mode)

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
        C200_update_font_cache(d, addr, u8(val))  // every bit in font cache is mapped to byte

    case        : 
        emu.write_not_implemented(#procedure, d.name, size, busaddr, val)
    }
    return
}


@private
C200_write_register :: proc(d: ^GPU_C200, size: BITS, busaddr, addr, val: u32, mode: emu.Region) {

    if size != .bits_8 {
        emu.unsupported_write_size(#procedure, d.name, d.id, size, busaddr, val)
        return
    }

    reg := C200_Register(addr)
    switch reg {
    case .C200_MCR_L:
        d.text_enabled    = (val & C200_MCR_TEXT )         != 0

    case .C200_MCR_H:
        if d.resolution != (val & C200_MODE_MASK) {

            d.resolution     = val & C200_MODE_MASK
            d.screen_resized = true

            switch d.resolution {
            case C200_MODE_640_480:     // 0
                d.screen_x_size = 640
                d.screen_y_size = 480
                d.delay         = 16  * time.Millisecond   // 16 for 60Hz, 14 for 70Hz
            case C200_MODE_800_600:     // 1
                d.screen_x_size = 800
                d.screen_y_size = 600
                d.delay         = 16  * time.Millisecond   // for 60Hz
            }
            C200_recalculate_screen(d)
        }

    case .C200_BCR:
        d.border_enabled = (val & C200_BCR_ENABLE )       != 0

        if (val & C200_BCR_X_SCROLL) != 0 {
            emu.write_not_implemented(#procedure, "C200_A_BCR_X_SCROLL", size, busaddr, val)
        }

    case .C200_BRD_COL_B: d.border_color_b =  u8(val); if d.border_enabled do C200_recalculate_screen(d)
    case .C200_BRD_COL_G: d.border_color_g =  u8(val); if d.border_enabled do C200_recalculate_screen(d)
    case .C200_BRD_COL_R: d.border_color_r =  u8(val); if d.border_enabled do C200_recalculate_screen(d)
    case .C200_BRD_XSIZE: d.border_x_size  = i32(val); if d.border_enabled do C200_recalculate_screen(d)
    case .C200_BRD_YSIZE: d.border_y_size  = i32(val); if d.border_enabled do C200_recalculate_screen(d)

    case .C200_CCR:
        d.cursor_enabled   =     (val & C200_CCR_ENABLE    ) != 0
        d.cursor_rate      = i32((val & C200_CCR_RATE_MASK ) >> 1)   // XXX - why i32?

        if (val & C200_CCR_FONT_PAGE0) != 0 {
            emu.write_not_implemented(#procedure, "C200_CCR_FONT_PAGE0", size, busaddr, val)
        }
        if (val & C200_CCR_FONT_PAGE1) != 0 {
            emu.write_not_implemented(#procedure, "C200_CCR_FONT_PAGE1", size, busaddr, val)
        }

    case .C200_TXT_CUR_CHAR: d.cursor_character = val
    case .C200_TXT_CUR_CLR:     
        d.cursor_bg        =  val & 0x0f
        d.cursor_fg        = (val & 0xf0) >> 4

    case .C200_TXT_CUR_XL: d.cursor_x  = val
    case .C200_TXT_CUR_XH:
    case .C200_TXT_CUR_YL: d.cursor_y  = val
    case .C200_TXT_CUR_YH: 
    case .C200_CHIP_NUM_L:
    case .C200_CHIP_NUM_H:
    case .C200_CHIP_VER_L:
    case .C200_CHIP_VER_H:
    case                 : emu.write_not_implemented(#procedure, "UNKNOWN",         size, busaddr, val)
    }
}

@private
C200_read_id_card :: proc(d: ^GPU_C200, size: BITS, busaddr, addr: u32, mode: emu.Region) -> (val: u32) {

    switch ID_CARD_Register(addr) {
    case .ID_NAME_ASCII ..= .ID_NAME_ASCII_END     : val = 00    // 15 Characters + $00
    case .ID_VENDOR_ID_Lo    : val = 0xe1  // Foenix Project Reserved ID: $F0E1
    case .ID_VENDOR_ID_Hi    : val = 0xf0
    case .ID_CARD_ID_Lo      : val = 0xc8  // $9236 - C200-EVID - XXX? bad value?
    case .ID_CARD_ID_Hi      : val = 0x00
    case .ID_CARD_HW_Rev     : val =    0
    case .ID_CARD_FPGA_Rev   : val =    0
    }
    return
}

@private
C200_read_register :: proc(d: ^GPU_C200, size: BITS, busaddr, addr: u32, mode: emu.Region) -> (val: u32) {

    switch C200_Register(addr) {
    case .C200_MCR_L: val |= C200_MCR_TEXT          if d.text_enabled    else 0           // Bit[0]
    case .C200_MCR_H: val |= C200_MODE_800_600  if  d.resolution == C200_MODE_800_600  else 0
    case .C200_BCR:
        val |= C200_BCR_ENABLE if d.border_enabled else 0
        val |= (u32(d.border_scroll_offset) <<  4)
        
    case .C200_BRD_COL_B: val  =  u32(d.border_color_b)
    case .C200_BRD_COL_G: val  =  u32(d.border_color_g)
    case .C200_BRD_COL_R: val  =  u32(d.border_color_r)
    case .C200_BRD_XSIZE: val  =  u32(d.border_x_size)
    case .C200_BRD_YSIZE: val  =  u32(d.border_y_size)

    case .C200_CCR:
        val |= C200_CCR_ENABLE if d.cursor_enabled else 0
        val |= u32(d.cursor_rate >> 1)

    case .C200_TXT_CUR_CHAR: 
        val = d.cursor_character

    case .C200_TXT_CUR_CLR:
        val  = d.cursor_bg
        val |= d.cursor_fg << 4

    case .C200_TXT_CUR_XL: val = d.cursor_x
    case .C200_TXT_CUR_XH: val = 0
    case .C200_TXT_CUR_YL: val = d.cursor_y
    case .C200_TXT_CUR_YH: val = 0
    case .C200_CHIP_NUM_L: val = 0 // XXX - update it
    case .C200_CHIP_NUM_H: val = 0 // XXX - update it
    case .C200_CHIP_VER_L: val = 0 // XXX - update it
    case .C200_CHIP_VER_H: val = 0 // XXX - update it

    case                 : emu.read_not_implemented(#procedure, "UNKNOWN", size, busaddr)
    }
    return
}


// GUI-specific
// updates font cache by converting bits to bytes
// position - position of indyvidual byte in font bank
// val      - particular value
@private
C200_update_font_cache :: proc(g: ^GPU_C200, position: u32, value: u8) {
       //log.debugf("C200: %s update font cache position %d value %d", g.name, position, value)
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


C200_recalculate_screen :: proc(gpu: ^GPU) {
    g         := &gpu.model.(GPU_C200)
    if g.border_enabled {
            g.starting_fb_row_pos = u32(g.screen_x_size) * u32(g.border_y_size) + u32(g.border_x_size)
            g.text_rows = u32((g.screen_y_size - g.border_y_size*2) / 8)
    } else {
            g.starting_fb_row_pos = 0
            g.text_rows = u32(g.screen_y_size / 8)
    }

    g.text_cols = u32(g.screen_x_size / 8)
    //g.text_rows = u32(g.screen_y_size / 8)

    log.debugf("C200: %s text_rows: %d", g.name, g.text_rows)
    log.debugf("C200: %s text_cols: %d", g.name, g.text_cols)
    log.debugf("C200: %s border: %v %d %d", g.name, g.border_enabled, g.border_x_size, g.border_y_size)
    log.debugf("C200: %s resolution %08x", g.name, g.resolution)
    return
}

// ----------------------------------------------------------------------------------------------------------

C200_render :: proc(gpu: ^GPU) {
    if gpu.text_enabled do C200_render_text(gpu)
    return
}


C200_render_text :: proc(gpu: ^GPU) {
        g         := &gpu.model.(GPU_C200)

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
        //fmt.printf("border %v text_rows %d text_cols %d\n", g.border_enabled, g.text_rows, g.text_cols)
        for text_y in u32(0) ..< g.text_rows { // over lines of text
                text_row_pos = text_y * g.text_cols
                for text_x in u32(0) ..< g.text_cols { // pre-calculate data for x-axis
                        fnttmp[text_x] = g.text[text_row_pos+text_x] * 64 // position in font array
                        dsttmp[text_x] = text_x * 8                       // position of char in dest FB

                        f := g.fg[text_row_pos+text_x] // fg and bg colors
                        b := g.bg[text_row_pos+text_x]

                        if g.cursor_visible && g.cursor_enabled && (cursor_y == text_y) && (cursor_x == text_x) {
                                f = g.cursor_fg
                                b = g.cursor_bg
                                fnttmp[text_x] = g.cursor_character * 64 // XXX precalculate?
                        }

                        fgctmp[text_x] = (transmute(^u32) &g.fg_clut[f])^
   
                        if g.overlay_enabled == false {
                                bgctmp[text_x] = (transmute(^u32) &g.bg_clut[b])^
                        } else {
                                bgctmp[text_x] = 0x000000FF                    // full alpha
                        }
                }
                for font_line in u32(0)..<8 { // for every line of text - over 8 lines of font
                        font_row_pos = font_line * 8
                        for text_x in u32(0)..<g.text_cols { // for each line iterate over columns of text
                                font_pos = fnttmp[text_x] + font_row_pos
                                fb_pos   = dsttmp[text_x] + fb_row_pos
                                for i in u32(0)..<8 { // for every font iterate over 8 pixels of font
                                        if g.font[font_pos+i] == 0 {
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
