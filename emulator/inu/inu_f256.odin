
package inu

import "lib:emu"

INU_F256 :: struct {
    using inu: ^INU,
    
    mem:    [0x1c]u32,
}

inu_f256_make :: proc(name: string) -> ^INU {
    inu          := new(INU)
    inu.name      = name
    inu.id        = 0

    inu.nread     = inu_f256_read
    inu.nwrite    = inu_f256_write
    inu.delete    = inu_f256_delete

    m            := INU_F256{inu = inu}
    inu.model    = m
    return inu
} 

inu_f256_delete :: proc(inu: ^INU) {
	free(inu)
    return
}

inu_f256_read :: proc(inu: ^INU, ba: ADDR) -> (val: u32) {
    m         := &inu.model.(INU_F256)
	val        = m.mem[ba.ea - ba.base]
	return
}

inu_f256_write :: proc(inu: ^INU, ba: ADDR, val: u32)  {
    m         := &inu.model.(INU_F256)
    addr      := ba.ea - ba.base

	switch addr {
        case 0x00, 0x01, 0x02, 0x03:   // UNSIGNED_MULT_A, UNSIGNED_MULT_B
			m.mem[addr] = val
			op1    := u16(m.mem[0x00]) + u16(m.mem[0x01]) << 8
			op2    := u16(m.mem[0x02]) + u16(m.mem[0x03]) << 8

			result := u32(op1 * op2)

			m.mem[0x10] = u32(result       & 0xff)
			m.mem[0x11] = u32(result >> 8  & 0xff)
			m.mem[0x12] = u32(result >> 16 & 0xff)
			m.mem[0x13] = u32(result >> 24 & 0xff)

        case 0x04, 0x05, 0x06, 0x07:   // UNSIGNED_DIV_DEM, UNSIGNED_DIV_NUM
			m.mem[addr] = val
			op1    := u16(m.mem[0x04]) + u16(m.mem[0x05]) << 8
			op2    := u16(m.mem[0x06]) + u16(m.mem[0x07]) << 8
					
			result    : u16
            remainder : u16
			if (op1 != 0) {
					result    = op2 / op1
					remainder = op2 % op1
			}

			m.mem[0x14] = u32(result          & 0xff)
			m.mem[0x15] = u32(result    >> 8  & 0xff)
			m.mem[0x16] = u32(remainder       & 0xff)
			m.mem[0x17] = u32(remainder >> 8  & 0xff)

        case 0x08, 0x09, 0x0a, 0x0b,  // ADDER32_A
             0x0c, 0x0d, 0x0e, 0x0f:  // ADDER32_B

			m.mem[addr] = val
			op1    := i32(m.mem[0x08])       + 
					  i32(m.mem[0x09]) <<  8 + 
					  i32(m.mem[0x0a]) << 16 + 
					  i32(m.mem[0x0b]) << 24

			op2    := i32(m.mem[0x0c])       + 
					  i32(m.mem[0x0d]) << 8  + 
					  i32(m.mem[0x0e]) << 16 + 
					  i32(m.mem[0x0f]) << 24
			result := i32(op1 + op2)

			m.mem[0x18] = u32(result       & 0xff)
			m.mem[0x19] = u32(result >> 8  & 0xff)
			m.mem[0x1a] = u32(result >> 16 & 0xff) 
			m.mem[0x1b] = u32(result >> 24 & 0xff) 

        case 0x10, 0x11, 0x12, 0x13:   // UNSIGNED_MULT_result
            break

        case 0x14, 0x15, 0x16, 0x17:   // UNSIGNED_DIV_result
            break

        case 0x18, 0x19, 0x1a, 0x1b:   // ADDER32_result 
        	break

        case:
        	m.mem[addr] = val
	}
	return
}
