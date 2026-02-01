
package emu

import "core:fmt"
import "core:log"

MODE :: OpMode
ERR  :: BusError
BREQ :: BusRequest

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

// XXX: make it configurable, for different lst
//      002105r - ca65
//      .42bd   - 64tass
//      .123456
format_pc :: proc(addr: u32) -> (out: string) {
    switch {
    case addr < 0x00_FFFF: out = fmt.aprintf(".%04x",                       u16(addr & 0xFFFF))
    case addr < 0xFF_FFFF: out = fmt.aprintf(".%02x%04x",   u8(addr >> 16), u16(addr & 0xFFFF))
    case                 : out = fmt.aprintf("%04x:%04x",  u16(addr >> 16), u16(addr & 0xFFFF))  // only ca65?
    }
    return
}

debug_read  :: proc(dev: string, m: MODE, addr, ra: u32, val: Maybe(u32) = nil) {
    saddr  := format_addr(addr)
    sra    := format_addr(ra)
    mode,_ := fmt.enum_value_to_string(m)
    if val != nil {
        sval   := format_val(m, val.?)
        log.debugf("%-6s %-9s read   %9s  from ra %9s  ea %9s", dev,  mode,       sval,  saddr,  sra)
        delete(sval)
    } else {
        log.debugf("%-6s %-9s read  %-9s   from ra %9s  ea %9s", dev,  mode,  "attempt",  saddr,  sra)
    }
    delete(saddr)
    delete(sra)
}

debug_write :: proc(dev: string, m: MODE, req: ^BREQ, val: u32, comment := "", loc:=#caller_location) {
    sea    := format_addr(req.ea)
    sra    := format_addr(req.ra)
    mode,_ := fmt.enum_value_to_string(m)
    sval   := format_val(m, val)

    spc      : string
    if req.has_pc {
        pc   := req.pc | (req.pc_bank << 16)
        spc   = format_pc(pc)
    } else {
        spc  = "-"
    }

    log.debugf("%-6s pc %9s %-9s write  %9s   ra %9s  ea %9s  %s  (%s:%d)", 
                dev,  spc,  mode,  sval,  sra,  sea,  comment,  loc.procedure, loc.line
    )

    delete(sval)
    delete(sea)
    delete(sra)
    if req.has_pc do delete(spc)
}

error_read  :: proc(dev: string, req: ^BREQ, e: ERR, m: MODE, addr:     u32, loc:=#caller_location) {
    sra      := format_addr(req.ra)
    saddr    := format_addr(addr)
    mode,_   := fmt.enum_value_to_string(m)

    err      :  string
    switch e {
    case .BAD_MODE: err = "not supp"
    case .NOT_IMPL: err = "not impl"
    }

    spc      : string
    if req.has_pc {
        pc   := req.pc | (req.pc_bank << 16)
        spc   = format_pc(pc)
    } else {
        spc  = "-"
    }

    log.errorf("%-6s pc %9s %-9s read               ra %9s  ea %9s  %s  (%s:%d)", 
                dev,  spc,  mode,  sra,  saddr,  err,  loc.procedure, loc.line
    )
    delete(sra)
    delete(saddr)
    if req.has_pc do delete(spc)
}

error_write :: proc(dev: string, req: ^BREQ, e: ERR, m: MODE, addr,val: u32, loc:=#caller_location) {
    sra      := format_addr(req.ra)
    saddr    := format_addr(addr)
    mode,_   := fmt.enum_value_to_string(m)
    sval     := format_val(m, val)

    err      :  string
    switch e {
    case .BAD_MODE: err = "not supp"
    case .NOT_IMPL: err = "not impl"
    }

    spc      : string
    if req.has_pc {
        pc   := req.pc | (req.pc_bank << 16)
        spc   = format_pc(pc)
    } else {
        spc  = "-"
    }

    log.errorf("%-6s pc %9s %-9s write  %9s   ra %9s  ea %9s  %s  (%s:%d)", 
                dev,  spc,  mode,  sval,  sra,  saddr,  err,  loc.procedure, loc.line
    )
    delete(sra)
    delete(saddr)
    if req.has_pc do delete(spc)
    delete(sval)
}

call_not_implemented :: proc(procedure, desc: string) {
    log.errorf("%-24s    %64s  not implemented at all", 
                procedure, 
                desc 
    )
}

