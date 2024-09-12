
package emu

import "core:log"

// used by bus read to denote 8/16/32 bits operations
Request_Size :: enum {
    bits_8   = 8,
    bits_16  = 16,
    bits_32  = 32
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
not_implemented :: proc(procedure, dev_name: string, mode: Request_Size, addr: u32) {
    log.errorf("%-12s %s access%-2d   addr %04X:%04X not implemented at all", 
                procedure, 
                dev_name, 
                mode, 
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
