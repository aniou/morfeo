
package ram

import "lib:emu"

MODE :: emu.OpMode

RAM  :: struct {
    name:    string,
    req:     ^emu.BusRequest,

    delete:  proc(^RAM),
    read:    proc(^RAM, MODE, u32, u32) -> u32,
    write:   proc(^RAM, MODE, u32, u32,    u32),

    size:    int,
    data:    [dynamic]u8,
}

ALTRAM  :: struct {
    name:    string,
    delete:  proc(^ALTRAM),
    read:    proc(^ALTRAM, MODE, u32) -> u32,
    write:   proc(^ALTRAM, MODE, u32,    u32),

    req:     ^emu.BusRequest,
    size:    int,
    data:    [dynamic]u8,
}

make_ram :: proc(name: string, dcb: ^emu.DeviceConfig, size: int) -> ^RAM {
    ram           := new(RAM)
    ram.name       = name
    ram.req        = dcb.req

    ram.delete     = delete_ram
    ram.read       =   read_ram
    ram.write      =  write_ram

    ram.data       = make([dynamic]u8, size+3) // margin for m68k 32-bit writing at 0x..FF
    ram.size       = size

    return ram
}

make_alt_ram :: proc(name: string, dcb: ^emu.DeviceConfig, size: int) -> ^ALTRAM {
    ram           := new(ALTRAM)
    ram.name       = name
    ram.req        = dcb.req

    ram.delete     = delete_alt_ram
    ram.read       =  read_alt_ram
    ram.write      = write_alt_ram

    ram.data       = make([dynamic]u8, size+3) // margin for m68k 32-bit writing at 0x..FF
    ram.size       = size

    return ram
}

delete_ram :: proc(ram: ^RAM) {
    delete(ram.data)
    free(ram)
    return
}

read_ram :: #force_inline proc(ram: ^RAM, mode: MODE, addr, ra: u32) -> (out: u32) {
    switch mode {
    case .mode_8: 
        out = cast(u32) ram.data[addr]
    case .mode_16be:
        ptr := transmute(^u16be) &ram.data[addr]
        out  = cast(u32) ptr^
    case .mode_32be:
        ptr := transmute(^u32be) &ram.data[addr]
        out  = cast(u32) ptr^
    }
    return
}

write_ram :: #force_inline proc(ram: ^RAM, mode: MODE, addr, ra, val: u32) {
    switch mode {
    case .mode_8: 
        ram.data[addr] = cast(u8) val
    case .mode_16be:
        (transmute(^u16be) &ram.data[addr])^ = cast(u16be) val
    case .mode_32be:
        (transmute(^u32be) &ram.data[addr])^ = cast(u32be) val
    }
    return
}

delete_alt_ram :: proc(ram: ^ALTRAM) {
    delete(ram.data)
    free(ram)
    return
}

read_alt_ram :: #force_inline proc(ram: ^ALTRAM, mode: MODE, addr: u32) -> (out: u32) {
    switch mode {
    case .mode_8: 
        out = cast(u32) ram.data[addr]
    case .mode_16be:
        ptr := transmute(^u16be) &ram.data[addr]
        out  = cast(u32) ptr^
    case .mode_32be:
        ptr := transmute(^u32be) &ram.data[addr]
        out  = cast(u32) ptr^
    }
    return
}

write_alt_ram :: #force_inline proc(ram: ^ALTRAM, mode: MODE, addr, val: u32) {
    switch mode {
    case .mode_8: 
        ram.data[addr] = cast(u8) val
    case .mode_16be:
        (transmute(^u16be) &ram.data[addr])^ = cast(u16be) val
    case .mode_32be:
        (transmute(^u32be) &ram.data[addr])^ = cast(u32be) val
    }
    return
}

// eof
