
package inu

import "lib:emu"

INU :: struct {
    name:   string,
    id:     int,

    delete:  proc(^INU           ),
    peek:    proc(^INU, emu.Bitsize, u32, u32)-> u32 ,
    read:    proc(^INU, emu.Bitsize, u32, u32)-> u32 ,
    write:   proc(^INU, emu.Bitsize, u32, u32,   u32),

    model: union {INU_C256}
}


