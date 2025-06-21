
package pic

import "core:log"

import "lib:emu"

// memory map, valid for:
//
// MODEL_FOENIX_A2560K          - base 0xFE_C0_0100
// MODEL_FOENIX_GENX
// MODEL_FOENIX_A2560X
// MODEL_FOENIX_A2560U          - base 0x00_B0_0100
// MODEL_FOENIX_A2560U_PLUS

PENDING_GRP0_B	:: 0x00		// VICKY
PENDING_GRP0_A	:: 0x01		// VICKY
PENDING_GRP1_B	:: 0x02		// GAVIN
PENDING_GRP1_A	:: 0x03		// GAVIN
PENDING_GRP2_B	:: 0x04		// BEATRIX
PENDING_GRP2_A	:: 0x05		// BEATRIX
POL_GRP0    	:: 0x08		// not used
POL_GRP1    	:: 0x0A		// not used
POL_GRP2    	:: 0x0C		// not used
EDGE_GRP0   	:: 0x10		// not used
EDGE_GRP1   	:: 0x12		// not used
EDGE_GRP2   	:: 0x14     // not used
MASK_GRP0_B 	:: 0x18		// VICKY
MASK_GRP0_A 	:: 0x19		// VICKY
MASK_GRP1_B 	:: 0x1A		// GAVIN
MASK_GRP1_A 	:: 0x1B		// GAVIN
MASK_GRP2_B 	:: 0x1C		// BEATRIX
MASK_GRP2_A 	:: 0x1D		// BEATRIX

// word of warning: IPL in Motorola are inverted, so if manual
// says '000 means NMI' that, in fact, means 'autovector 7'.
// and '111 means no-interrupt' and thus there is no 'autovec 0'

IRQ :: enum {
    NONE,               // IPL 111 or spurious
    IRQ1,               // IPL 110
    IRQ2,               // IPL 101
    IRQ3,               // IPL 100
    IRQ4,               // IPL 011
    IRQ5,               // IPL 010
    IRQ6,               // IPL 001
    NMI,                // IPL 000, lvl 7

    VICKY_A_SOF,        // Vicky A interrupts
    VICKY_A_SOL,
    VICKY_A_COL_SPR,
    VICKY_A_COL_BM,
    VICKY_A_VDMA,
    VICKY_A_COL_TILE,
    VICKY_A_RESERVED,
    VICKY_A_HOTPLUG,

    VICKY_B_SOF,        // Vicky B interrupts
    VICKY_B_SOL,
    VICKY_B_COL_SPR,
    VICKY_B_COL_BM,
    VICKY_B_VDMA,
    VICKY_B_COL_TILE,
    VICKY_B_RESERVED,
    VICKY_B_HOTPLUG,

    KBD_PS2,            // SuperIO - PS/2 Keyboard
    KBD_A2560K,         // SuperIO - A2560K Built in keyboard (Mo)
    MOUSE,              // SuperIO - PS/2 Mouse
    COM1,               // SuperIO - COM1
    COM2,               // SuperIO - COM2
    LPT1,               // SuperIO - LPT1
    FDC,                // SuperIO - Floppy Drive Controller
    MIDI,               // SuperIO - MIDI

    TIMER0,             // Timer 0, Clocked with the CPU Clock
    TIMER1,             // Timer 1, Clocked with the CPU Clock
    TIMER2,             // Timer 2, Clocked with the CPU Clock
    TIMER3,             // Timer 3, Clocked with the SOF Channel A
    TIMER4,             // Timer 4, Clocked with the SOF Channel B
    RESERVED_3,         // Reserved
    RESERVED_4,         // Reserved
    RTC,                // Real Time Clock

    PATA,               // IDE/PATA Hard drive interrupt
    SDC_INS,            // SD card inserted
    SDC,                // SD card controller
    OPM_INT,            // Internal OPM
    OPN2_EXT,           // External OPN
    OPL3_EXT,           // External OPL
    RESERVED_5,         // Reserved
    RESERVED_6,         // Reserved

    BEATRIX_0,          // Beatrix 0
    BEATRIX_1,          // Beatrix 1
    BEATRIX_2,          // Beatrix 2
    BEATRIX_3,          // Beatrix 3
    RESERVED_7,         // Reserved
    DAC1_PB,            // DAC1 Playback Done (48K)
    RESERVED_8,         // Reserved
    DAC0_PB,            // DAC0 Playback Done (44.1K)

}

IRQ_GROUP :: enum {
    GRP_NONE,
    GRP_0A,
    GRP_0B,
    GRP_1A,
    GRP_1B,
    GRP_2A,
    GRP_2B,
}

IRQ_MASK :: [IRQ_GROUP][8]IRQ {
    .GRP_NONE = {
        .NONE, 
        .IRQ1, 
        .IRQ2, 
        .IRQ3, 
        .IRQ4, 
        .IRQ5, 
        .IRQ6, 
        .NMI,
    },

    .GRP_0A = {
        .VICKY_A_SOF, 
        .VICKY_A_SOL, 
        .VICKY_A_COL_SPR, 
        .VICKY_A_COL_BM, 
        .VICKY_A_VDMA, 
        .VICKY_A_COL_TILE, 
        .VICKY_A_RESERVED, 
        .VICKY_A_HOTPLUG, 
    },

    .GRP_0B = {
        .VICKY_B_SOF, 
        .VICKY_B_SOL, 
        .VICKY_B_COL_SPR, 
        .VICKY_B_COL_BM, 
        .VICKY_B_VDMA, 
        .VICKY_B_COL_TILE, 
        .VICKY_B_RESERVED, 
        .VICKY_B_HOTPLUG, 
    },

    .GRP_1A = {
        .KBD_PS2, 
        .KBD_A2560K, 
        .MOUSE, 
        .COM1, 
        .COM2, 
        .LPT1, 
        .FDC, 
        .MIDI, 
    },

    .GRP_1B = {
        .TIMER0, 
        .TIMER1, 
        .TIMER2, 
        .TIMER3, 
        .TIMER4, 
        .RESERVED_3, 
        .RESERVED_4, 
        .RTC, 
    },

    .GRP_2A = {
        .PATA, 
        .SDC_INS, 
        .SDC, 
        .OPM_INT, 
        .OPN2_EXT, 
        .OPL3_EXT, 
        .RESERVED_5, 
        .RESERVED_6, 
    },

    .GRP_2B = {
        .BEATRIX_0, 
        .BEATRIX_1, 
        .BEATRIX_2, 
        .BEATRIX_3, 
        .RESERVED_7, 
        .DAC1_PB, 
        .RESERVED_8, 
        .DAC0_PB, 
    },
}

Irq_table :: struct {
    group:  IRQ_GROUP,
    prio:   IRQ,
    vector: int,
    mask:   u8,
}

M68K_IRQ :: [IRQ]Irq_table {
    .NONE             = Irq_table{.GRP_NONE, .NONE, 24, 0x01},   // IPL 111 or spurious
    .IRQ1             = Irq_table{.GRP_NONE, .IRQ1, 25, 0x02},   // IPL 110  BEATRIX group B
    .IRQ2             = Irq_table{.GRP_NONE, .IRQ2, 26, 0x03},   // IPL 101  BEATRIX group A
    .IRQ3             = Irq_table{.GRP_NONE, .IRQ3, 27, 0x04},   // IPL 100  GAVIN   group B
    .IRQ4             = Irq_table{.GRP_NONE, .IRQ4, 28, 0x10},   // IPL 011  GAVIN   group A
    .IRQ5             = Irq_table{.GRP_NONE, .IRQ5, 29, 0x20},   // IPL 010, VICKY A group B
    .IRQ6             = Irq_table{.GRP_NONE, .IRQ6, 30, 0x40},   // IPL 001, VICKY B - not used in A2560U
    .NMI              = Irq_table{.GRP_NONE, .NMI,  31, 0x80},   // IPL 000, lvl 7

    .VICKY_B_SOF      = Irq_table{.GRP_0B, .IRQ6, 30, 0x01},     // Starf Of Frame
    .VICKY_B_SOL      = Irq_table{.GRP_0B, .IRQ6, 30, 0x02},     // Start Of Line
    .VICKY_B_COL_SPR  = Irq_table{.GRP_0B, .IRQ6, 30, 0x02},     // Sprite Collision
    .VICKY_B_COL_BM   = Irq_table{.GRP_0B, .IRQ6, 30, 0x08},     // Bitmap Collision
    .VICKY_B_VDMA     = Irq_table{.GRP_0B, .IRQ6, 30, 0x10},     // VDMA
    .VICKY_B_COL_TILE = Irq_table{.GRP_0B, .IRQ6, 30, 0x20},     // Tile Collision
    .VICKY_B_RESERVED = Irq_table{.GRP_0B, .IRQ6, 30, 0x40},     // Reserved
    .VICKY_B_HOTPLUG  = Irq_table{.GRP_0B, .IRQ6, 30, 0x80},     // Hotplug

    .VICKY_A_SOF      = Irq_table{.GRP_0A, .IRQ5, 29, 0x01},     // Starf Of Frame
    .VICKY_A_SOL      = Irq_table{.GRP_0A, .IRQ5, 29, 0x02},     // Start Of Line
    .VICKY_A_COL_SPR  = Irq_table{.GRP_0A, .IRQ5, 29, 0x05},     // Sprite Collision
    .VICKY_A_COL_BM   = Irq_table{.GRP_0A, .IRQ5, 29, 0x08},     // Bitmap Collision
    .VICKY_A_VDMA     = Irq_table{.GRP_0A, .IRQ5, 29, 0x10},     // VDMA
    .VICKY_A_COL_TILE = Irq_table{.GRP_0A, .IRQ5, 29, 0x20},     // Tile Collision
    .VICKY_A_RESERVED = Irq_table{.GRP_0A, .IRQ5, 29, 0x40},     // Reserved
    .VICKY_A_HOTPLUG  = Irq_table{.GRP_0A, .IRQ5, 29, 0x80},     // Hotplug

    .KBD_PS2          = Irq_table{.GRP_1A, .IRQ4, 64, 0x01},     // SuperIO - PS/2 Keyboard
    .KBD_A2560K       = Irq_table{.GRP_1A, .IRQ4, 65, 0x02},     // SuperIO - A2560K Built in keyboard (Mo)
    .MOUSE            = Irq_table{.GRP_1A, .IRQ4, 66, 0x04},     // SuperIO - PS/2 Mouse
    .COM1             = Irq_table{.GRP_1A, .IRQ4, 67, 0x08},     // SuperIO - COM1
    .COM2             = Irq_table{.GRP_1A, .IRQ4, 68, 0x10},     // SuperIO - COM2
    .LPT1             = Irq_table{.GRP_1A, .IRQ4, 69, 0x20},     // SuperIO - LPT1
    .FDC              = Irq_table{.GRP_1A, .IRQ4, 70, 0x40},     // SuperIO - Floppy Drive Controller
    .MIDI             = Irq_table{.GRP_1A, .IRQ4, 71, 0x80},     // SuperIO - MIDI

    .TIMER0           = Irq_table{.GRP_1B, .IRQ3, 72, 0x01},     // Timer 0, Clocked with the CPU Clock
    .TIMER1           = Irq_table{.GRP_1B, .IRQ3, 73, 0x02},     // Timer 1, Clocked with the CPU Clock
    .TIMER2           = Irq_table{.GRP_1B, .IRQ3, 74, 0x02},     // Timer 2, Clocked with the CPU Clock
    .TIMER3           = Irq_table{.GRP_1B, .IRQ3, 75, 0x08},     // Timer 3, Clocked with the SOF Channel A
    .TIMER4           = Irq_table{.GRP_1B, .IRQ3, 76, 0x10},     // Timer 4, Clocked with the SOF Channel B
    .RESERVED_3       = Irq_table{.GRP_1B, .IRQ3, 77, 0x20},     // Reserved
    .RESERVED_4       = Irq_table{.GRP_1B, .IRQ3, 78, 0x40},     // Reserved
    .RTC              = Irq_table{.GRP_1B, .IRQ3, 79, 0x80},     // Real Time Clock

    .PATA             = Irq_table{.GRP_2A, .IRQ2, 80, 0x01},     // IDE/PATA Hard drive interrupt
    .SDC_INS          = Irq_table{.GRP_2A, .IRQ2, 81, 0x02},     // SD card inserted
    .SDC              = Irq_table{.GRP_2A, .IRQ2, 82, 0x02},     // SD card controller
    .OPM_INT          = Irq_table{.GRP_2A, .IRQ2, 83, 0x08},     // Internal OPM
    .OPN2_EXT         = Irq_table{.GRP_2A, .IRQ2, 84, 0x10},     // External OPN
    .OPL3_EXT         = Irq_table{.GRP_2A, .IRQ2, 85, 0x20},     // External OPL
    .RESERVED_5       = Irq_table{.GRP_2A, .IRQ2, 86, 0x40},     // Reserved
    .RESERVED_6       = Irq_table{.GRP_2A, .IRQ2, 87, 0x80},     // Reserved

    .BEATRIX_0        = Irq_table{.GRP_2B, .IRQ1, 88, 0x01},     // Beatrix 0
    .BEATRIX_1        = Irq_table{.GRP_2B, .IRQ1, 89, 0x02},     // Beatrix 1
    .BEATRIX_2        = Irq_table{.GRP_2B, .IRQ1, 90, 0x02},     // Beatrix 2
    .BEATRIX_3        = Irq_table{.GRP_2B, .IRQ1, 91, 0x08},     // Beatrix 3
    .RESERVED_7       = Irq_table{.GRP_2B, .IRQ1, 92, 0x10},     // Reserved
    .DAC1_PB          = Irq_table{.GRP_2B, .IRQ1, 93, 0x20},     // DAC1 Playback Done (48K)
    .RESERVED_8       = Irq_table{.GRP_2B, .IRQ1, 94, 0x40},     // Reserved
    .DAC0_PB          = Irq_table{.GRP_2B, .IRQ1, 95, 0x80},     // DAC0 Playback Done (44.1K)
}

PIC_M68K :: struct {
    using pic: ^PIC
}

pic_m68k_make :: proc(name: string) -> ^PIC {
    pic          := new(PIC)
    pic.name      = name
    pic.id        = 0
    pic.data      = new([32]u8)
    pic.current   = .NONE
    pic.group     = .GRP_NONE
    pic.irqs      = M68K_IRQ
    pic.irq_clear = false
    pic.irq_active= false

    pic.trigger   = m68040_trigger
    pic.clean     = m68040_clean
    pic.read8     = pic_m68k_read8
    pic.write8    = pic_m68k_write8
    pic.read      = pic_m68k_read
    pic.write     = pic_m68k_write
    pic.delete    = pic_m68k_delete

    p            := PIC_M68K{pic = pic}
    pic.model     = p
    return pic
}

// XXX - workaround
pic_m68k_write :: proc(d: ^PIC, size: emu.Bitsize, addr_orig, addr, val: u32) {
    //d         := &pic.model.(PIC_M68K)
    switch size {
    case .bits_8: 
        pic_m68k_write8(d, addr, u8(val))
    case .bits_16:
        pic_m68k_write8(d, addr  , u8(val >> 8))
        pic_m68k_write8(d, addr+1, u8(val))
    case .bits_32:
        pic_m68k_write8(d, addr  , u8(val >> 24))
        pic_m68k_write8(d, addr+1, u8(val >> 16))
        pic_m68k_write8(d, addr+2, u8(val >> 8))
    }
    return
}

pic_m68k_read :: proc(d: ^PIC, size: emu.Bitsize, addr_orig, addr: u32) -> (val: u32) {
    //d         := &pic.model.(PIC_M68K)
    switch size {
    case .bits_8: 
        return cast(u32) pic_m68k_read8(d, addr)
    case .bits_16:
        val = u32(pic_m68k_read8(d, addr  )) << 8 |
              u32(pic_m68k_read8(d, addr+1))
    case .bits_32:
        val = u32(pic_m68k_read8(d, addr  )) << 24 |
              u32(pic_m68k_read8(d, addr+1)) << 16 |
              u32(pic_m68k_read8(d, addr+2)) <<  8 |
              u32(pic_m68k_read8(d, addr+3))
    }
    return
}


pic_m68k_read8 :: proc(pic: ^PIC, addr: u32) -> (val: u8) {
    d         := &pic.model.(PIC_M68K)
    val = 0
	switch addr {
	case PENDING_GRP0_A:
	case PENDING_GRP0_B:
	case PENDING_GRP1_A:
	case PENDING_GRP1_B:
	case PENDING_GRP2_A:
	case PENDING_GRP2_B:
	case MASK_GRP0_A:
	case MASK_GRP0_B:
	case MASK_GRP1_A:
	case MASK_GRP1_B:
	case MASK_GRP2_A:
	case MASK_GRP2_B:
	case:
		log.warnf("%s: read8      at 0x %04X:%04X not implemented", d.name, u16(addr >> 16), u16(addr & 0x0000_ffff))
        return
    }
    val = d.data[addr]
    return
}

// there is an assumption:
// if there is a clear bit on IRQ that is processed then clear 
// marker of 'irq in progress' too

pic_m68k_clear_irq :: proc(pic: ^PIC, group: IRQ_GROUP, val, reg: u8) {
    d         := &pic.model.(PIC_M68K)
    if d.current == .NONE {
        return
    }

    mask_group := IRQ_MASK
    for v in mask_group[group] {
        mask := d.irqs[v].mask
        log.debugf("pic0: mask %02x %04b:%04b reg %04b:%04b", mask, (mask >> 4), (mask & 0x0f), (reg >> 4), (reg & 0x0f))

        if val & mask == mask {  // does not change register

        /*
        if reg & mask == 0 {     // register already 0?
            log.debugf("  already 0")
            continue
        }
        log.debugf("pic0: mask %02x %04b:%04b", mask, (mask >> 4), (mask & 0x0f))
        */

            // XXX: optimize it
            if (d.current == v) & (d.group == group) {
                log.debugf("pic0: I found a potential IRQ to cancel: %s", v)
                d.current    = .NONE
                d.group      = .GRP_NONE
                d.irq_clear  = true
                d.irq_active = false
            } else {
                log.debugf("pic0: not processed, thus not cancel not needed %s", v)
                d.current   = .NONE
                d.group     = .GRP_NONE
                d.irq_clear = true
                d.irq_active = false
            }
        }
    }
}


pic_m68k_write8 :: proc(pic: ^PIC, addr: u32, val: u8) {
    d         := &pic.model.(PIC_M68K)
    log.debugf("pic0: write8 addr %d val %d", addr, val)
	switch addr {
	case PENDING_GRP0_A:
        pic_m68k_clear_irq(d, .GRP_0A, val, d.data[addr])
        d.data[addr] = d.data[addr] & (~val)
	case PENDING_GRP0_B:
        pic_m68k_clear_irq(d, .GRP_0B, val, d.data[addr])
        d.data[addr] = d.data[addr] & (~val)
	case PENDING_GRP1_A:
        pic_m68k_clear_irq(d, .GRP_1A, val, d.data[addr])
        d.data[addr] = d.data[addr] & (~val)
	case PENDING_GRP1_B:
        pic_m68k_clear_irq(d, .GRP_1B, val, d.data[addr])
        d.data[addr] = d.data[addr] & (~val)
	case PENDING_GRP2_A:
        pic_m68k_clear_irq(d, .GRP_2A, val, d.data[addr])
        d.data[addr] = d.data[addr] & (~val)
	case PENDING_GRP2_B:
        pic_m68k_clear_irq(d, .GRP_2B, val, d.data[addr])
        d.data[addr] = d.data[addr] & (~val)
	case MASK_GRP0_A:
        d.data[addr] = val
	case MASK_GRP0_B:
        d.data[addr] = val
	case MASK_GRP1_A:
        d.data[addr] = val
	case MASK_GRP1_B:
        d.data[addr] = val
	case MASK_GRP2_A:
        d.data[addr] = val
	case MASK_GRP2_B:
        d.data[addr] = val
	case:
		log.warnf("%s: write8 0x%02x at 0x %04X:%04X not implemented", d.name, val, u16(addr >> 16), u16(addr & 0x0000_ffff))
    }
}

m68040_trigger :: proc(pic: ^PIC, i: IRQ) {
    d         := &pic.model.(PIC_M68K)
    requested := d.irqs[i]

    // test if IRQ is masked
    masked   := u8(0)
    switch requested.group {
        case .GRP_0A:   masked = requested.mask & d.data[MASK_GRP0_A]
        case .GRP_0B:   masked = requested.mask & d.data[MASK_GRP0_B]
        case .GRP_1A:   masked = requested.mask & d.data[MASK_GRP1_A]
        case .GRP_1B:   masked = requested.mask & d.data[MASK_GRP1_B]
        case .GRP_2A:   masked = requested.mask & d.data[MASK_GRP2_A]
        case .GRP_2B:   masked = requested.mask & d.data[MASK_GRP2_B]
        case .GRP_NONE: log.warnf("pic0: %s undefined mask group %s for %s", d.name, requested.group, i)
    } 
    
    if masked != 0 {
        log.debugf("pic0: %s irq %s masked: %08b", d.name, i, d.data[MASK_GRP1_A])
        log.debugf("pic0: %s irq %s masked: %08b", d.name, i, d.data[MASK_GRP1_B])
        return
    }

    // test if there is already processed irq
    if requested.prio <=  d.irqs[d.current].prio {
        log.debugf("pic0: %s irq with highest prio pending (%v>%v)", d.name, d.current, i)
        return
    }

    switch requested.group {
        case .GRP_0A:   d.data[PENDING_GRP0_A] = requested.mask | d.data[PENDING_GRP0_A]
        case .GRP_0B:   d.data[PENDING_GRP0_A] = requested.mask | d.data[PENDING_GRP0_B]
        case .GRP_1A:   d.data[PENDING_GRP0_A] = requested.mask | d.data[PENDING_GRP1_A]
        case .GRP_1B:   d.data[PENDING_GRP0_A] = requested.mask | d.data[PENDING_GRP1_B]
        case .GRP_2A:   d.data[PENDING_GRP0_A] = requested.mask | d.data[PENDING_GRP2_A]
        case .GRP_2B:   d.data[PENDING_GRP0_A] = requested.mask | d.data[PENDING_GRP2_B]
        case .GRP_NONE: log.warnf("pic0: %s undefined mask group %s for %s", d.name, requested.group, i)
    } 

    d.current = i
    d.group   = d.irqs[i].group
    d.irq     = uint(d.irqs[i].prio)
    d.vector  = uint(d.irqs[i].vector)
    log.debugf("pic0: %s irq %s triggered)", d.name, i)
}

// probably not needed
m68040_clean :: proc(pic: ^PIC) {
    d         := &pic.model.(PIC_M68K)
    d.current   = .NONE
    d.group     = .GRP_NONE
    d.irq_clear = false
}

pic_m68k_delete :: proc(pic: ^PIC) {
    d         := &pic.model.(PIC_M68K)
    free(d.data)
    free(d)
}
