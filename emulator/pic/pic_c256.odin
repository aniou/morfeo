
package pic

import "core:fmt"
import "core:log"
import "core:slice"

import "lib:emu"

PIC_C256 :: struct {
    using pic: ^PIC,

    pending:  [IRQ_C256]bool,
    mask:     [IRQ_C256]bool,
    edge:     [IRQ_C256]bool,
    polarity: [IRQ_C256]bool,
}

IRQ_C256_GROUP :: enum {
    FNX0,
    FNX1,
    FNX2,
    FNX3,
}

Register_pic_c256 :: enum u32 {
    INT_PENDING_REG0 = 0x00_0140,    // Interrupt pending #0
    INT_PENDING_REG1 = 0x00_0141,    // Interrupt pending #1
    INT_PENDING_REG2 = 0x00_0142,    // Interrupt pending #2
    INT_PENDING_REG3 = 0x00_0143,    // Interrupt pending #3---FMX Model only
    INT_POL_REG0     = 0x00_0144,    // Interrupt polarity #0
    INT_POL_REG1     = 0x00_0145,    // Interrupt polarity #1
    INT_POL_REG2     = 0x00_0146,    // Interrupt polarity #2
    INT_POL_REG3     = 0x00_0147,    // Interrupt polarity #3---FMX Model only
    INT_EDGE_REG0    = 0x00_0148,    // Enable Edge Detection #0
    INT_EDGE_REG1    = 0x00_0149,    // Enable Edge Detection #1
    INT_EDGE_REG2    = 0x00_014A,    // Enable Edge Detection #2
    INT_EDGE_REG3    = 0x00_014B,    // Enable Edge Detection #3---FMX Model only
    INT_MASK_REG0    = 0x00_014C,    // Enable Interrupt #0
    INT_MASK_REG1    = 0x00_014D,    // Enable Interrupt #1
    INT_MASK_REG2    = 0x00_014E,    // Enable Interrupt #2
    INT_MASK_REG3    = 0x00_014F,    // Enable Interrupt #3---FMX Model only 
}

IRQ_C256 :: enum {
    FNX0_INT00_SOF,
    FNX0_INT01_SOL,
    FNX0_INT02_TMR0,
    FNX0_INT03_TMR1,
    FNX0_INT04_TMR2,
    FNX0_INT05_RTC,
    FNX0_INT06_FCC,
    FNX0_INT07_MOUSE,

    FNX1_INT00_KBD,
    FNX1_INT01_SC0,
    FNX1_INT02_SC1,
    FNX1_INT03_COM2,
    FNX1_INT04_COM1,
    FNX1_INT05_MPU401,
    FNX1_INT06_LPT,
    FNX1_INT07_SDCARD,

    FNX2_INT00_OPL3,
    FNX2_INT01_GABE_INT0,
    FNX2_INT02_GABE_INT1,
    FNX2_INT03_SDMA,
    FNX2_INT04_VDMA,
    FNX2_INT05_GABE_INT2,
    FNX2_INT06_EXT,
    FNX2_INT07_SDCARD_INS,

    FNX3_INT00_OPN2,
    FNX3_INT01_OPM,
    FNX3_INT02_IDE,
    FNX3_INT03_TBD,
    FNX3_INT04_TBD,
    FNX3_INT05_TBD,
    FNX3_INT06_TBD,
    FNX3_INT07_TBD,
}

pic_c256_make :: proc(name: string) -> ^PIC {
    pic          := new(PIC)
    pic.name      = name
    pic.id        = 0
    pic.data      = new([32]u8)
    pic.current   = .NONE
    pic.group     = .GRP_NONE
    //pic.irqs      = M68K_IRQ
    pic.irq_clear = false
    pic.irq_active= false

    pic.read      = pic_c256_read
    pic.write     = pic_c256_write
    pic.trigger   = pic_c256_trigger
    pic.delete    = pic_c256_delete
    /*
    pic.clean     = m68040_clean
    pic.read8     = pic_m68k_read8
    pic.write8    = pic_m68k_write8
    */
    p            := PIC_C256{pic = pic}
    pic.model     = p
    return pic
} 

// Note to myself, because I did it again.
//
// In general there is a tempting desire to use bit_set instead - but 
// thing may fall miserably in future, when main irq processing will
// be done. For example - triggering FNX2_INT07_SDCARD_INS with current
// layout is simply: check mask[...SDCARD_INS], set pending[SDCARD_INS]
//
// With bit_sets things are definitevely simpler when we come to set or
// get, with simple transmute - but it may require splitting IRQs into
// four, separate groups or creating non-trivial selector. Finally it
// will lead to much more complex solution when irq trigger come to play.
//
pic_c256_read :: proc(pic: ^PIC, size: emu.Request_Size, addr_orig, addr: u32) -> (val: u32) {

    if size != .bits_8 do emu.unsupported_read_size(#procedure, pic.name, pic.id, size, addr_orig)

    d         := &pic.model.(PIC_C256)
    switch Register_pic_c256(addr) {
    case .INT_PENDING_REG0:
        val |= 0x01 if d.pending[.FNX0_INT00_SOF         ] else 0
        val |= 0x02 if d.pending[.FNX0_INT01_SOL         ] else 0
        val |= 0x04 if d.pending[.FNX0_INT02_TMR0        ] else 0
        val |= 0x08 if d.pending[.FNX0_INT03_TMR1        ] else 0
        val |= 0x10 if d.pending[.FNX0_INT04_TMR2        ] else 0
        val |= 0x20 if d.pending[.FNX0_INT05_RTC         ] else 0
        val |= 0x40 if d.pending[.FNX0_INT06_FCC         ] else 0
        val |= 0x80 if d.pending[.FNX0_INT07_MOUSE       ] else 0

        //log.debugf("pic0: %6s read   .INT_PENDING_REG0: val %02x", d.name, val)
    case .INT_PENDING_REG1:
        val |= 0x01 if d.pending[.FNX1_INT00_KBD         ] else 0
        val |= 0x02 if d.pending[.FNX1_INT01_SC0         ] else 0
        val |= 0x04 if d.pending[.FNX1_INT02_SC1         ] else 0
        val |= 0x08 if d.pending[.FNX1_INT03_COM2        ] else 0
        val |= 0x10 if d.pending[.FNX1_INT04_COM1        ] else 0
        val |= 0x20 if d.pending[.FNX1_INT05_MPU401      ] else 0
        val |= 0x40 if d.pending[.FNX1_INT06_LPT         ] else 0
        val |= 0x80 if d.pending[.FNX1_INT07_SDCARD      ] else 0
        //log.debugf("pic0: %6s read   .INT_PENDING_REG1: val %02x", d.name, val)
    case .INT_PENDING_REG2:
        val |= 0x01 if d.pending[.FNX2_INT00_OPL3        ] else 0
        val |= 0x02 if d.pending[.FNX2_INT01_GABE_INT0   ] else 0
        val |= 0x04 if d.pending[.FNX2_INT02_GABE_INT1   ] else 0
        val |= 0x08 if d.pending[.FNX2_INT03_SDMA        ] else 0
        val |= 0x10 if d.pending[.FNX2_INT04_VDMA        ] else 0
        val |= 0x20 if d.pending[.FNX2_INT05_GABE_INT2   ] else 0
        val |= 0x40 if d.pending[.FNX2_INT06_EXT         ] else 0
        val |= 0x80 if d.pending[.FNX2_INT07_SDCARD_INS  ] else 0
    case .INT_PENDING_REG3:
        val |= 0x01 if d.pending[.FNX3_INT00_OPN2        ] else 0
        val |= 0x02 if d.pending[.FNX3_INT01_OPM         ] else 0
        val |= 0x04 if d.pending[.FNX3_INT02_IDE         ] else 0
        val |= 0x08 if d.pending[.FNX3_INT03_TBD         ] else 0
        val |= 0x10 if d.pending[.FNX3_INT04_TBD         ] else 0
        val |= 0x20 if d.pending[.FNX3_INT05_TBD         ] else 0
        val |= 0x40 if d.pending[.FNX3_INT06_TBD         ] else 0
        val |= 0x80 if d.pending[.FNX3_INT07_TBD         ] else 0
    case .INT_POL_REG0:
        val |= 0x01 if d.polarity[.FNX0_INT00_SOF        ] else 0
        val |= 0x02 if d.polarity[.FNX0_INT01_SOL        ] else 0
        val |= 0x04 if d.polarity[.FNX0_INT02_TMR0       ] else 0
        val |= 0x08 if d.polarity[.FNX0_INT03_TMR1       ] else 0
        val |= 0x10 if d.polarity[.FNX0_INT04_TMR2       ] else 0
        val |= 0x20 if d.polarity[.FNX0_INT05_RTC        ] else 0
        val |= 0x40 if d.polarity[.FNX0_INT06_FCC        ] else 0
        val |= 0x80 if d.polarity[.FNX0_INT07_MOUSE      ] else 0
    case .INT_POL_REG1:
        val |= 0x01 if d.polarity[.FNX1_INT00_KBD        ] else 0
        val |= 0x02 if d.polarity[.FNX1_INT01_SC0        ] else 0
        val |= 0x04 if d.polarity[.FNX1_INT02_SC1        ] else 0
        val |= 0x08 if d.polarity[.FNX1_INT03_COM2       ] else 0
        val |= 0x10 if d.polarity[.FNX1_INT04_COM1       ] else 0
        val |= 0x20 if d.polarity[.FNX1_INT05_MPU401     ] else 0
        val |= 0x40 if d.polarity[.FNX1_INT06_LPT        ] else 0
        val |= 0x80 if d.polarity[.FNX1_INT07_SDCARD     ] else 0
    case .INT_POL_REG2:
        val |= 0x01 if d.polarity[.FNX2_INT00_OPL3       ] else 0
        val |= 0x02 if d.polarity[.FNX2_INT01_GABE_INT0  ] else 0
        val |= 0x04 if d.polarity[.FNX2_INT02_GABE_INT1  ] else 0
        val |= 0x08 if d.polarity[.FNX2_INT03_SDMA       ] else 0
        val |= 0x10 if d.polarity[.FNX2_INT04_VDMA       ] else 0
        val |= 0x20 if d.polarity[.FNX2_INT05_GABE_INT2  ] else 0
        val |= 0x40 if d.polarity[.FNX2_INT06_EXT        ] else 0
        val |= 0x80 if d.polarity[.FNX2_INT07_SDCARD_INS ] else 0
    case .INT_POL_REG3:
        val |= 0x01 if d.polarity[.FNX3_INT00_OPN2       ] else 0
        val |= 0x02 if d.polarity[.FNX3_INT01_OPM        ] else 0
        val |= 0x04 if d.polarity[.FNX3_INT02_IDE        ] else 0
        val |= 0x08 if d.polarity[.FNX3_INT03_TBD        ] else 0
        val |= 0x10 if d.polarity[.FNX3_INT04_TBD        ] else 0
        val |= 0x20 if d.polarity[.FNX3_INT05_TBD        ] else 0
        val |= 0x40 if d.polarity[.FNX3_INT06_TBD        ] else 0
        val |= 0x80 if d.polarity[.FNX3_INT07_TBD        ] else 0
    case .INT_EDGE_REG0:
        val |= 0x01 if d.edge[.FNX0_INT00_SOF            ] else 0
        val |= 0x02 if d.edge[.FNX0_INT01_SOL            ] else 0
        val |= 0x04 if d.edge[.FNX0_INT02_TMR0           ] else 0
        val |= 0x08 if d.edge[.FNX0_INT03_TMR1           ] else 0
        val |= 0x10 if d.edge[.FNX0_INT04_TMR2           ] else 0
        val |= 0x20 if d.edge[.FNX0_INT05_RTC            ] else 0
        val |= 0x40 if d.edge[.FNX0_INT06_FCC            ] else 0
        val |= 0x80 if d.edge[.FNX0_INT07_MOUSE          ] else 0
    case .INT_EDGE_REG1:
        val |= 0x01 if d.edge[.FNX1_INT00_KBD            ] else 0
        val |= 0x02 if d.edge[.FNX1_INT01_SC0            ] else 0
        val |= 0x04 if d.edge[.FNX1_INT02_SC1            ] else 0
        val |= 0x08 if d.edge[.FNX1_INT03_COM2           ] else 0
        val |= 0x10 if d.edge[.FNX1_INT04_COM1           ] else 0
        val |= 0x20 if d.edge[.FNX1_INT05_MPU401         ] else 0
        val |= 0x40 if d.edge[.FNX1_INT06_LPT            ] else 0
        val |= 0x80 if d.edge[.FNX1_INT07_SDCARD         ] else 0
    case .INT_EDGE_REG2:
        val |= 0x01 if d.edge[.FNX2_INT00_OPL3           ] else 0
        val |= 0x02 if d.edge[.FNX2_INT01_GABE_INT0      ] else 0
        val |= 0x04 if d.edge[.FNX2_INT02_GABE_INT1      ] else 0
        val |= 0x08 if d.edge[.FNX2_INT03_SDMA           ] else 0
        val |= 0x10 if d.edge[.FNX2_INT04_VDMA           ] else 0
        val |= 0x20 if d.edge[.FNX2_INT05_GABE_INT2      ] else 0
        val |= 0x40 if d.edge[.FNX2_INT06_EXT            ] else 0
        val |= 0x80 if d.edge[.FNX2_INT07_SDCARD_INS     ] else 0
    case .INT_EDGE_REG3:
        val |= 0x01 if d.edge[.FNX3_INT00_OPN2           ] else 0
        val |= 0x02 if d.edge[.FNX3_INT01_OPM            ] else 0
        val |= 0x04 if d.edge[.FNX3_INT02_IDE            ] else 0
        val |= 0x08 if d.edge[.FNX3_INT03_TBD            ] else 0
        val |= 0x10 if d.edge[.FNX3_INT04_TBD            ] else 0
        val |= 0x20 if d.edge[.FNX3_INT05_TBD            ] else 0
        val |= 0x40 if d.edge[.FNX3_INT06_TBD            ] else 0
        val |= 0x80 if d.edge[.FNX3_INT07_TBD            ] else 0
    case .INT_MASK_REG0:
        val |= 0x01 if d.mask[.FNX0_INT00_SOF            ] else 0
        val |= 0x02 if d.mask[.FNX0_INT01_SOL            ] else 0
        val |= 0x04 if d.mask[.FNX0_INT02_TMR0           ] else 0
        val |= 0x08 if d.mask[.FNX0_INT03_TMR1           ] else 0
        val |= 0x10 if d.mask[.FNX0_INT04_TMR2           ] else 0
        val |= 0x20 if d.mask[.FNX0_INT05_RTC            ] else 0
        val |= 0x40 if d.mask[.FNX0_INT06_FCC            ] else 0
        val |= 0x80 if d.mask[.FNX0_INT07_MOUSE          ] else 0
    case .INT_MASK_REG1:
        val |= 0x01 if d.mask[.FNX1_INT00_KBD            ] else 0
        val |= 0x02 if d.mask[.FNX1_INT01_SC0            ] else 0
        val |= 0x04 if d.mask[.FNX1_INT02_SC1            ] else 0
        val |= 0x08 if d.mask[.FNX1_INT03_COM2           ] else 0
        val |= 0x10 if d.mask[.FNX1_INT04_COM1           ] else 0
        val |= 0x20 if d.mask[.FNX1_INT05_MPU401         ] else 0
        val |= 0x40 if d.mask[.FNX1_INT06_LPT            ] else 0
        val |= 0x80 if d.mask[.FNX1_INT07_SDCARD         ] else 0
        //log.debugf("pic0: %6s read   .INT_MASK_REG1: val %02x", d.name, val)
    case .INT_MASK_REG2:
        val |= 0x01 if d.mask[.FNX2_INT00_OPL3           ] else 0
        val |= 0x02 if d.mask[.FNX2_INT01_GABE_INT0      ] else 0
        val |= 0x04 if d.mask[.FNX2_INT02_GABE_INT1      ] else 0
        val |= 0x08 if d.mask[.FNX2_INT03_SDMA           ] else 0
        val |= 0x10 if d.mask[.FNX2_INT04_VDMA           ] else 0
        val |= 0x20 if d.mask[.FNX2_INT05_GABE_INT2      ] else 0
        val |= 0x40 if d.mask[.FNX2_INT06_EXT            ] else 0
        val |= 0x80 if d.mask[.FNX2_INT07_SDCARD_INS     ] else 0
    case .INT_MASK_REG3:
        val |= 0x01 if d.mask[.FNX3_INT00_OPN2           ] else 0
        val |= 0x02 if d.mask[.FNX3_INT01_OPM            ] else 0
        val |= 0x04 if d.mask[.FNX3_INT02_IDE            ] else 0
        val |= 0x08 if d.mask[.FNX3_INT03_TBD            ] else 0
        val |= 0x10 if d.mask[.FNX3_INT04_TBD            ] else 0
        val |= 0x20 if d.mask[.FNX3_INT05_TBD            ] else 0
        val |= 0x40 if d.mask[.FNX3_INT06_TBD            ] else 0
        val |= 0x80 if d.mask[.FNX3_INT07_TBD            ] else 0
    }

    return
}

pic_c256_write :: proc(pic: ^PIC, size: emu.Request_Size, addr_orig, addr, val: u32)  {

    if size != .bits_8 do emu.unsupported_write_size(#procedure, pic.name, pic.id, size, addr_orig, val)

    d         := &pic.model.(PIC_C256)
    switch Register_pic_c256(addr) {
    case .INT_PENDING_REG0:
        if (val & 0x01) != 0 do d.pending[.FNX0_INT00_SOF         ] = false 
        if (val & 0x02) != 0 do d.pending[.FNX0_INT01_SOL         ] = false 
        if (val & 0x04) != 0 do d.pending[.FNX0_INT02_TMR0        ] = false 
        if (val & 0x08) != 0 do d.pending[.FNX0_INT03_TMR1        ] = false 
        if (val & 0x10) != 0 do d.pending[.FNX0_INT04_TMR2        ] = false 
        if (val & 0x20) != 0 do d.pending[.FNX0_INT05_RTC         ] = false 
        if (val & 0x40) != 0 do d.pending[.FNX0_INT06_FCC         ] = false 
        if (val & 0x80) != 0 do d.pending[.FNX0_INT07_MOUSE       ] = false 
    case .INT_PENDING_REG1:
        if (val & 0x01) != 0 do d.pending[.FNX1_INT00_KBD         ] = false 
        if (val & 0x02) != 0 do d.pending[.FNX1_INT01_SC0         ] = false 
        if (val & 0x04) != 0 do d.pending[.FNX1_INT02_SC1         ] = false 
        if (val & 0x08) != 0 do d.pending[.FNX1_INT03_COM2        ] = false 
        if (val & 0x10) != 0 do d.pending[.FNX1_INT04_COM1        ] = false 
        if (val & 0x20) != 0 do d.pending[.FNX1_INT05_MPU401      ] = false 
        if (val & 0x40) != 0 do d.pending[.FNX1_INT06_LPT         ] = false 
        if (val & 0x80) != 0 do d.pending[.FNX1_INT07_SDCARD      ] = false 
    case .INT_PENDING_REG2:
        if (val & 0x01) != 0 do d.pending[.FNX2_INT00_OPL3        ] = false
        if (val & 0x02) != 0 do d.pending[.FNX2_INT01_GABE_INT0   ] = false
        if (val & 0x04) != 0 do d.pending[.FNX2_INT02_GABE_INT1   ] = false
        if (val & 0x08) != 0 do d.pending[.FNX2_INT03_SDMA        ] = false
        if (val & 0x10) != 0 do d.pending[.FNX2_INT04_VDMA        ] = false
        if (val & 0x20) != 0 do d.pending[.FNX2_INT05_GABE_INT2   ] = false
        if (val & 0x40) != 0 do d.pending[.FNX2_INT06_EXT         ] = false
        if (val & 0x80) != 0 do d.pending[.FNX2_INT07_SDCARD_INS  ] = false
    case .INT_PENDING_REG3:
        if (val & 0x01) != 0 do d.pending[.FNX3_INT00_OPN2        ] = false
        if (val & 0x02) != 0 do d.pending[.FNX3_INT01_OPM         ] = false
        if (val & 0x04) != 0 do d.pending[.FNX3_INT02_IDE         ] = false
        if (val & 0x08) != 0 do d.pending[.FNX3_INT03_TBD         ] = false
        if (val & 0x10) != 0 do d.pending[.FNX3_INT04_TBD         ] = false
        if (val & 0x20) != 0 do d.pending[.FNX3_INT05_TBD         ] = false
        if (val & 0x40) != 0 do d.pending[.FNX3_INT06_TBD         ] = false
        if (val & 0x80) != 0 do d.pending[.FNX3_INT07_TBD         ] = false
    case .INT_POL_REG0:
        d.polarity[.FNX0_INT00_SOF        ]  = (val & 0x01) != 0
        d.polarity[.FNX0_INT01_SOL        ]  = (val & 0x02) != 0
        d.polarity[.FNX0_INT02_TMR0       ]  = (val & 0x04) != 0
        d.polarity[.FNX0_INT03_TMR1       ]  = (val & 0x08) != 0
        d.polarity[.FNX0_INT04_TMR2       ]  = (val & 0x10) != 0
        d.polarity[.FNX0_INT05_RTC        ]  = (val & 0x20) != 0
        d.polarity[.FNX0_INT06_FCC        ]  = (val & 0x40) != 0
        d.polarity[.FNX0_INT07_MOUSE      ]  = (val & 0x80) != 0
    case .INT_POL_REG1:
        d.polarity[.FNX1_INT00_KBD        ]  = (val & 0x01) != 0
        d.polarity[.FNX1_INT01_SC0        ]  = (val & 0x02) != 0
        d.polarity[.FNX1_INT02_SC1        ]  = (val & 0x04) != 0
        d.polarity[.FNX1_INT03_COM2       ]  = (val & 0x08) != 0
        d.polarity[.FNX1_INT04_COM1       ]  = (val & 0x10) != 0
        d.polarity[.FNX1_INT05_MPU401     ]  = (val & 0x20) != 0
        d.polarity[.FNX1_INT06_LPT        ]  = (val & 0x40) != 0
        d.polarity[.FNX1_INT07_SDCARD     ]  = (val & 0x80) != 0
    case .INT_POL_REG2:
        d.polarity[.FNX2_INT00_OPL3       ]  = (val & 0x01) != 0
        d.polarity[.FNX2_INT01_GABE_INT0  ]  = (val & 0x02) != 0
        d.polarity[.FNX2_INT02_GABE_INT1  ]  = (val & 0x04) != 0
        d.polarity[.FNX2_INT03_SDMA       ]  = (val & 0x08) != 0
        d.polarity[.FNX2_INT04_VDMA       ]  = (val & 0x10) != 0
        d.polarity[.FNX2_INT05_GABE_INT2  ]  = (val & 0x20) != 0
        d.polarity[.FNX2_INT06_EXT        ]  = (val & 0x40) != 0
        d.polarity[.FNX2_INT07_SDCARD_INS ]  = (val & 0x80) != 0
    case .INT_POL_REG3:
        d.polarity[.FNX3_INT00_OPN2       ]  = (val & 0x01) != 0
        d.polarity[.FNX3_INT01_OPM        ]  = (val & 0x02) != 0
        d.polarity[.FNX3_INT02_IDE        ]  = (val & 0x04) != 0
        d.polarity[.FNX3_INT03_TBD        ]  = (val & 0x08) != 0
        d.polarity[.FNX3_INT04_TBD        ]  = (val & 0x10) != 0
        d.polarity[.FNX3_INT05_TBD        ]  = (val & 0x20) != 0
        d.polarity[.FNX3_INT06_TBD        ]  = (val & 0x40) != 0
        d.polarity[.FNX3_INT07_TBD        ]  = (val & 0x80) != 0
    case .INT_EDGE_REG0:
        d.edge[.FNX0_INT00_SOF            ]  = (val & 0x01) != 0
        d.edge[.FNX0_INT01_SOL            ]  = (val & 0x02) != 0
        d.edge[.FNX0_INT02_TMR0           ]  = (val & 0x04) != 0
        d.edge[.FNX0_INT03_TMR1           ]  = (val & 0x08) != 0
        d.edge[.FNX0_INT04_TMR2           ]  = (val & 0x10) != 0
        d.edge[.FNX0_INT05_RTC            ]  = (val & 0x20) != 0
        d.edge[.FNX0_INT06_FCC            ]  = (val & 0x40) != 0
        d.edge[.FNX0_INT07_MOUSE          ]  = (val & 0x80) != 0
    case .INT_EDGE_REG1:
        d.edge[.FNX1_INT00_KBD            ]  = (val & 0x01) != 0
        d.edge[.FNX1_INT01_SC0            ]  = (val & 0x02) != 0
        d.edge[.FNX1_INT02_SC1            ]  = (val & 0x04) != 0
        d.edge[.FNX1_INT03_COM2           ]  = (val & 0x08) != 0
        d.edge[.FNX1_INT04_COM1           ]  = (val & 0x10) != 0
        d.edge[.FNX1_INT05_MPU401         ]  = (val & 0x20) != 0
        d.edge[.FNX1_INT06_LPT            ]  = (val & 0x40) != 0
        d.edge[.FNX1_INT07_SDCARD         ]  = (val & 0x80) != 0
    case .INT_EDGE_REG2:
        d.edge[.FNX2_INT00_OPL3           ]  = (val & 0x01) != 0
        d.edge[.FNX2_INT01_GABE_INT0      ]  = (val & 0x02) != 0
        d.edge[.FNX2_INT02_GABE_INT1      ]  = (val & 0x04) != 0
        d.edge[.FNX2_INT03_SDMA           ]  = (val & 0x08) != 0
        d.edge[.FNX2_INT04_VDMA           ]  = (val & 0x10) != 0
        d.edge[.FNX2_INT05_GABE_INT2      ]  = (val & 0x20) != 0
        d.edge[.FNX2_INT06_EXT            ]  = (val & 0x40) != 0
        d.edge[.FNX2_INT07_SDCARD_INS     ]  = (val & 0x80) != 0
    case .INT_EDGE_REG3:
        d.edge[.FNX3_INT00_OPN2           ]  = (val & 0x01) != 0
        d.edge[.FNX3_INT01_OPM            ]  = (val & 0x02) != 0
        d.edge[.FNX3_INT02_IDE            ]  = (val & 0x04) != 0
        d.edge[.FNX3_INT03_TBD            ]  = (val & 0x08) != 0
        d.edge[.FNX3_INT04_TBD            ]  = (val & 0x10) != 0
        d.edge[.FNX3_INT05_TBD            ]  = (val & 0x20) != 0
        d.edge[.FNX3_INT06_TBD            ]  = (val & 0x40) != 0
        d.edge[.FNX3_INT07_TBD            ]  = (val & 0x80) != 0
    case .INT_MASK_REG0:
        //log.debugf("pic0: %6s write   .INT_MASK_REG0: val %02x", d.name, val)
        d.mask[.FNX0_INT00_SOF            ]  = (val & 0x01) != 0
        d.mask[.FNX0_INT01_SOL            ]  = (val & 0x02) != 0
        d.mask[.FNX0_INT02_TMR0           ]  = (val & 0x04) != 0
        d.mask[.FNX0_INT03_TMR1           ]  = (val & 0x08) != 0
        d.mask[.FNX0_INT04_TMR2           ]  = (val & 0x10) != 0
        d.mask[.FNX0_INT05_RTC            ]  = (val & 0x20) != 0
        d.mask[.FNX0_INT06_FCC            ]  = (val & 0x40) != 0
        d.mask[.FNX0_INT07_MOUSE          ]  = (val & 0x80) != 0
    case .INT_MASK_REG1:
        //log.debugf("pic0: %6s write  .INT_MASK_REG1: val %02x", d.name, val)
        d.mask[.FNX1_INT00_KBD            ]  = (val & 0x01) != 0
        d.mask[.FNX1_INT01_SC0            ]  = (val & 0x02) != 0
        d.mask[.FNX1_INT02_SC1            ]  = (val & 0x04) != 0
        d.mask[.FNX1_INT03_COM2           ]  = (val & 0x08) != 0
        d.mask[.FNX1_INT04_COM1           ]  = (val & 0x10) != 0
        d.mask[.FNX1_INT05_MPU401         ]  = (val & 0x20) != 0
        d.mask[.FNX1_INT06_LPT            ]  = (val & 0x40) != 0
        d.mask[.FNX1_INT07_SDCARD         ]  = (val & 0x80) != 0
    case .INT_MASK_REG2:
        d.mask[.FNX2_INT00_OPL3           ]  = (val & 0x01) != 0
        d.mask[.FNX2_INT01_GABE_INT0      ]  = (val & 0x02) != 0
        d.mask[.FNX2_INT02_GABE_INT1      ]  = (val & 0x04) != 0
        d.mask[.FNX2_INT03_SDMA           ]  = (val & 0x08) != 0
        d.mask[.FNX2_INT04_VDMA           ]  = (val & 0x10) != 0
        d.mask[.FNX2_INT05_GABE_INT2      ]  = (val & 0x20) != 0
        d.mask[.FNX2_INT06_EXT            ]  = (val & 0x40) != 0
        d.mask[.FNX2_INT07_SDCARD_INS     ]  = (val & 0x80) != 0
    case .INT_MASK_REG3:
        d.mask[.FNX3_INT00_OPN2           ]  = (val & 0x01) != 0
        d.mask[.FNX3_INT01_OPM            ]  = (val & 0x02) != 0
        d.mask[.FNX3_INT02_IDE            ]  = (val & 0x04) != 0
        d.mask[.FNX3_INT03_TBD            ]  = (val & 0x08) != 0
        d.mask[.FNX3_INT04_TBD            ]  = (val & 0x10) != 0
        d.mask[.FNX3_INT05_TBD            ]  = (val & 0x20) != 0
        d.mask[.FNX3_INT06_TBD            ]  = (val & 0x40) != 0
        d.mask[.FNX3_INT07_TBD            ]  = (val & 0x80) != 0
    }

    return
}

/*
GABE Interrupt Control Registers ($00:0140 – $00:014B)

There are four types of interrupt control register that GABE provides: pending,
polarity, edge detection, and mask. Each interrupt that is supported has a bit
position in each of the 24 or 32 bits provided by the register types.

Pending
    The pending registers indicate if an interrupt of a particular type has
    been triggered and needs processing. An interrupt handler should also write
    to this register to clear the pending flag, once the interrupt has been
    processed.

Polarity
    This register indicates if the interrupt is triggered by a high or low
    signal on the input to GABE.

Edge
    This register indicates if the interrupt is triggered by an transition
    (edge) or by a high or low value.

Mask
    This register indicates if the associated interrupt will trigger an IRQ to
    the processor. Interrupt signals with a mask bit of 0 will be ignored,
    while those with a mask bit of 1 will trigger an interrupt to the CPU.
*/

pic_c256_internal_trigger :: proc(pic: ^PIC, irq: IRQ_C256)  {
    d         := &pic.model.(PIC_C256)

    d.pending[irq] = true
    //log.debugf("IRQ: %v", irq)

    // there is a problem with handling SOF with rate 60Hz - maybe emulator is too slow?
    if d.mask[irq] == false && irq != .FNX0_INT00_SOF {
        d.irq_active   = true
    } 
    
    return
}

pic_c256_trigger :: proc(pic: ^PIC, irq: IRQ)  {
    #partial switch irq {
    case      .KBD_PS2: pic_c256_internal_trigger(pic, .FNX1_INT00_KBD)
    case  .VICKY_A_SOF: pic_c256_internal_trigger(pic, .FNX0_INT00_SOF)
    case   .RESERVED_5: pic_c256_internal_trigger(pic, .FNX2_INT03_SDMA)    // too bad, too bad we
    case   .RESERVED_6: pic_c256_internal_trigger(pic, .FNX2_INT04_VDMA)    // need abstract irq names
    case          : emu.call_not_implemented(#procedure, fmt.aprintf("%s", irq))
    }
}

pic_c256_delete :: proc(pic: ^PIC) {
    //d         := &pic.model.(PIC_C256)
    //free(d.data)
    free(pic)
}

