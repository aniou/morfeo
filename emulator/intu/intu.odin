
package intu

import "lib:emu"

INTU :: struct {
    name:   string,
    id:     int,

    delete:  proc(^INTU           ),
    read:    proc(^INTU, emu.Request_Size, u32, u32)-> u32 ,
    write:   proc(^INTU, emu.Request_Size, u32, u32,   u32),

    model: union {INTU_C256}
}


