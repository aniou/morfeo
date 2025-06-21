
package inu

import "lib:emu"

BITS :: emu.Bitsize
INU  :: struct {
    name:   string,
    id:     int,

    delete:  proc(^INU           ),
    peek:    proc(^INU, BITS, u32, u32)-> u32 ,
    read:    proc(^INU, BITS, u32, u32)-> u32 ,
    write:   proc(^INU, BITS, u32, u32,   u32),

    model: union {INU_C256}
}


