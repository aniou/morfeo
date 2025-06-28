
package emu

import "core:fmt"
import "core:log"

TARGET :: #config(TARGET, "none")

// now compile-type static TARGET is used in place of dynamic Type one
// following is kept for archival purposes

// used to determine minor differences between platforms, XXX: add m68k
//Type :: enum {
//    C256FMX,    // 4 SRAM  4 VRAM          65816       @ 14Mhz (FMX) - OPL3, OPN2, OPM and SN76489
//    C256U,      // 2 SRAM  2 VRAM          65816       @ 14Mhz
//    C256UPLUS,  // 4 SRAM  2 VRAM          65816       @ 14Mhz
//    C256B,      // 2 SRAM  ? VRAM          65816                    - 2xOPL2
//    F256Jr,     // 1 SRAM                  W65C02      @ 6Mhz  - 3 CPU!
//    F256Jr2,    //                                             - 2 CPU
//    F256K,      // 1 SRAM                  6502                - 3 CPU
//    F256K2,     //                                             - 2 CPU
//    A2560u,     // 4 SRAM    SDRAM 2 VRAM  MC68SEC000  @ 20Mhz
//    A2560x,     // 4 SRAM    SDRAM 8 VRAM        32bit 
//    A2560k,     // 4 SRAM 16 SDRAM 8 VRAM  MC68040V    @ 25Mhz
//    A2560m,     // 8 SRAM 1024 DDR 4 FLASH
//    GenX,       // 8 SRAM 16 SDRAM 8 VRAM  65816+32bit @ 14Mhz
//}

// C256 FMX    = $00
// C256 U      = $01
// F256JR      = $02
// F256JRe     = $03
// GenX        = $04  (8bit side)
// C256 U+     = $05
// Not Defined = $06
// Not Defined = $07
// A2560X      = $08 (GenX 32Bits SIde)
// A2560U+     = $09 (there is no A2560U only in the field)
// A2560M      = $0A (this is for the future)
// A2560K      = $0B (Classic)
// A2560K40    = $0C
// A2560K60    = $0D
// Not Defined = $0E
// Not Defined = $0F
// F256P       = $10 (future portable)
// F256K2c     = $11
// F256Kc      = $12
// F256Ke      = $13
// F256K2e     = $14

// used by bus read to denote 8/16/32 bits operations
// XXX: todo - expand to little and big endian ones
Bitsize :: enum {
    bits_8   = 8,
    bits_16  = 16,
    bits_32  = 32
}

Access_Type :: enum {
    READ,
    WRITE
}

// used by devices to denote function
Region :: enum {
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
    MOUSEPTR0,  // mouse pointer memory in vicky
    MOUSEPTR1,  // mouse pointer memory in vicky
    TILEMAP,
    TILESET,
    ID_CARD,    // id block of extension card
}

// general config structure for emulator
DIP :: enum{DIP1, DIP2, DIP5, DIP4, DIP3, DIP6, DIP7, DIP8}

Config :: struct {
    disk0:     string,
    disk1:     string,             // XXX: not supported yet
    dipoff:    bit_set[DIP; u32],
    gui_scale: int,                // gui scaling, by default: 2
    gpu_id:    int,
    disasm:    bool,
    busdump:   bool,
    files:     [dynamic]string,
}   


// used by devices
unsupported_read_size :: proc(procedure, dev_name: string, dev_id: int, mode: Bitsize, addr: u32) {
    log.errorf("%-12s %s%d read%-2d          from %04X:%04X not supported", 
                procedure, 
                dev_name, 
                dev_id, 
                mode, 
                u16(addr >> 16), u16(addr & 0x0000_ffff)
    )
}

// used by devices
unsupported_write_size :: proc(procedure, dev_name: string, dev_id: int, mode: Bitsize, addr, val: u32) {
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
write_not_implemented :: proc(procedure, dev_name: string, bits: Bitsize, addr, val: u32) {
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

read_not_implemented :: proc(procedure, dev_name: string, bits: Bitsize, addr: u32) {
    log.errorf("%-12s %s read  bits%2d   addr %04X:%04X               not implemented at all", 
                procedure, 
                dev_name, 
                bits, 
                u16(addr >> 16), u16(addr & 0x0000_ffff)
    )
}

call_not_implemented :: proc(procedure, call: string) {
    log.errorf("%-12s    call %64s  not implemented at all", 
                procedure, 
                call
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

// helper routines
// assign 8-bit part to corresponding byte in 32-bit value
assign_byte1  :: #force_inline proc(dst, arg: u32) -> (val: u32) {
    val  = dst & 0xFFFF_FF00
    val |= arg 
    return
}

assign_byte2  :: #force_inline proc(dst, arg: u32) -> (val: u32) {
    val  = dst  & 0xFFFF_00FF
    val |= arg << 8
    return
}

assign_byte3  :: #force_inline proc(dst, arg: u32) -> (val: u32) {
    val  = dst  & 0xFF00_FFFF
    val |= arg << 16
    return
}

assign_byte4  :: #force_inline proc(dst, arg: u32) -> (val: u32) {
    val  = dst  & 0x00FF_FFFF
    val |= arg << 24
    return
}

get_byte1  :: #force_inline proc(dst: u32) -> (val: u32) {
    val  = (dst & 0x0000_00FF)
    return
}

get_byte2  :: #force_inline proc(dst: u32) -> (val: u32) {
    val  = (dst & 0x0000_FF00) >> 8
    return
}

get_byte3  :: #force_inline proc(dst: u32) -> (val: u32) {
    val  = (dst & 0x00FF_0000) >> 16
    return
}

get_byte4  :: #force_inline proc(dst: u32) -> (val: u32) {
    val  = (dst & 0xFF00_0000) >> 24
    return
}

// eof
