
package inu

// inu is an shortcut od 'integer unit'
//     - a very bad name, but fpu may be a problem in future, due
//       to clash with real fpu implementation and 'math' already
//       exists in core

import "lib:emu"

BITS :: emu.Bitsize
ADDR :: emu.BusAddress
INU  :: struct {
    name:   string,
    id:     int,

    delete:  proc(^INU           ),
    peek:    proc(^INU, BITS, u32, u32)-> u32 ,
    read:    proc(^INU, BITS, u32, u32)-> u32 ,
    write:   proc(^INU, BITS, u32, u32,   u32),
    nread:   proc(^INU, ADDR          )-> u32 ,
    nwrite:  proc(^INU, ADDR,             u32),

    model: union {INU_C256, INU_F256}
}


