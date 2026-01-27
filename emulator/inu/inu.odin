
package inu

// inu is an shortcut od 'integer unit'
//     - a very bad name, but fpu may be a problem in future, due
//       to clash with real fpu implementation and 'math' already
//       exists in core

import "lib:emu"

MODE :: emu.OpMode
INU  :: struct {
    name:   string,
    req:    ^emu.BusRequest,

    delete:  proc(^INU           ),
    read:    proc(^INU, MODE, u32)-> u32 ,
    write:   proc(^INU, MODE, u32,   u32),

    model: union {INU_C256, INU_F256}
}


