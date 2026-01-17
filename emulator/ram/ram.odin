
package ram

import "lib:emu"

MODE :: emu.OpMode

RAM  :: struct {
    name:    string,
    delete:  proc(^RAM),
    read:    proc(^RAM, MODE, u32, u32) -> u32,
    write:   proc(^RAM, MODE, u32, u32,    u32),

    size:    int,
    data:    [dynamic]u8,
}

make_ram :: proc(name: string, size: int) -> ^RAM {
    ram           := new(RAM)
    ram.name       = name
    ram.delete     = delete_ram
    ram.read       =   read_ram
    ram.write      =  write_ram

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

// eof
