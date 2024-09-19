
package ram

import "lib:emu"

RAM :: struct {
    delete:  proc(^RAM           ),
    read:    proc(^RAM, emu.Request_Size, u32)-> u32 ,
    write:   proc(^RAM, emu.Request_Size, u32,   u32),

    name:   string,
    data:   [dynamic]u8,
    size:   int
}

read_ram :: #force_inline proc(ram: ^RAM, mode: emu.Request_Size, addr: u32) -> (val: u32) {
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

write_ram :: #force_inline proc(ram: ^RAM, mode: emu.Request_Size, addr, val: u32) {
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

make_ram :: proc(name: string, size: int) -> ^RAM {

    ram       := new(RAM)
    ram.name   = name
    ram.delete = delete_ram
    ram.read   = read_ram
    ram.write  = write_ram
    ram.data   = make([dynamic]u8,     size+3)
    ram.size   = size

    //g         := RAM_Ram{ram = ram}
    return ram
}

delete_ram :: proc(ram: ^RAM) {
    delete(ram.data)
    free(ram)
    return
}

