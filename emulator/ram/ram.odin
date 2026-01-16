
package ram

import "lib:emu"

MODE :: emu.OpMode

RAM  :: struct {
    read:    proc(^RAM, BITS, u32, u32) -> u32,
    write:   proc(^RAM, BITS, u32, u32,    u32),
    delete:  proc(^RAM),

    name:   string,
    size:   int,
    data:   [dynamic]u8,
}

ram_make :: proc(name: string, size: int) -> ^RAM {
    ram           := new(RAM)
    ram.name       = name
    ram.delete     = ram_delete
    ram.read       = ram_read
    ram.write      = ram_write
    ram.data       = make([dynamic]u8, size+3) // margin for m68k 32-bit writing at 0x..FF
    ram.size       = size

    return ram
}


ram_read :: #force_inline proc(ram: ^RAM, mode: MODE, addr, ra: u32) -> (out: u32) {
    switch mode {
    case .op_8: 
        val = cast(u32) ram.data[addr]
    case .op_16be:
        ptr := transmute(^u16be) &ram.data[addr]
        val  = cast(u32) ptr^
    case .op_32be:
        ptr := transmute(^u32be) &ram.data[addr]
        val  = cast(u32) ptr^
    }
    return
}

ram_write :: #force_inline proc(ram: ^RAM, mode: MODE, addr, ra, val: u32) {
    switch mode {
    case .op_8: 
        ram.data[addr] = cast(u8) val
    case .op_16be:
        (transmute(^u16be) &ram.data[addr])^ = cast(u16be) val
    case .op_32be:
        (transmute(^u32be) &ram.data[addr])^ = cast(u32be) val
    }
    return
}

ram_delete :: proc(ram: ^RAM) {
    delete(ram.data)
    free(ram)
    return
}

// eof
