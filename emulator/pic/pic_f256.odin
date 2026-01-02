
package pic

import "core:fmt"
import "core:log"
import "core:slice"

import "lib:emu"

PIC_F256 :: struct {
    using pic: ^PIC,

    pending:  [IRQ_F256]bool,
    mask:     [IRQ_F256]bool,
    edge:     [IRQ_F256]bool,
    polarity: [IRQ_F256]bool,
}

Register_pic_f256 :: enum u32 {
    INT_PENDING_REG0 = 0x00_0000,    // Interrupt pending #0
    INT_PENDING_REG1 = 0x00_0001,    // Interrupt pending #1
    INT_PENDING_REG2 = 0x00_0002,    // Interrupt pending #2
    
    INT_POL_REG0     = 0x00_0004,    // Interrupt polarity #0
    INT_POL_REG1     = 0x00_0005,    // Interrupt polarity #1
    INT_POL_REG2     = 0x00_0006,    // Interrupt polarity #2
    
    INT_EDGE_REG0    = 0x00_0008,    // Enable Edge Detection #0
    INT_EDGE_REG1    = 0x00_0009,    // Enable Edge Detection #1
    INT_EDGE_REG2    = 0x00_000A,    // Enable Edge Detection #2
    
    INT_MASK_REG0    = 0x00_000C,    // Enable Interrupt #0
    INT_MASK_REG1    = 0x00_000D,    // Enable Interrupt #1
    INT_MASK_REG2    = 0x00_000E,    // Enable Interrupt #2
}

IRQ_F256 :: enum {
    GRP0_INT00_SOF,
    GRP0_INT01_SOL,
    GRP0_INT02_PS2_KBD,
    GRP0_INT03_PS2_MOUSE,
    GRP0_INT04_TIMER0,
    GRP0_INT05_TIMER1,
    // reserved
    GRP0_INT07_CART,

    GRP1_INT00_UART,
    // reserverd
    //
    //
    GRP1_INT04_RTC,
    GRP1_INT05_VIA0,
    GRP1_INT06_VIA1,    // f256k - local keyboard
    GRP1_INT07_SDC_INS,

    GRP2_INT00_IEC_DATA,
    GRP2_INT01_IEC_CLOCK,
    GRP2_INT02_IEC_ATN,
    GRP2_INT03_IEC_SREQ,
    // reserved * 4

}

pic_f256_make :: proc(name: string) -> ^PIC {
    pic          := new(PIC)
    pic.name      = name
    pic.id        = 0
    pic.data      = new([32]u8)
    pic.current   = .NONE
    pic.group     = .GRP_NONE
    //pic.irqs      = M68K_IRQ
    pic.irq_clear = false
    pic.irq_active= false

    pic.nread     = pic_f256_read
    pic.nwrite    = pic_f256_write
    pic.trigger   = pic_f256_trigger
    pic.delete    = pic_f256_delete
    
    p            := PIC_F256{pic = pic}
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
pic_f256_read :: proc(pic: ^PIC, ba: ADDR) -> (val: u32) {

    if ba.size != .bits_8 {
        emu.unsupported_read_size(#procedure, pic.name, ba)
        return
    }

    addr      := ba.ea - ba.base
    d         := &pic.model.(PIC_F256)

    switch Register_pic_f256(addr) {
    case .INT_PENDING_REG0:
        val |= 0x01 if d.pending[.GRP0_INT00_SOF         ] else 0
        val |= 0x02 if d.pending[.GRP0_INT01_SOL         ] else 0
        val |= 0x04 if d.pending[.GRP0_INT02_PS2_KBD     ] else 0
        val |= 0x08 if d.pending[.GRP0_INT03_PS2_MOUSE   ] else 0
        val |= 0x10 if d.pending[.GRP0_INT04_TIMER0      ] else 0
        val |= 0x20 if d.pending[.GRP0_INT05_TIMER1      ] else 0
        // reserved
        val |= 0x80 if d.pending[.GRP0_INT07_CART        ] else 0
        //log.debugf("pic0: %6s read   .INT_PENDING_REG0: val %02x", d.name, val)
    case .INT_PENDING_REG1:
        val |= 0x01 if d.pending[.GRP1_INT00_UART        ] else 0
        // reserved
        // reserved
        // reserved
        val |= 0x10 if d.pending[.GRP1_INT04_RTC         ] else 0
        val |= 0x20 if d.pending[.GRP1_INT05_VIA0        ] else 0
        val |= 0x40 if d.pending[.GRP1_INT06_VIA1        ] else 0
        val |= 0x80 if d.pending[.GRP1_INT07_SDC_INS     ] else 0
        //log.debugf("pic0: %6s read   .INT_PENDING_REG1: val %02x", d.name, val)
    case .INT_PENDING_REG2:
        val |= 0x01 if d.pending[.GRP2_INT00_IEC_DATA    ] else 0
        val |= 0x02 if d.pending[.GRP2_INT01_IEC_CLOCK   ] else 0
        val |= 0x04 if d.pending[.GRP2_INT02_IEC_ATN     ] else 0
        val |= 0x08 if d.pending[.GRP2_INT03_IEC_SREQ    ] else 0
        // reserved
        // reserved
        // reserved
        // reserved
    case .INT_POL_REG0:
        val |= 0x01 if d.polarity[.GRP0_INT00_SOF         ] else 0
        val |= 0x02 if d.polarity[.GRP0_INT01_SOL         ] else 0
        val |= 0x04 if d.polarity[.GRP0_INT02_PS2_KBD     ] else 0
        val |= 0x08 if d.polarity[.GRP0_INT03_PS2_MOUSE   ] else 0
        val |= 0x10 if d.polarity[.GRP0_INT04_TIMER0      ] else 0
        val |= 0x20 if d.polarity[.GRP0_INT05_TIMER1      ] else 0
        // reserved
        val |= 0x80 if d.polarity[.GRP0_INT07_CART        ] else 0
    case .INT_POL_REG1:
        val |= 0x01 if d.polarity[.GRP1_INT00_UART        ] else 0
        // reserved
        // reserved
        // reserved
        val |= 0x10 if d.polarity[.GRP1_INT04_RTC         ] else 0
        val |= 0x20 if d.polarity[.GRP1_INT05_VIA0        ] else 0
        val |= 0x40 if d.polarity[.GRP1_INT06_VIA1        ] else 0
        val |= 0x80 if d.polarity[.GRP1_INT07_SDC_INS     ] else 0
    case .INT_POL_REG2:
        val |= 0x01 if d.polarity[.GRP2_INT00_IEC_DATA    ] else 0
        val |= 0x02 if d.polarity[.GRP2_INT01_IEC_CLOCK   ] else 0
        val |= 0x04 if d.polarity[.GRP2_INT02_IEC_ATN     ] else 0
        val |= 0x08 if d.polarity[.GRP2_INT03_IEC_SREQ    ] else 0
        // reserved
        // reserved
        // reserved
        // reserved
    case .INT_EDGE_REG0:
        val |= 0x01 if d.edge[.GRP0_INT00_SOF         ] else 0
        val |= 0x02 if d.edge[.GRP0_INT01_SOL         ] else 0
        val |= 0x04 if d.edge[.GRP0_INT02_PS2_KBD     ] else 0
        val |= 0x08 if d.edge[.GRP0_INT03_PS2_MOUSE   ] else 0
        val |= 0x10 if d.edge[.GRP0_INT04_TIMER0      ] else 0
        val |= 0x20 if d.edge[.GRP0_INT05_TIMER1      ] else 0
        // reserved
        val |= 0x80 if d.edge[.GRP0_INT07_CART        ] else 0
    case .INT_EDGE_REG1:
        val |= 0x01 if d.edge[.GRP1_INT00_UART        ] else 0
        // reserved
        // reserved
        // reserved
        val |= 0x10 if d.edge[.GRP1_INT04_RTC         ] else 0
        val |= 0x20 if d.edge[.GRP1_INT05_VIA0        ] else 0
        val |= 0x40 if d.edge[.GRP1_INT06_VIA1        ] else 0
        val |= 0x80 if d.edge[.GRP1_INT07_SDC_INS     ] else 0
    case .INT_EDGE_REG2:
        val |= 0x01 if d.edge[.GRP2_INT00_IEC_DATA    ] else 0
        val |= 0x02 if d.edge[.GRP2_INT01_IEC_CLOCK   ] else 0
        val |= 0x04 if d.edge[.GRP2_INT02_IEC_ATN     ] else 0
        val |= 0x08 if d.edge[.GRP2_INT03_IEC_SREQ    ] else 0
        // reserved
        // reserved
        // reserved
        // reserved
    case .INT_MASK_REG0:
        val |= 0x01 if d.mask[.GRP0_INT00_SOF         ] else 0
        val |= 0x02 if d.mask[.GRP0_INT01_SOL         ] else 0
        val |= 0x04 if d.mask[.GRP0_INT02_PS2_KBD     ] else 0
        val |= 0x08 if d.mask[.GRP0_INT03_PS2_MOUSE   ] else 0
        val |= 0x10 if d.mask[.GRP0_INT04_TIMER0      ] else 0
        val |= 0x20 if d.mask[.GRP0_INT05_TIMER1      ] else 0
        // reserved
        val |= 0x80 if d.mask[.GRP0_INT07_CART        ] else 0
    case .INT_MASK_REG1:
        val |= 0x01 if d.mask[.GRP1_INT00_UART        ] else 0
        // reserved
        // reserved
        // reserved
        val |= 0x10 if d.mask[.GRP1_INT04_RTC         ] else 0
        val |= 0x20 if d.mask[.GRP1_INT05_VIA0        ] else 0
        val |= 0x40 if d.mask[.GRP1_INT06_VIA1        ] else 0
        val |= 0x80 if d.mask[.GRP1_INT07_SDC_INS     ] else 0
    case .INT_MASK_REG2:
        val |= 0x01 if d.mask[.GRP2_INT00_IEC_DATA    ] else 0
        val |= 0x02 if d.mask[.GRP2_INT01_IEC_CLOCK   ] else 0
        val |= 0x04 if d.mask[.GRP2_INT02_IEC_ATN     ] else 0
        val |= 0x08 if d.mask[.GRP2_INT03_IEC_SREQ    ] else 0
        // reserved
        // reserved
        // reserved
        // reserved
    }

    return
}

pic_f256_write :: proc(pic: ^PIC, ba: ADDR, val: u32)  {

    if ba.size != .bits_8 {
        emu.unsupported_write_size(#procedure, pic.name, ba, val)
        return
    }

    addr      := ba.ea - ba.base
    d         := &pic.model.(PIC_F256)

    switch Register_pic_f256(addr) {
    case .INT_PENDING_REG0:
        if (val & 0x01) != 0 do d.pending[.GRP0_INT00_SOF         ] = false 
        if (val & 0x02) != 0 do d.pending[.GRP0_INT01_SOL         ] = false 
        if (val & 0x04) != 0 do d.pending[.GRP0_INT02_PS2_KBD     ] = false 
        if (val & 0x08) != 0 do d.pending[.GRP0_INT03_PS2_MOUSE   ] = false 
        if (val & 0x10) != 0 do d.pending[.GRP0_INT04_TIMER0      ] = false 
        if (val & 0x20) != 0 do d.pending[.GRP0_INT05_TIMER1      ] = false 
        // reserved
        if (val & 0x80) != 0 do d.pending[.GRP0_INT07_CART        ] = false 
    case .INT_PENDING_REG1:
        if (val & 0x01) != 0 do d.pending[.GRP1_INT00_UART        ] = false 
        // reserved
        // reserved
        // reserved
        if (val & 0x10) != 0 do d.pending[.GRP1_INT04_RTC         ] = false 
        if (val & 0x20) != 0 do d.pending[.GRP1_INT05_VIA0        ] = false 
        if (val & 0x40) != 0 do d.pending[.GRP1_INT06_VIA1        ] = false 
        if (val & 0x80) != 0 do d.pending[.GRP1_INT07_SDC_INS     ] = false 
    case .INT_PENDING_REG2:
        if (val & 0x01) != 0 do d.pending[.GRP2_INT00_IEC_DATA    ] = false
        if (val & 0x02) != 0 do d.pending[.GRP2_INT01_IEC_CLOCK   ] = false
        if (val & 0x04) != 0 do d.pending[.GRP2_INT02_IEC_ATN     ] = false
        if (val & 0x08) != 0 do d.pending[.GRP2_INT03_IEC_SREQ    ] = false
        // reserved
        // reserved
        // reserved
        // reserved
    case .INT_POL_REG0:
        d.polarity[.GRP0_INT00_SOF         ]  = (val & 0x01) != 0
        d.polarity[.GRP0_INT01_SOL         ]  = (val & 0x02) != 0
        d.polarity[.GRP0_INT02_PS2_KBD     ]  = (val & 0x04) != 0
        d.polarity[.GRP0_INT03_PS2_MOUSE   ]  = (val & 0x08) != 0
        d.polarity[.GRP0_INT04_TIMER0      ]  = (val & 0x10) != 0
        d.polarity[.GRP0_INT05_TIMER1      ]  = (val & 0x20) != 0
        // d.polarity[                        ]  = (val & 0x40) != 0
        d.polarity[.GRP0_INT07_CART        ]  = (val & 0x80) != 0
    case .INT_POL_REG1:
        d.polarity[.GRP1_INT00_UART        ]  = (val & 0x01) != 0
        // d.polarity[                        ]  = (val & 0x02) != 0
        // d.polarity[                        ]  = (val & 0x04) != 0
        // d.polarity[                        ]  = (val & 0x08) != 0
        d.polarity[.GRP1_INT04_RTC         ]  = (val & 0x10) != 0
        d.polarity[.GRP1_INT05_VIA0        ]  = (val & 0x20) != 0
        d.polarity[.GRP1_INT06_VIA1        ]  = (val & 0x40) != 0
        d.polarity[.GRP1_INT07_SDC_INS     ]  = (val & 0x80) != 0
    case .INT_POL_REG2:
        d.polarity[.GRP2_INT00_IEC_DATA    ]  = (val & 0x01) != 0
        d.polarity[.GRP2_INT01_IEC_CLOCK   ]  = (val & 0x02) != 0
        d.polarity[.GRP2_INT02_IEC_ATN     ]  = (val & 0x04) != 0
        d.polarity[.GRP2_INT03_IEC_SREQ    ]  = (val & 0x08) != 0
        // d.polarity[]  = (val & 0x10) != 0
        // d.polarity[]  = (val & 0x20) != 0
        // d.polarity[]  = (val & 0x40) != 0
        // d.polarity[]  = (val & 0x80) != 0
    case .INT_EDGE_REG0:
        d.edge[.GRP0_INT00_SOF         ]  = (val & 0x01) != 0
        d.edge[.GRP0_INT01_SOL         ]  = (val & 0x02) != 0
        d.edge[.GRP0_INT02_PS2_KBD     ]  = (val & 0x04) != 0
        d.edge[.GRP0_INT03_PS2_MOUSE   ]  = (val & 0x08) != 0
        d.edge[.GRP0_INT04_TIMER0      ]  = (val & 0x10) != 0
        d.edge[.GRP0_INT05_TIMER1      ]  = (val & 0x20) != 0
        // d.edge[                        ]  = (val & 0x40) != 0
        d.edge[.GRP0_INT07_CART        ]  = (val & 0x80) != 0
    case .INT_EDGE_REG1:
        d.edge[.GRP1_INT00_UART        ]  = (val & 0x01) != 0
        // d.edge[                        ]  = (val & 0x02) != 0
        // d.edge[                        ]  = (val & 0x04) != 0
        // d.edge[                        ]  = (val & 0x08) != 0
        d.edge[.GRP1_INT04_RTC         ]  = (val & 0x10) != 0
        d.edge[.GRP1_INT05_VIA0        ]  = (val & 0x20) != 0
        d.edge[.GRP1_INT06_VIA1        ]  = (val & 0x40) != 0
        d.edge[.GRP1_INT07_SDC_INS     ]  = (val & 0x80) != 0
    case .INT_EDGE_REG2:
        d.edge[.GRP2_INT00_IEC_DATA    ]  = (val & 0x01) != 0
        d.edge[.GRP2_INT01_IEC_CLOCK   ]  = (val & 0x02) != 0
        d.edge[.GRP2_INT02_IEC_ATN     ]  = (val & 0x04) != 0
        d.edge[.GRP2_INT03_IEC_SREQ    ]  = (val & 0x08) != 0
        // d.edge[]  = (val & 0x10) != 0
        // d.edge[]  = (val & 0x20) != 0
        // d.edge[]  = (val & 0x40) != 0
        // d.edge[]  = (val & 0x80) != 0
    case .INT_MASK_REG0:
        //log.debugf("pic0: %6s write   .INT_MASK_REG0: val %02x", d.name, val)
        d.mask[.GRP0_INT00_SOF         ]  = (val & 0x01) != 0
        d.mask[.GRP0_INT01_SOL         ]  = (val & 0x02) != 0
        d.mask[.GRP0_INT02_PS2_KBD     ]  = (val & 0x04) != 0
        d.mask[.GRP0_INT03_PS2_MOUSE   ]  = (val & 0x08) != 0
        d.mask[.GRP0_INT04_TIMER0      ]  = (val & 0x10) != 0
        d.mask[.GRP0_INT05_TIMER1      ]  = (val & 0x20) != 0
        // d.mask[                        ]  = (val & 0x40) != 0
        d.mask[.GRP0_INT07_CART        ]  = (val & 0x80) != 0
    case .INT_MASK_REG1:
        //log.debugf("pic0: %6s write  .INT_MASK_REG1: val %02x", d.name, val)
        d.mask[.GRP1_INT00_UART        ]  = (val & 0x01) != 0
        // d.mask[                        ]  = (val & 0x02) != 0
        // d.mask[                        ]  = (val & 0x04) != 0
        // d.mask[                        ]  = (val & 0x08) != 0
        d.mask[.GRP1_INT04_RTC         ]  = (val & 0x10) != 0
        d.mask[.GRP1_INT05_VIA0        ]  = (val & 0x20) != 0
        d.mask[.GRP1_INT06_VIA1        ]  = (val & 0x40) != 0
        d.mask[.GRP1_INT07_SDC_INS     ]  = (val & 0x80) != 0
    case .INT_MASK_REG2:
        d.mask[.GRP2_INT00_IEC_DATA    ]  = (val & 0x01) != 0
        d.mask[.GRP2_INT01_IEC_CLOCK   ]  = (val & 0x02) != 0
        d.mask[.GRP2_INT02_IEC_ATN     ]  = (val & 0x04) != 0
        d.mask[.GRP2_INT03_IEC_SREQ    ]  = (val & 0x08) != 0
        // d.mask[]  = (val & 0x10) != 0
        // d.mask[]  = (val & 0x20) != 0
        // d.mask[]  = (val & 0x40) != 0
        // d.mask[]  = (val & 0x80) != 0
    }

    return
}

/*
Interrupt Control Registers

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

pic_f256_internal_trigger :: proc(pic: ^PIC, irq: IRQ_F256)  {
    d         := &pic.model.(PIC_F256)

    d.pending[irq] = true

    // there is a problem with handling SOF with rate 60Hz - maybe emulator is too slow?
    //if d.mask[irq] == false && irq != .FNX0_INT00_SOF {
    if d.mask[irq] == false {
        //log.debugf("IRQ: %v", irq)
        d.irq_active   = true
    } 
    
    return
}

pic_f256_trigger :: proc(pic: ^PIC, irq: IRQ)  {
    #partial switch irq {
//    case      .KBD_PS2: pic_f256_internal_trigger(pic, .GRP0_INT02_PS2_KBD)
    case      .KBD_PS2: pic_f256_internal_trigger(pic, .GRP1_INT06_VIA1)
    case  .VICKY_A_SOF: pic_f256_internal_trigger(pic, .GRP0_INT00_SOF)
//    case   .RESERVED_5: pic_f256_internal_trigger(pic, .FNX2_INT03_SDMA)    // too bad, too bad we
//    case   .RESERVED_6: pic_f256_internal_trigger(pic, .FNX2_INT04_VDMA)    // need abstract irq names
    case       .TIMER0: pic_f256_internal_trigger(pic, .GRP0_INT04_TIMER0)
    case       .TIMER1: pic_f256_internal_trigger(pic, .GRP0_INT05_TIMER1)
    case          .RTC: pic_f256_internal_trigger(pic, .GRP1_INT04_RTC)
    case          : emu.call_not_implemented(#procedure, fmt.aprintf("%s", irq))
    }
}

pic_f256_delete :: proc(pic: ^PIC) {
    //d         := &pic.model.(PIC_F256)
    //free(d.data)
    free(pic)
}

