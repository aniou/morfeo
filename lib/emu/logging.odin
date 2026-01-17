
package emu

import "core:fmt"
import "core:log"

MODE :: OpMode
ERR  :: BusError

format_val  :: proc(mode: OpMode, val: u32) -> (out: string) {
    switch mode {
    case .mode_8   : out = fmt.aprintf("%02X",        u8(val & 0x0000_00ff))
    case .mode_16be: out = fmt.aprintf("%04X",       u16(val & 0x0000_ffff))
    case .mode_32be: out = fmt.aprintf("%04X:%04X",  u16(val >> 16), u16(val & 0x0000_ffff))
    }
    return
}

format_addr :: proc(addr: u32) -> (out: string) {
    switch {
    case addr < 0x00_FFFF: out = fmt.aprintf("%04X",                        u16(addr & 0xFFFF))
    case addr < 0xFF_FFFF: out = fmt.aprintf("%02X:%04X",   u8(addr >> 16), u16(addr & 0xFFFF))
    case                 : out = fmt.aprintf("%04X:%04X",  u16(addr >> 16), u16(addr & 0xFFFF))
    }
    return
}


error_read :: proc(dev: string, e: ERR, m: MODE, addr,ra: u32, r: Region, loc:=#caller_location) {
    sra    := format_addr(ra)
    saddr  := format_addr(addr)
    err    :  string

    switch e {
    case .BAD_MODE: err = "not supported"
    case .NOT_IMPL: err = "not implemented"
    }

    log.errorf("%-6s %8s read %7d       from ra %9s ea %9s %s (%s)", 
                dev, 
                fmt.enum_value_to_string(r),
                fmt.enum_value_to_string(m),
                sra,  saddr,  err,  loc
    )
    delete(sra)
    delete(saddr)
}

error_write :: proc(dev: string, e: ERR, m: MODE, addr,ra,val: u32, r: Region, loc:=#caller_location) {
    sra    := format_addr(ra)
    saddr  := format_addr(addr)
    sval   := format_val(m, val)
    err    :  string

    switch e {
    case .BAD_MODE: err = "not supported"
    case .NOT_IMPL: err = "not implemented"
    }

    log.errorf("%-6s %8s read %7d val %9s to ra %9s ea %9s %s (%s)", 
                dev, 
                fmt.enum_value_to_string(r),
                fmt.enum_value_to_string(m),
                sval,
                sra,  saddr,  err,  loc
    )
    delete(sra)
    delete(saddr)
    delete(sval)
}

call_not_implemented :: proc(procedure, desc: string) {
    log.errorf("%-24s    %64s  not implemented at all", 
                procedure, 
                desc 
    )
}

