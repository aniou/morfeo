
package emu

import "core:fmt"
import "core:log"

// used by bus read to denote 8/16/32 bits operations
// XXX: todo - expand to little and big endian ones
Request_Size :: enum {
    bits_8   = 8,
    bits_16  = 16,
    bits_32  = 32
}

Access_Type :: enum {
    READ,
    WRITE
}

// used by devices to denote function
Mode :: enum {
    MAIN,
    MAIN_A,
    MAIN_B,
    TEXT,
    TEXT_COLOR,
    TEXT_FG_LUT,
    TEXT_BG_LUT,
    FONT_BANK0,
    FONT_BANK1,
    LUT,
    VRAM0,
}

// used to determine minor differences between platforms, XXX: add m68k
Type :: enum {
    C256B, 		// 2 SRAM                  65816                    - 2xOPL2
    C256FMX, 	// 4 SRAM  4 VRAM          65816       @ 14Mhz (FMX) - OPL3, OPN2, OPM and SN76489
    C256U,		// 1 SRAM  2 VRAM          65816       @ 14Mhz
    C256Uplus,  // 2 SRAM  2 VRAM          65816       @ 14Mhz
    F256Jr,		// 1 SRAM                  W65C02      @ 6Mhz  - 3 CPU!
    F256Jr2,    //                                             - 2 CPU
    F256K,		// 1 SRAM                  6502                - 3 CPU
    F256K2,     //                                             - 2 CPU
    A2560u,     // 4 SRAM    SDRAM 2 VRAM  MC68SEC000  @ 20Mhz
    A2560x,     // 4 SRAM    SDRAM 8 VRAM        32bit 
    A2560k,     // 4 SRAM 16 SDRAM 8 VRAM  MC68040V    @ 25Mhz
    A2560m,     // 8 SRAM 1024 DDR 4 FLASH
    GenX,		// 8 SRAM 16 SDRAM 8 VRAM  65816+32bit @ 14Mhz
}

// used by devices
unsupported_read_size :: proc(procedure, dev_name: string, dev_id: int, mode: Request_Size, addr: u32) {
    log.errorf("%-12s %s%d read%-2d          from %04X:%04X not supported", 
                procedure, 
                dev_name, 
                dev_id, 
                mode, 
                u16(addr >> 16), u16(addr & 0x0000_ffff)
    )
}

// used by devices
unsupported_write_size :: proc(procedure, dev_name: string, dev_id: int, mode: Request_Size, addr, val: u32) {
    log.errorf("%-12s %s%d write%-2d %04X:%04X to %04X:%04X not supported", 
                procedure, 
                dev_name, 
                dev_id, 
                mode, 
                u16(val  >> 16), u16(val  & 0x0000_ffff),
                u16(addr >> 16), u16(addr & 0x0000_ffff)
    )
}

// used by devices
write_not_implemented :: proc(procedure, dev_name: string, bits: Request_Size, addr, val: u32) {
    display_val : string 
    switch bits {
        case .bits_8:  display_val = fmt.aprintf("%02X",        u8(val & 0x0000_00ff))
        case .bits_16: display_val = fmt.aprintf("%04X",       u16(val & 0x0000_ffff))
        case .bits_32: display_val = fmt.aprintf("%04X:%04X",  u16(addr >> 16), u16(val & 0x0000_ffff))
    }

    log.errorf("%-12s %s write bits%2d   addr %04X:%04X val %9s not implemented at all", 
                procedure, 
                dev_name, 
                bits, 
                u16(addr >> 16), u16(addr & 0x0000_ffff),
                display_val
    )
}

read_not_implemented :: proc(procedure, dev_name: string, bits: Request_Size, addr: u32) {
    log.errorf("%-12s %s read  bits%2d   addr %04X:%04X               not implemented at all", 
                procedure, 
                dev_name, 
                bits, 
                u16(addr >> 16), u16(addr & 0x0000_ffff)
    )
}

// used by main program
show_cpu_speed :: proc(cycles: u32) -> (u32, string) {
        switch {
        case cycles > 1000000:
                return cycles / 1000000, "MHz"
        case cycles > 1000:
                return cycles / 100, "kHz"
        case:
                return cycles, "Hz"
        }
}
