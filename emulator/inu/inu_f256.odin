
package inu

import "lib:emu"

INU_F256 :: struct {
    using base: ^INU,
    
    mem:    [0x1c]u32,
}

make_inu_f256 :: proc(name: string, dcb: ^emu.DeviceConfig) -> ^INU {
    inu         := new(INU)
    inu.name     = name
    inu.req      = dcb.req

    inu.delete   = delete_inu_f256
    inu.read     =   read_inu_f256
    inu.write    =  write_inu_f256

    inu.model    = INU_F256{base = inu}
    return inu
} 

delete_inu_f256 :: proc(inu: ^INU) {
	free(inu)
    return
}

read_inu_f256 :: proc(inu: ^INU, mode: MODE, addr: u32) -> (out: u32) {
    i         := &inu.model.(INU_F256)
	out        = i.mem[addr]
	return
}

write_inu_f256 :: proc(inu: ^INU, mode: MODE, addr, val: u32)  {
    i         := &inu.model.(INU_F256)
	switch addr {
        case 0x00, 0x01, 0x02, 0x03:   // UNSIGNED_MULT_A, UNSIGNED_MULT_B
			i.mem[addr] = val
			op1    := u16(i.mem[0x00]) + u16(i.mem[0x01]) << 8
			op2    := u16(i.mem[0x02]) + u16(i.mem[0x03]) << 8

			result := u32(op1 * op2)

			i.mem[0x10] = u32(result       & 0xff)
			i.mem[0x11] = u32(result >> 8  & 0xff)
			i.mem[0x12] = u32(result >> 16 & 0xff)
			i.mem[0x13] = u32(result >> 24 & 0xff)

        case 0x04, 0x05, 0x06, 0x07:   // UNSIGNED_DIV_DEM, UNSIGNED_DIV_NUM
			i.mem[addr] = val
			op1    := u16(i.mem[0x04]) + u16(i.mem[0x05]) << 8
			op2    := u16(i.mem[0x06]) + u16(i.mem[0x07]) << 8
					
			result    : u16
            remainder : u16
			if (op1 != 0) {
					result    = op2 / op1
					remainder = op2 % op1
			}

			i.mem[0x14] = u32(result          & 0xff)
			i.mem[0x15] = u32(result    >> 8  & 0xff)
			i.mem[0x16] = u32(remainder       & 0xff)
			i.mem[0x17] = u32(remainder >> 8  & 0xff)

        case 0x08, 0x09, 0x0a, 0x0b,  // ADDER32_A
             0x0c, 0x0d, 0x0e, 0x0f:  // ADDER32_B

			i.mem[addr] = val
			op1    := i32(i.mem[0x08])       + 
					  i32(i.mem[0x09]) <<  8 + 
					  i32(i.mem[0x0a]) << 16 + 
					  i32(i.mem[0x0b]) << 24

			op2    := i32(i.mem[0x0c])       + 
					  i32(i.mem[0x0d]) << 8  + 
					  i32(i.mem[0x0e]) << 16 + 
					  i32(i.mem[0x0f]) << 24
			result := i32(op1 + op2)

			i.mem[0x18] = u32(result       & 0xff)
			i.mem[0x19] = u32(result >> 8  & 0xff)
			i.mem[0x1a] = u32(result >> 16 & 0xff) 
			i.mem[0x1b] = u32(result >> 24 & 0xff) 

        case 0x10, 0x11, 0x12, 0x13:   // UNSIGNED_MULT_result
            break

        case 0x14, 0x15, 0x16, 0x17:   // UNSIGNED_DIV_result
            break

        case 0x18, 0x19, 0x1a, 0x1b:   // ADDER32_result 
        	break

        case:
        	i.mem[addr] = val
	}
	return
}
