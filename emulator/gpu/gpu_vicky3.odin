package gpu

import "core:fmt"
import "core:log"
import "core:os"

import "lib:emu"

// new definitions

VKY3_MCR_TEXT          :: 0x_00_00_00_01  // A B - enable text mode
VKY3_MCR_TEXT_OVERLAY  :: 0x_00_00_00_02  //   B - enable text overlay
VKY3_MCR_GRAPHIC       :: 0x_00_00_00_04  //   B - enable graphic engine
VKY3_MCR_BITMAP        :: 0x_00_00_00_08  //   B - enable bitmap engine
VKY3_MCR_TILE          :: 0x_00_00_00_10  //   B - enable tile engine
VKY3_MCR_SPRITE        :: 0x_00_00_00_20  //   B - enable sprite engine
VKY3_MCR_VIDEO_DISABLE :: 0x_00_00_00_80  // A B - disable video engine

VKY3_MCR_MODE_MASK     :: 0x_00_00_03_00  //   B - video mode (two bits)
VKY3_MCR_DOUBLE_PIXEL  :: 0x_00_00_04_00  //   B - video mode
VKY3_MCR_1024_768      :: 0x_00_00_08_00  // A   - 1024x768 mode

VKY3_MCR_MANUAL_GAMMA  :: 0x_00_01_00_00  // A B -  gamma source selector (DIP or Bit[17])
VKY3_MCR_GAMMA         :: 0x_00_02_00_00  // A B -  gamma state (Bit[17])
VKY3_MCR_SLEEP         :: 0x_00_04_00_00  // A B -  monitor sleep (sync disable)

VKY3_BCR_ENABLE        :: 0x_00_00_00_01
VKY3_BCR_X_SCROLL      :: 0x_00_00_00_70
VKY3_BCR_X_SIZE        :: 0x_00_00_3f_00
VKY3_BCR_Y_SIZE        :: 0x_00_3f_00_00

VKY3_CCR_ENABLE        :: 0x_00_00_00_01
VKY3_CCR_RATE          :: 0x_00_00_00_06
VKY3_CCR_OFFSET        :: 0x_00_00_ff_00
VKY3_CCR_CHARACTER     :: 0x_00_ff_00_00
VKY3_CCR_BG            :: 0x_0f_00_00_00
VKY3_CCR_FG            :: 0x_f0_00_00_00

VKY3_BITMAP            :: 0x_00_00_00_01
VKY3_BITMAP_LUT_MASK   :: 0x_00_00_00_07
VKY3_BITMAP_COLLISION  :: 0x_00_00_00_40

Register :: enum u32 {
    VKY3_MCR        = 0x_00_00,     // A B - master control register
    VKY3_BCR        = 0x_00_04,     // A B - border control register
    VKY3_BRD_COLOR  = 0x_00_08,     // A B - border color register
    VKY3_BGR_COLOR  = 0x_00_0c,     // A B - background color register
    VKY3_CCR        = 0x_00_10,     // A B - cursor control register
    VKY3_CPR        = 0x_00_14,     // A B - cursor position register
    VKY3_IRQ0       = 0x_00_18,     // A B - line interrupt 0 1
    VKY3_IRQ1       = 0x_00_1C,     // A B - line interrupt 2 3
    VKY3_FONT_MGR0  = 0x_00_20,     // A   - font manager 0
    VKY3_FONT_MGR1  = 0x_00_24,     // A   - font manager 0
    VKY3_BM_L0CR    = 0x_01_00,     //   B - bitmap 0 control register
    VKY3_BM_L0PTR   = 0x_01_04,     //   B - bitmap 0 control register
}


CURSOR_BLINK_RATE           :: [4]i32{1000, 500, 250, 200}


GPU_Vicky3 :: struct {
    using gpu: ^GPU,

    vram0:   [dynamic]u8,    // VRAM
    //vram1:   [dynamic]u8,    // VRAM  -- not implemented yet?
    text:    [dynamic]u32,   // text memory
    tc:      [dynamic]u32,   // text color memory
    pointer: [dynamic]u8,    // pointer memory (16 x 16 x 4 bytes)
    lut:     [dynamic]u8,    // LUT memory block (lut0 to lut7 ARGB)

    blut:    [dynamic]u32,   // bitmap LUT cache : 256 colors * 8 banks (lut0 to lut7)
    fg:      [dynamic]u32,   // text foreground LUT cache
    bg:      [dynamic]u32,   // text background LUT cache
    font:    [dynamic]u8,    // font cache       : 256 chars  * 8 lines * 8 columns
    cram:    [dynamic]u8,    // XXX - temporary ram for FG clut/BG clut and others

    fg_clut: [16]u32,         // 16 pre-calculated RGBA colors for text fore-
    bg_clut: [16]u32,         // ...and background

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

vicky3_make :: proc(name: string, id: int) -> ^GPU {
    log.infof("vicky3: gpu%d initialization start, name %s", id, name)

    gpu       := new(GPU)
    gpu.name   = name
    gpu.id     = id
    gpu.read   = vicky3_read
    gpu.write  = vicky3_write
    //gpu.read8  = vicky3_read8
    //gpu.write8 = vicky3_write8
    gpu.delete = vicky3_delete
    gpu.render = vicky3_render
    g         := GPU_Vicky3{gpu = gpu}

    g.vram0   = make([dynamic]u8,  0x20_0000) // 2MB
    //g.vram1   = make([dynamic]u8,  0x20_0000) // 2MB
    g.text    = make([dynamic]u32,    0x4000)
    g.tc      = make([dynamic]u32,    0x4000)
    g.fg      = make([dynamic]u32,    0x4000) // text foreground LUT cache
    g.bg      = make([dynamic]u32,    0x4000) // text backround  LUT cache
    g.lut     = make([dynamic]u8,     0x2000) // 8 * 256 * 4 colors 
    g.blut    = make([dynamic]u32,     0x800)
    g.cram    = make([dynamic]u8,      0x100)
    g.font    = make([dynamic]u8,  0x100*8*8) // font cache 256 chars * 8 lines * 8 columns
    g.pointer = make([dynamic]u8,      0x400) // pointer     16 x 16 x 4 bytes color

    g.TFB     = new([1024*768]u32)            // text framebuffer
    g.BM0FB   = new([1024*768]u32)            // bitmap0 framebuffer
    g.BM1FB   = new([1024*768]u32)            // bitmap1 framebuffer

    // initial values - XXX - should be memory updated too? 
    // maybe they should be set by vicky3_write?
    g.screen_x_size  = 800
    g.screen_y_size  = 600
    g.resolution     = 2 << 8  
    g.screen_resized = false

    g.pixel_size     = 1
    g.cursor_enabled = true
    g.cursor_visible = true
    g.bitmap_enabled = true // xxx: there is no way to change it in vicky3?
    g.text_enabled   = true 

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

    g.delay               = 16   // 16 milliseconds for ~60Hz

    // fake init
    //v.mem[MASTER_CTRL_REG_L] = 0x01
    for _, i in g.text {
        g.text[i] = 35   // u32('#')
        g.fg[i]   = 2    // green in FoenixMCP
        g.bg[i]   = 0    // black in FoenixMCP
    }

    for _, i in g.fg_clut {
        g.fg_clut[i] = u32(0xff00_00ff)
        g.bg_clut[i] = u32(0xffcc_dd00)
    }


    gpu.model  = g
    vicky3_recalculate_screen(g)
    return gpu
}

vicky3_delete :: proc(gpu: ^GPU) {
    g         := &gpu.model.(GPU_Vicky3)

    delete(g.text)
    delete(g.vram0)
    //delete(g.vram1)
    delete(g.tc)
    delete(g.fg)
    delete(g.bg)
    delete(g.lut)
    delete(g.blut)
    delete(g.cram)
    delete(g.font)
    delete(g.pointer)

    free(g.TFB)
    free(g.BM0FB)
    free(g.BM1FB)

    //free(g.gpu)
    free(gpu)

    return
}


vicky3_read :: proc(gpu: ^GPU, size: emu.Request_Size, addr_orig, addr: u32, mode: emu.Mode = .MAIN) -> (val: u32) {
    d := &gpu.model.(GPU_Vicky3)
    #partial switch mode {
    case .MAIN_A: 
        val = vicky3_read_register(d, size, addr_orig, addr, mode)
    case .MAIN_B: 
        val = vicky3_read_register(d, size, addr_orig, addr, mode)
    case .TEXT:
        if size != .bits_8 {
            emu.unsupported_read_size(#procedure, d.name, d.id, size, addr_orig)
        } else {
            val = d.text[addr]
        }
    case .TEXT_COLOR:
        if size != .bits_8 {
            emu.unsupported_read_size(#procedure, d.name, d.id, size, addr_orig)
        } else {
            val = d.tc[addr]
        }
    case .TEXT_FG_LUT:
        if size != .bits_32 {
            emu.unsupported_read_size(#procedure, d.name, d.id, size, addr_orig)
        } else {
		    color := addr >> 2 // every color ARGB bytes, assume 4-byte align
		    val = d.fg_clut[color]
        }

    case .TEXT_BG_LUT:
        if size != .bits_32 {
            emu.unsupported_read_size(#procedure, d.name, d.id, size, addr_orig)
        } else {
		    color := addr >> 2 // every color ARGB bytes, assume 4-byte align
		    val = d.bg_clut[color]
        }

    case .LUT:
		switch size {
        case .bits_8:
        	val = cast(u32) d.lut[addr]
    	case .bits_16:
        	ptr := transmute(^u16be) &d.lut[addr]
        	val  = cast(u32) ptr^
    	case .bits_32:
        	ptr := transmute(^u32be) &d.lut[addr]
        	val  = cast(u32) ptr^
    	}

    case .VRAM0:
		switch size {
        case .bits_8:
        	val = cast(u32) d.vram0[addr]
    	case .bits_16:
        	ptr := transmute(^u16be) &d.vram0[addr]
        	val  = cast(u32) ptr^
    	case .bits_32:
        	ptr := transmute(^u32be) &d.vram0[addr]
        	val  = cast(u32) ptr^
    	}

    case: 
        emu.not_implemented(#procedure, d.name, size, addr_orig)
    }
    return
}


vicky3_write :: proc(gpu: ^GPU, size: emu.Request_Size, addr_orig, addr, val: u32, mode: emu.Mode = .MAIN) {
    d := &gpu.model.(GPU_Vicky3)
    #partial switch mode {
    case .MAIN_A: 
        vicky3_write_register(&d.model.(GPU_Vicky3), size, addr_orig, addr, val, mode)

    case .MAIN_B: 
        vicky3_write_register(&d.model.(GPU_Vicky3), size, addr_orig, addr, val, mode)

    case .TEXT:
        if size != .bits_8 {
            emu.unsupported_write_size(#procedure, d.name, d.id, size, addr_orig, val)
        } else {
            d.text[addr] = val & 0x00_00_00_ff
        }

    case .TEXT_COLOR:
        if size != .bits_8 {
            emu.unsupported_write_size(#procedure, d.name, d.id, size, addr_orig, val)
        } else {
            d.fg[addr] = (val & 0xf0) >> 4
            d.bg[addr] =  val & 0x0f
            d.tc[addr] =  val & 0x00_00_00_ff
        }
        
    case .TEXT_FG_LUT:
        if size != .bits_32 {
            emu.unsupported_write_size(#procedure, d.name, d.id, size, addr_orig, val)
        } else {
		    color := addr >> 2 // every color ARGB bytes, assume 4-byte align
		    d.fg_clut[color] = val
        }

    case .TEXT_BG_LUT:
        if size != .bits_32 {
            emu.unsupported_write_size(#procedure, d.name, d.id, size, addr_orig, val)
        } else {
		    color := addr >> 2 // every color ARGB bytes, assume 4-byte align
		    d.bg_clut[color] = val
        }

    case .FONT_BANK0:
        if size != .bits_8 {
            emu.unsupported_write_size(#procedure, d.name, d.id, size, addr_orig, val)
        } else {
            vicky3_update_font_cache(d, addr, u8(val))  // every bit in font cache is mapped to byte
        }

    case .LUT:
        switch size {
        case .bits_8:
            d.lut[addr] = cast(u8) val
        case .bits_16:
            (transmute(^u16be) &d.lut[addr])^ = cast(u16be) val
        case .bits_32:
            (transmute(^u32be) &d.lut[addr])^ = cast(u32be) val
        }
        
    case .VRAM0:
        switch size {
        case .bits_8:
            d.vram0[addr] = cast(u8) val
        case .bits_16:
            (transmute(^u16be) &d.vram0[addr])^ = cast(u16be) val
        case .bits_32:
            (transmute(^u32be) &d.vram0[addr])^ = cast(u32be) val
        }

    case        : 
        emu.not_implemented(#procedure, d.name, size, addr_orig)
    }
    return
}


@private
vicky3_write_register :: proc(d: ^GPU_Vicky3, size: emu.Request_Size, addr_orig, addr, val: u32, mode: emu.Mode) {
    if size != .bits_32 {
        emu.unsupported_write_size(#procedure, d.name, d.id, size, addr_orig, val)
        return
    }

    reg := Register(addr)
    switch reg {
    case .VKY3_MCR:                             // so far only difference between channel A and B

        if mode == .MAIN_A {

            d.text_enabled = (val & VKY3_MCR_TEXT )         != 0
            d.gpu_enabled  = (val & VKY3_MCR_VIDEO_DISABLE) == 0

            if d.resolution != (val & VKY3_MCR_1024_768) {
                d.resolution     = val & VKY3_MCR_1024_768
                d.screen_resized = true

                switch d.resolution {
                case 0x00:
                    d.screen_x_size = 800
                    d.screen_y_size = 600
                case VKY3_MCR_1024_768:
                    d.screen_x_size = 1024
                    d.screen_y_size = 768
                }

                vicky3_recalculate_screen(d)
            }
            // XXX: Bit[16] gamma selector not implemented
            // XXX: Bit[17] gamma state    not implemented
            // XXX: Bit[18] sync off       not implemented

    } else {

            d.text_enabled    = (val & VKY3_MCR_TEXT )         != 0
            d.overlay_enabled = (val & VKY3_MCR_TEXT_OVERLAY ) != 0
            d.graphic_enabled = (val & VKY3_MCR_GRAPHIC )      != 0
            d.bitmap_enabled  = (val & VKY3_MCR_BITMAP )       != 0
            d.tile_enabled    = (val & VKY3_MCR_TILE )         != 0
            d.sprite_enabled  = (val & VKY3_MCR_SPRITE )       != 0
            d.gpu_enabled     = (val & VKY3_MCR_VIDEO_DISABLE) == 0

            // XXX - double pixel not supported

            log.debugf("gpu%d %s: screen size %d", d.id, d.name, ((val & VKY3_MCR_MODE_MASK) >> 8))
            if d.resolution != (val & VKY3_MCR_MODE_MASK) {
                d.resolution     = val & VKY3_MCR_MODE_MASK
                d.screen_resized = true

                switch ( d.resolution >> 8 ) {
                case 0x00:
                    d.screen_x_size = 640
                    d.screen_y_size = 480
                    d.delay         = 16    // for 60Hz
                case 0x01:
                    // something is wrong here
                case 0x02:
                    d.screen_x_size = 800
                    d.screen_y_size = 600
                    d.delay         = 16    // for 60Hz
                case 0x03:
                    d.screen_x_size = 640
                    d.screen_y_size = 400
                    d.delay         = 14    // for 70Hz
                }

                vicky3_recalculate_screen(d)
            }
            // XXX: Bit[16] gamma selector not implemented
            // XXX: Bit[17] gamma state    not implemented
            // XXX: Bit[18] sync off       not implemented

    }

    case .VKY3_BCR:
        d.border_enabled = (val & VKY3_BCR_ENABLE )       != 0

        if (val & VKY3_BCR_X_SCROLL) != 0 {
            emu.not_implemented(#procedure, "VKY3_A_BCR_X_SCROLL", .bits_32, addr_orig)
        }

        d.border_x_size = i32((val & VKY3_BCR_X_SIZE) >>  8)
        d.border_y_size = i32((val & VKY3_BCR_Y_SIZE) >> 16)
        vicky3_recalculate_screen(d)
        
    case .VKY3_BRD_COLOR:
        // XXX - convert this to BGRA or something?
        d.border_color_b = u8( val & 0x_00_00_00_ff)
        d.border_color_g = u8((val & 0x_00_00_ff_00) >>  8)
        d.border_color_r = u8((val & 0x_00_ff_00_00) >> 16)

    case .VKY3_BGR_COLOR:
        d.bg_color_b = u8( val & 0x_00_00_00_ff)
        d.bg_color_g = u8((val & 0x_00_00_ff_00) >>  8)
        d.bg_color_r = u8((val & 0x_00_ff_00_00) >> 16)

    case .VKY3_CCR:
        d.cursor_enabled   =     (val & VKY3_CCR_ENABLE    ) != 0
        d.cursor_rate      = i32((val & VKY3_CCR_RATE      ) >>  1)   // XXX - why i32?
        d.cursor_character = u32((val & VKY3_CCR_CHARACTER ) >> 16)
        d.cursor_bg        = u32((val & VKY3_CCR_BG        ) >> 24)
        d.cursor_fg        = u32((val & VKY3_CCR_BG        ) >> 28)

        if (val & VKY3_CCR_OFFSET) != 0 {
            emu.not_implemented(#procedure, "VKY3_A_CCR_OFFSET", .bits_32, addr_orig)
        }

    case .VKY3_CPR:
        d.cursor_x = (val & 0x_00_00_ff_ff)
        d.cursor_y = (val & 0x_ff_ff_00_00) >> 16

    case .VKY3_IRQ0:
        emu.not_implemented(#procedure, "VKY3_IRQ0", size, addr_orig)
    case .VKY3_IRQ1:
        emu.not_implemented(#procedure, "VKY3_IRQ1", size, addr_orig)
    case .VKY3_FONT_MGR0:
        emu.not_implemented(#procedure, "VKY3_FONT_MGR0", size, addr_orig)
    case .VKY3_FONT_MGR1:
        emu.not_implemented(#procedure, "VKY3_FONT_MGR1", size, addr_orig)

    case .VKY3_BM_L0CR:
        d.bm0_enabled           = (val & VKY3_BITMAP           ) != 0 
        d.bm0_lut               = (val & VKY3_BITMAP_LUT_MASK  ) >> 1
        d.bm0_collision_enabled = (val & VKY3_BITMAP_COLLISION ) != 0 
        log.debugf("gpu%d %s: bitmap_bm0 %v", d.id, d.name, d.bm0_enabled)

    case .VKY3_BM_L0PTR:
        d.bm0_pointer = val
        // XXX - recalculate bitmap0
    case                 :
        emu.not_implemented(#procedure, "UNKNOWN", size, addr_orig)
    }
}

@private
vicky3_read_register :: proc(d: ^GPU_Vicky3, size: emu.Request_Size, addr_orig, addr: u32, mode: emu.Mode) -> (val: u32) {
    if size != .bits_32 {
        emu.unsupported_read_size(#procedure, d.name, d.id, size, addr_orig)
        return
    }

    reg := Register(addr)
    switch reg {
    case .VKY3_MCR:
        if mode == .MAIN_A {

            val |= VKY3_MCR_TEXT if d.text_enabled else 0                      // Bit[0]
            val |= 0             if d.gpu_enabled  else VKY3_MCR_VIDEO_DISABLE // Bit[7]
            val |= d.resolution                                                // Bit[11]
            val |= 0x_40_00_00_00                                              // Bit[30]  XXX val for 800x600 (lower)

            // XXX: Bit[16] gamma selector not implemented
            // XXX: Bit[17] gamma state    not implemented
            // XXX: Bit[18] sync off       not implemented

        } else {

            val |= VKY3_MCR_TEXT         if d.text_enabled    else 0                       // Bit[0]
            val |= VKY3_MCR_TEXT_OVERLAY if d.overlay_enabled else 0                       // Bit[1]
            val |= VKY3_MCR_GRAPHIC      if d.graphic_enabled else 0                       // Bit[2]
            val |= VKY3_MCR_BITMAP       if d.bitmap_enabled  else 0                       // Bit[3]
            val |= VKY3_MCR_TILE         if d.tile_enabled    else 0                       // Bit[4]
            val |= VKY3_MCR_SPRITE       if d.sprite_enabled  else 0                       // Bit[5]
            // Bit[6] reserved
            val |= 0                     if d.gpu_enabled     else VKY3_MCR_VIDEO_DISABLE  // Bit[7]
            val |= d.resolution                                                            // Bit[8:9]
            // XXX: Bit[10] double pixel not supported
            // Bit[10] reserved (hires on A)
            val |= 0x_00_00_00_00                                              // Bit[14]  XXX val for 800x600 (high)

            // XXX: Bit[16] gamma selector not implemented
            // XXX: Bit[17] gamma state    not implemented
            // XXX: Bit[18] sync off       not implemented

    }
    case .VKY3_BCR:
        val |= VKY3_BCR_ENABLE if d.border_enabled else 0
        val |= (u32(d.border_x_size) <<  8)
        val |= (u32(d.border_y_size) << 16)
        
    case .VKY3_BRD_COLOR:
        val  =  u32(d.border_color_b)
        val |= (u32(d.border_color_g) <<  8)
        val |= (u32(d.border_color_r) << 16)

    case .VKY3_BGR_COLOR:
        val  =  u32(d.bg_color_b)
        val |= (u32(d.bg_color_g) <<  8)
        val |= (u32(d.bg_color_r) << 16)

    case .VKY3_CCR:
        emu.not_implemented(#procedure, "VKY3_CCR", size, addr_orig)

    case .VKY3_CPR:
        val |= d.cursor_x
        val |= d.cursor_y << 16

    case .VKY3_IRQ0:
        emu.not_implemented(#procedure, "VKY3_IRQ0", size, addr_orig)
    case .VKY3_IRQ1:
        emu.not_implemented(#procedure, "VKY3_IRQ1", size, addr_orig)
    case .VKY3_FONT_MGR0:
        emu.not_implemented(#procedure, "VKY3_FONT_MGR0", size, addr_orig)
    case .VKY3_FONT_MGR1:
        emu.not_implemented(#procedure, "VKY3_FONT_MGR1", size, addr_orig)

    case .VKY3_BM_L0CR:
        val |= VKY3_BITMAP           if d.border_enabled        else 0
        val |= VKY3_BITMAP_COLLISION if d.bm0_collision_enabled else 0
        val |= d.bm0_lut << 1

    case .VKY3_BM_L0PTR:
        val = d.bm0_pointer

    case                 :
        emu.not_implemented(#procedure, "UNKNOWN", size, addr_orig)
    }
    return
}

@private
vicky3_b_write_register :: proc(d: ^GPU_Vicky3, size: emu.Request_Size, addr_orig, addr, val: u32) {
    emu.not_implemented(#procedure, d.name, size, addr_orig)
}

@private
vicky3_b_read_register :: proc(d: ^GPU_Vicky3, size: emu.Request_Size, addr_orig, addr: u32) -> (val: u32) {
    emu.not_implemented(#procedure, d.name, size, addr_orig)
    return
}


// GUI-specific
// updates font cache by converting bits to bytes
// position - position of indyvidual byte in font bank
// val      - particular value
@private
vicky3_update_font_cache :: proc(g: ^GPU_Vicky3, position: u32, value: u8) {
    //log.debugf("vicky3: %s update font cache position %d value %d", g.name, position, value)
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


vicky3_recalculate_screen :: proc(gpu: ^GPU) {
    g         := &gpu.model.(GPU_Vicky3)
    if g.border_enabled {
            g.starting_fb_row_pos = u32(g.screen_x_size) * u32(g.border_y_size) + u32(g.border_x_size)
            g.text_rows = u32((g.screen_y_size - g.border_y_size*2) / 8)
    } else {
            g.starting_fb_row_pos = 0
            g.text_rows = u32(g.screen_y_size / 8)
    }

    g.text_cols = u32(g.screen_x_size / 8)
    //g.text_rows = u32(g.screen_y_size / 8)

    log.debugf("vicky3: %s text_rows: %d", g.name, g.text_rows)
    log.debugf("vicky3: %s text_cols: %d", g.name, g.text_cols)
    log.debugf("vicky3: %s border: %v %d %d", g.name, g.border_enabled, g.border_x_size, g.border_y_size)
    log.debugf("vicky3: %s resolution %08x", g.name, g.resolution)
    return
}

vicky3_render :: proc(gpu: ^GPU) {
    if gpu.text_enabled do vicky3_render_text(gpu)
    if gpu.bm0_enabled  do vicky3_render_bm0(gpu)
    if gpu.bm1_enabled  do vicky3_render_bm1(gpu)
    return
}

vicky3_render_bm0 :: proc(gpu: ^GPU) {
    g         := &gpu.model.(GPU_Vicky3)
   
    max := u32(g.screen_x_size * g.screen_y_size)
    for i := u32(0); i < max; i += 1 {
        lut_index    := u32(g.vram0[g.bm0_pointer + i])
        lut_position := (g.bm0_lut * 256) + 4 * lut_index
        g.BM0FB[i] = (transmute(^u32) &g.lut[lut_position])^
    }

}

vicky3_render_bm1 :: proc(gpu: ^GPU) {
    g         := &gpu.model.(GPU_Vicky3)
   
    max := u32(g.screen_x_size * g.screen_y_size)
    for i := u32(0); i < max; i += 1 {
        lut_index    := u32(g.vram0[g.bm1_pointer + i])
        lut_position := (g.bm1_lut * 256) + 4 * lut_index
        g.BM0FB[i] = (transmute(^u32) &g.lut[lut_position])^
    }

}

vicky3_render_text :: proc(gpu: ^GPU) {
        g         := &gpu.model.(GPU_Vicky3)

        cursor_x, cursor_y: u32 // row and column of cursor
        text_x, text_y:     u32 // row and column of text
        text_row_pos:       u32 // beginning of current text row in text memory
        fb_row_pos:         u32 // beginning of current FB   row in memory
        font_pos:           u32 // position in font array (char * 64 + char_line * 8)
        fb_pos:             u32 // position in destination framebuffer
        font_line:          u32 // line in current font
        font_row_pos:       u32 // position of line in current font (=font_line*8 because every line has 8 bytes)
        i:                  u32 // counter

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

                        fgctmp[text_x] = g.fg_clut[f]
                        if g.overlay_enabled == false {
                                bgctmp[text_x] = g.bg_clut[b]
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
