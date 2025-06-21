
package inu

import "lib:emu"

INU_C256 :: struct {
    using inu: ^INU,
    
    mem:    [0x2c]u32,
}

inu_c256_make :: proc(name: string) -> ^INU {
    inu          := new(INU)
    inu.name      = name
    inu.id        = 0

    inu.read      = inu_c256_read
    inu.write     = inu_c256_write
    inu.delete    = inu_c256_delete

    m            := INU_C256{inu = inu}
    inu.model    = m
    return inu
} 

inu_c256_delete :: proc(inu: ^INU) {
	free(inu)
    return
}

inu_c256_read :: proc(inu: ^INU, size: BITS, base, busaddr: u32) -> (val: u32) {

    m         := &inu.model.(INU_C256)
	val        = m.mem[busaddr - base]
	return
}

inu_c256_write :: proc(inu: ^INU, size: BITS, base, busaddr, val: u32)  {

    m         := &inu.model.(INU_C256)
    addr      := busaddr - base

	switch addr {
        case 0x00, 0x01, 0x02, 0x03:   // UNSIGNED_MULT_A, UNSIGNED_MULT_B
			m.mem[addr] = val
			op1    := u16(m.mem[0x00]) + u16(m.mem[0x01]) << 8
			op2    := u16(m.mem[0x02]) + u16(m.mem[0x03]) << 8

			result := u32(op1 * op2)

			m.mem[0x04] = u32(result       & 0xff)
			m.mem[0x05] = u32(result >> 8  & 0xff)
			m.mem[0x06] = u32(result >> 16 & 0xff)
			m.mem[0x07] = u32(result >> 24 & 0xff)

        case 0x04, 0x05, 0x06, 0x07:   // UNSIGNED_MULT_result
                break

        case 0x08, 0x09, 0x0a, 0x0b:   // SIGNED_MULT_A, SIGNED_MULT_B
			m.mem[addr] = val
			op1    := i16(m.mem[0x08]) + i16(m.mem[0x09]) << 8
			op2    := i16(m.mem[0x0a]) + i16(m.mem[0x0b]) << 8

			result := i32(op1 * op2)

			m.mem[0x0c] = u32(result       & 0xff)
			m.mem[0x0d] = u32(result >> 8  & 0xff)
			m.mem[0x0e] = u32(result >> 16 & 0xff)
			m.mem[0x0f] = u32(result >> 24 & 0xff)

        case 0x0c, 0x0d, 0x0e, 0x0f:   // SIGNED_MULT_result
            break

        case 0x10, 0x11, 0x12, 0x13:   // UNSIGNED_DIV_DEM, UNSIGNED_DIV_NUM
			m.mem[addr] = val
			op1    := u16(m.mem[0x10]) + u16(m.mem[0x11]) << 8
			op2    := u16(m.mem[0x12]) + u16(m.mem[0x13]) << 8
					
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

        case 0x14, 0x15, 0x16, 0x17:   // UNSIGNED_DIV_result
                break

        case 0x18, 0x19, 0x1a, 0x1b:   // SIGNED_DIV_DEM, SIGNED_DIV_NUM
			m.mem[addr] = val
			op1    := i16(m.mem[0x18]) + i16(m.mem[0x19]) << 8
			op2    := i16(m.mem[0x1A]) + i16(m.mem[0x1B]) << 8
					
			result    : i16
            remainder : i16
			if (op1 != 0) {
					result = op2 / op1
					remainder = op2 % op1
			}

			m.mem[0x1C] = u32(result          & 0xff)
			m.mem[0x1D] = u32(result    >> 8  & 0xff)
			m.mem[0x1E] = u32(remainder       & 0xff)
			m.mem[0x1F] = u32(remainder >> 8  & 0xff)

        case 0x1c, 0x1d, 0x1e, 0x1f:   // SIGNED_DIV_result
                break

        case 0x20, 0x21, 0x22, 0x23,  // ADDER32_A
             0x24, 0x25, 0x26, 0x27:  // ADDER32_B

			m.mem[addr] = val
			op1    := i32(m.mem[0x20])       + 
					  i32(m.mem[0x21]) <<  8 + 
					  i32(m.mem[0x22]) << 16 + 
					  i32(m.mem[0x23]) << 24

			op2    := i32(m.mem[0x24])       + 
					  i32(m.mem[0x25]) << 8  + 
					  i32(m.mem[0x26]) << 16 + 
					  i32(m.mem[0x27]) << 24
			result := i32(op1 + op2)

			m.mem[0x28] = u32(result       & 0xff)
			m.mem[0x29] = u32(result >> 8  & 0xff)
			m.mem[0x2a] = u32(result >> 16 & 0xff) 
			m.mem[0x2b] = u32(result >> 24 & 0xff) 

        case 0x28, 0x29, 0x2a, 0x2b:   // ADDER32_result 
        	break

        case:
        	m.mem[addr] = val
	}
	return
}
