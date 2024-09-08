package cpu

import "core:fmt"

parse_argument :: proc(c: ^CPU_65xxx, mode: CPU_65xxx_mode) -> (result: string) {
    pc          := c.pc
    pc.addr     += 1 

    switch mode {
    case .Absolute:                           // abs
        arg    := read_m( pc, word )
        result  = fmt.aprintf("$%04x  ", arg) 

    case .Absolute_X:                         // abs,X
        arg    := read_m( pc, word )
        result  = fmt.aprintf("$%04x,X", arg) 

    case .Absolute_Y:                         // abs,Y
        arg    := read_m( pc, word )
        result  = fmt.aprintf("$%04x,Y", arg) 

    case .Accumulator:                        // acc
        result  = ""

    case .Immediate:                          // imm
        if c.f.M {
            arg    := read_m( pc, byte)
            result  = fmt.aprintf("#$%02x", arg & 0xff) 
        } else {
            arg    := read_m( pc, word )
            result  = fmt.aprintf("#$%04x", arg) 
        }

    case .Implied:                            // imp
        result  = ""

    case .DP:                                 // dir
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("$%02x,Y", arg & 0xff) 

    case .DP_X:                               // dir,X
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("$%02x,X", arg & 0xff) 

    case .DP_Y:                               // dir,Y
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("($%02x,X)", arg & 0xff) 

    case .DP_X_Indirect:                      // (dir,X)
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("($%02x,X)", arg & 0xff) 

    case .DP_Indirect:                        // (dir)
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("($%02x)", arg & 0xff) 

    case .DP_Indirect_Long:                   // [dir]
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("[$%02x]", arg & 0xff) 

    case .DP_Indirect_Y:                      // (dir),Y
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("($%02x),Y", arg & 0xff) 

    case .DP_Indirect_Long_Y:                 // [dir],Y
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("[$%02x],Y", arg & 0xff) 

    case .Absolute_X_Indirect:                // (abs,X)
        arg    := read_m( pc, word )
        result  = fmt.aprintf("($%04x,X)", arg) 

    case .Absolute_Indirect:                  // (abs)
        arg    := read_m( pc, word )
        result  = fmt.aprintf("($%04x)", arg) 

    case .Absolute_Indirect_Long:             // [abs]
        arg    := read_m( pc, word )
        result  = fmt.aprintf("[$%04x]", arg) 

    case .Absolute_Long:                      // long
        arg     := read_m( pc, word )
        pc.addr += 2
        bank    := read_m( pc, byte )
        result   = fmt.aprintf("$%02x:%04x", bank, arg) 

    case .Absolute_Long_X:                    // long,X
        arg     := read_m( pc, word )
        pc.addr += 2
        bank    := read_m( pc, byte )
        result   = fmt.aprintf("$%02x:%04x,X", bank, arg) 

    case .BlockMove:                          // src,dest
        dst     := read_m( pc, byte )
        pc.addr += 1
        src     := read_m( pc, byte )
        result   = fmt.aprintf("%02x, %02x", src, dst)

    case .PC_Relative:                        // rel8
        arg    := read_m( pc, byte )
        dst    := adds_b( pc.addr + 1, arg )
        result  = fmt.aprintf("$%02x ($%04x)", arg, dst) 

    case .PC_Relative_Long:                   // rel16
        arg    := read_m( pc, word )
        dst    := adds_w( pc.addr + 2, arg )
        result  = fmt.aprintf("$%02x ($%04x)", arg, dst) 

    case .S_Relative:                         // stk,S
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("$%02x,S", arg) 

    case .S_Relative_Indirect_Y:              // (stk,S),Y
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("($%02x,S),Y", arg) 

    case .ZP_X_Indirect:                      // (zp,X)
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("($%02x,X)", arg) 

    case .ZP:                                 // zp
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("$%02x", arg) 

    case .ZP_X:                               // zp,X
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("$%02x,X", arg) 

    case .ZP_Y:                               // zp,Y
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("$%02x,Y", arg) 

    case .ZP_and_Relative:                    // zp,rel
        arg1     := read_m( pc, byte )
        pc.addr  += 1
        arg2     := read_m( pc, byte )
        dst      := adds_w( pc.addr + 1, arg2 )
        result    = fmt.aprintf("%02x, %02x ($%04x)", arg1, arg2, dst)

    case .ZP_Indirect_Y:                      // (zp),Y
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("($%02x),Y", arg) 

    case .ZP_Indirect:                        // (zp)
        arg    := read_m( pc, byte )
        result  = fmt.aprintf("($%02x)", arg) 

    case .Illegal:                            // -
        result  = fmt.aprintf("(opcode %02x)", c.ir) 
    }

    return
}
// eof
