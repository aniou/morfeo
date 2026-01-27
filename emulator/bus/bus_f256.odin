package bus

import "core:log"
import "core:fmt"


import "emulator:ata"
import "emulator:gpu"
import "emulator:inu"
import "emulator:joy"
import "emulator:kbd"
import "emulator:pic"
import "emulator:ps2"                                                                                                                  
import "emulator:rtc"
import "emulator:ram"
import "emulator:rng"
import "emulator:timer"     
import "emulator:tty"

import "lib:emu"

import "core:prof/spall"

DEVICE :: union {
    ^gpu.GPU,
    ^pic.PIC,
    ^ps2.PS2,
    ^ram.RAM,
}

BUS_F256 :: struct {
    using bus: ^Bus,

    mlut_edit_en:    bool,  // is MLUT edited?
    mlut_active:      u32,  // 0-3 - currently active MLUT
    mlut_edited:      u32,  // 0-3 - currently edited MLUT

    mlut_mem:  [4][16]u32,  // raw mlut memory, used for addr 2,3 and 8 to 15
    mmu_mem:      [16]u32,  // raw mmu memory, exposed as helper or when !mlut_edit_en

    mlut_val:   [4][8]u32,  // re-calculated bits 0..8   of MLUT: moved to A20..A13
    mlut_ext:   [4][8]u32,  // re-calculated bits 9..10  of MLUT: moved to A22..A21
    mlut_cur:      [8]u32,  // reals addr for current mlut, usually mlut_val | mlut_ext

    machine_id:    [9]u32,  // read-only array of machine ID data
    pcb_id:        [5]u32,  // read-only array of pcb ID data

    sprite_high:     bool,
    sram_en:         bool,
    move_io:         bool,
    move_flash:      bool,
    io_disable:      bool,  // if set then bank6 is mapped to memory
    io_page:          u32,  // 0-3 - IO set
}

// XXX: parametrize make_bus routine - common enum or smth.
// XXX: power-on init, add ram/flash version, page 17 of manual
make_f256 :: proc(name: string, config: ^emu.Config) -> ^Bus {
    bus        := new(Bus)
    bus.name    = name
    bus.model   = BUS_F256{bus = bus}

	init_f256_mmu(bus)

    return bus
}

init_f256_mmu :: proc(bus: ^Bus) {
	b := &bus.model.(BUS_F256)

    write_f256_mmu(b, 0, 0x80)
    mlut_values := []u32{0, 1, 2, 3, 4, 5, 6, 0x7f} 
    for val, index in mlut_values  {
        write_f256_mmu(b, u32(index)+8, val)
    }
    write_f256_mmu(b, 0, 0x00) // lock edit to prevent overflow by stack during debug runs

    for index in 0 ..= 7 {
        log.debugf("%s MLUT %i %16b %08x", #procedure, index, b.mlut_cur[index], b.mlut_cur[index])
    }

    // id data
    b.machine_id = [9]u32{0x91, 0x30, 0x43, 0x13, 0x00, 0x01, 0x02, 0x02, 0x56}
    //b.machine_id = [9]u32{0x12, 0x30, 0x43, 0x13, 0x00, 0x01, 0x02, 0x02, 0x56}
    b.pcb_id     = [5]u32{0x42, 0x30, 0x18, 0x01, 0x23}
}

delete_f256 :: proc(bus: ^Bus) {
    free(bus)
    return
}

read_f256 :: proc(bus: ^Bus, mode: MODE, addr: u32) -> (out: u32) {
   // return f256_io_via_mmu(d, .READ8, ra, 0)
   return
}

write_f256 :: proc(bus: ^Bus, mode: MODE, ra, val: u32)  {
   // f256_io_via_mmu(d, .WRITE8, ra, val)
}

/*
f256_io_via_mmu :: #force_inline proc(b: ^B256, op: OPER, ra, val: u32) -> (out: u32 = 0x55) {
    b.req.ra     = ra
    b.req.bank   = ra & 0xE000                      // A15..A13 from req - index in MLUT
    b.req.bank >>= 13
    b.req.ea     = ra & 0x1FFF                      // A12..A0
    b.req.ea    |= b.mlut_cur[b.req.bank]                 // A22..A13 from pre-calculated values
    b.req.op     = op
    b.req.val    = val

    switch ra {
    case 0x00      ..= 0x0F     : 
        #partial switch op {
        case .READ8 : out =  f256_mmu_read(b, ra)
        case .WRITE8:        f256_mmu_write(b, ra, val)
        }
        return
    case 0x10      ..= 0xEF_FFFF: // do not modify ea
    case 0xF0_0000 ..= 0xF3_FFFF: if b.move_io    do b.req.ea = ra - 0xD8_0000
    case 0xF4_0000 ..= 0xF7_FFFF: if b.move_flash do b.req.ea = ra - 0xE4_0000
    case 0xF8_0000 ..= 0xFF_FFFF: if b.move_flash do b.req.ea = ra - 0xF0_0000
    }

    switch b.req.ea {
    case  0x00_0002 ..= 0x07_FFFF:  
    case  0x08_0000 ..= 0x0F_FFFF:  out = ram.io(b.flash0, b.req, 0x08_0000, .MAIN)
    }
    return
}
*/

// memory handling strategy for MMU 
// 0..1   - always in mmu_mem[0..1]
// 2..3   - if  edit_enable then in mlut_mem[mlut_edit][2..3]
//          if !edit_enable then in mmu_mem[2..3]
// 4..7   - always in mmu_mem[4..7]
// 8..15  - if  edit_enable then in mlut_mem[mlut_edit][8..15]
//          if !edit_enable then in mmu_mem[8..15]
read_f256_mmu :: proc(b: ^BUS_F256, addr: u32) -> (val: u32) {
    switch addr {
    case  0x00 ..= 0x01: val = b.mmu_mem[addr]
    case  0x02 ..= 0x03: val = b.mmu_mem[addr] if !b.mlut_edit_en else  b.mlut_mem[b.mlut_edited][addr] 
    case  0x04 ..= 0x07: val = b.mmu_mem[addr]
    case  0x08 ..= 0x0F: val = b.mmu_mem[addr] if !b.mlut_edit_en else  b.mlut_mem[b.mlut_edited][addr]
    }
    return
}

write_f256_mmu :: proc(b: ^BUS_F256, addr, val: u32) {
    switch addr {
    case  0x00:
        b.mmu_mem[0]   = val
        b.mlut_edit_en = (val & 0x80) == 0x80
        b.mlut_edited  = (val & 0x30) >> 4 
        b.sram_en      = (val & 0x08) == 0x08    // core2x: flat access to SRAM
        b.mlut_active  = (val & 0x03)
    case  0x01:
        b.mmu_mem[1]   = val
        b.io_disable   = (val & 0x04) == 0x04
        b.io_page      = (val & 0x03)
        b.io_page     |= (val & 0x08) >> 1       // core2x: IO_PAGE_EXT
        b.move_io      = (val & 0x10) == 0x10    // core2x: IO to F0:0000
        b.move_flash   = (val & 0x20) == 0x20    // core2x: IO to F4:0000 and F8:0000
        b.sprite_high  = (val & 0x40) == 0x40    // core2x: 0 - sprite 0-63, 1 - sprite 64-127
    case  0x02:
        if !b.mlut_edit_en {
            b.mmu_mem[2] = val
            return
        }
        b.mlut_mem[b.mlut_edited][2]  = val

        b.mlut_ext[b.mlut_edited][0]  = (val & 0x03) << 22
        b.mlut_ext[b.mlut_edited][1]  = (val & 0x0c) << 20
        b.mlut_ext[b.mlut_edited][2]  = (val & 0x30) << 18
        b.mlut_ext[b.mlut_edited][3]  = (val & 0xc0) << 16
    case  0x03: 
        if !b.mlut_edit_en {
            b.mmu_mem[3] = val
            return
        }
        b.mlut_mem[b.mlut_edited][3]  = val

        b.mlut_ext[b.mlut_edited][4]  = (val & 0x03) << 22
        b.mlut_ext[b.mlut_edited][5]  = (val & 0x0c) << 20
        b.mlut_ext[b.mlut_edited][6]  = (val & 0x30) << 18
        b.mlut_ext[b.mlut_edited][7]  = (val & 0xc0) << 16
    case  0x04 ..= 0x07:        // normal memory, but handled here
        b.mmu_mem[addr] = val
        return
    case  0x08 ..= 0x0F: 
        if !b.mlut_edit_en {
            b.mmu_mem[addr] = val
            return
        }
        b.mlut_mem[b.mlut_edited][addr    ] = val
        b.mlut_val[b.mlut_edited][addr - 8] = val << 13
    }

    // in some cases that update is redundant, but I'm not convinced
    // that we need micro-optimization with `lut_updated: bool` here

    mlut          := b.mlut_active
    b.mlut_cur[0]  = b.mlut_val[mlut][0] | b.mlut_ext[mlut][0]
    b.mlut_cur[1]  = b.mlut_val[mlut][1] | b.mlut_ext[mlut][1]
    b.mlut_cur[2]  = b.mlut_val[mlut][2] | b.mlut_ext[mlut][2]
    b.mlut_cur[3]  = b.mlut_val[mlut][3] | b.mlut_ext[mlut][3]
    b.mlut_cur[4]  = b.mlut_val[mlut][4] | b.mlut_ext[mlut][4]
    b.mlut_cur[5]  = b.mlut_val[mlut][5] | b.mlut_ext[mlut][5]
    b.mlut_cur[7]  = b.mlut_val[mlut][7] | b.mlut_ext[mlut][7]

    if b.io_disable {
        b.mlut_cur[6] = b.mlut_val[mlut][6] | b.mlut_ext[mlut][6]
    } else {
        b.mlut_cur[6] = (b.io_page + 0xc0) << 13
    }

}

