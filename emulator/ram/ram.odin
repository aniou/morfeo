
package ram

import "lib:emu"

BITS :: emu.Bitsize

RAM  :: struct {
    peek:    proc(^RAM, BITS, u32, u32) -> u32,
    read:    proc(^RAM, BITS, u32, u32) -> u32,
    write:   proc(^RAM, BITS, u32, u32,    u32),
    delete:  proc(^RAM),

    name:   string,
    size:   int,

    data:   [dynamic]u8,
}


ram_read :: #force_inline proc(ram: ^RAM, mode: BITS, base, busaddr: u32) -> (val: u32) {
    addr := busaddr - base

    switch mode {
    case .bits_8: 
        val = cast(u32) ram.data[addr]
    case .bits_16:
        ptr := transmute(^u16be) &ram.data[addr]
        val  = cast(u32) ptr^
    case .bits_32:
        ptr := transmute(^u32be) &ram.data[addr]
        val  = cast(u32) ptr^
    }
    return
}

ram_write :: #force_inline proc(ram: ^RAM, mode: BITS, base, busaddr, val: u32) {
    addr := busaddr - base

    switch mode {
    case .bits_8: 
        ram.data[addr] = cast(u8) val
    case .bits_16:
        (transmute(^u16be) &ram.data[addr])^ = cast(u16be) val
    case .bits_32:
        (transmute(^u32be) &ram.data[addr])^ = cast(u32be) val
    }
    return
}

ram_make :: proc(name: string, size: int) -> ^RAM {
    ram           := new(RAM)
    ram.name       = name
    ram.delete     = ram_delete
    ram.peek       = ram_read
    ram.read       = ram_read
    ram.write      = ram_write
    ram.data       = make([dynamic]u8, size+3) // margin for m68k 32-bit writing at 0x..FF
    ram.size       = size

    return ram
}

ram_delete :: proc(ram: ^RAM) {
    delete(ram.data)
    free(ram)
    return
}

// eof
