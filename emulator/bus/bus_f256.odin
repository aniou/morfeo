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
    using base: ^Bus,

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
    bus           := new(Bus)
    bus.name       = name
    bus.req.has_pc = true
    bus.model      = BUS_F256{base = bus}


    bus.delete  = delete_f256
    bus.read    =   read_f256_with_mmu
    bus.write   =  write_f256_with_mmu

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

read_f256_with_mmu :: proc(bus: ^Bus, mode: MODE, ra: u32) -> (out: u32) {
    b          := &bus.model.(BUS_F256)

    bus.req.ra         = ra
    bus.req.mmu_bank   = ra & 0xE000                   // A15..A13 from req - index in MLUT
    bus.req.mmu_bank >>= 13
    bus.req.ea         = ra & 0x1FFF                   // A12..A0
    bus.req.ea        |= b.mlut_cur[bus.req.mmu_bank]  // A22..A13 from pre-calculated values

    switch ra {
    case 0x00      ..= 0x0F     : out = read_f256_mmu(b, ra)
                                  return
    case 0x10      ..= 0xEF_FFFF: // do not modify ea
    case 0xF0_0000 ..= 0xF3_FFFF: if b.move_io    do bus.req.ea = ra - 0xD8_0000
    case 0xF4_0000 ..= 0xF7_FFFF: if b.move_flash do bus.req.ea = ra - 0xE4_0000
    case 0xF8_0000 ..= 0xFF_FFFF: if b.move_flash do bus.req.ea = ra - 0xF0_0000
    }

   switch bus.req.ea {
    case  0x00_0002 ..= 0x07_FFFF: out =    bus.ram0->read(mode, bus.req.ea - 0x00_0000              ) // SRAM0     512
    case  0x08_0000 ..= 0x0F_FFFF: out =  bus.flash0->read(mode, bus.req.ea - 0x08_0000              ) // FLASH     512
    case  0x10_0000 ..= 0x13_FFFF: out =   bus.cart0->read(mode, bus.req.ea - 0x10_0000              ) // RAM/FLASH 256
    case  0x18_1000 ..= 0x18_101B: out =    bus.gpu0->read(mode, bus.req.ea - 0x18_1000, .MAIN       )
    case  0x18_1622              : out =   0 // XXX: just for test
    case  0x18_1650 ..= 0x18_1657: out =  bus.timer0->read(mode, bus.req.ea - 0x18_1650              )
    case  0x18_1658 ..= 0x18_165F: out =  bus.timer1->read(mode, bus.req.ea - 0x18_1658              )
    case  0x18_1660 ..= 0x18_166E: out =    bus.pic0->read(mode, bus.req.ea - 0x18_1660              )
    case  0x18_1690 ..= 0x18_169F: out =    bus.rtc0->read(mode, bus.req.ea - 0x18_1690              ) 
    case  0x18_16A0              : out =    0x80 // XXX: workaround, SD_CD = true *see 17.1 table [manual]
    case  0x18_16A7 ..= 0x18_16AF: out =      b.machine_id[bus.req.ea - 0x18_16A7]
    case  0x18_16EB ..= 0x18_16EF: out =          b.pcb_id[bus.req.ea - 0x18_16EB]
    case  0x18_1800 ..= 0x18_183F: out =    bus.gpu0->read(mode, bus.req.ea - 0x18_1800, .TEXT_FG_LUT)
    case  0x18_1840 ..= 0x18_187F: out =    bus.gpu0->read(mode, bus.req.ea - 0x18_1840, .TEXT_BG_LUT)
    case  0x18_1C00 ..= 0x18_1C01: out =    0 // XXX: fake VIA
    case  0x18_1D00 ..= 0x18_1D01: out =    bus.sdc0->read(mode, bus.req.ea - 0x18_1D00              )
    case  0x18_1D63              : out =    1 // XXX: workaround, lack of SPI
    case  0x18_1DC0 ..= 0x18_1DC3: out =    bus.kbd0->read(mode, bus.req.ea - 0x18_1DC0              )
    case  0x18_1E00 ..= 0x18_1E1B: out =    bus.inu0->read(mode, bus.req.ea - 0x18_1E00              )
    case  0x18_2000 ..= 0x18_277F: out =    bus.gpu0->read(mode, bus.req.ea - 0x18_2000, .FONT_BANK0 )
    case  0x18_4000 ..= 0x18_5FFF: out =    bus.gpu0->read(mode, bus.req.ea - 0x18_4000, .TEXT       )
    case  0x18_6000 ..= 0x18_7FFF: out =    bus.gpu0->read(mode, bus.req.ea - 0x18_6000, .TEXT_COLOR )

    case  0x18_0000 ..= 0x18_FFFF:          emu.error_read(bus.name, &bus.req, .NOT_IMPL, mode, bus.req.ea)
    case  0x20_0000 ..= 0x27_FFFF: out =    bus.ram1->read(mode, bus.req.ea - 0x20_0000               ) // SRAM1     512
    case  0x40_0000 ..= 0x47_FFFF: out =    bus.ram2->read(mode, bus.req.ea - 0x40_0000               ) // SRAM2     512
    case  0x60_0000 ..= 0x67_FFFF: out =    bus.ram3->read(mode, bus.req.ea - 0x60_0000               ) // SRAM3     512
    case                         :          emu.error_read(bus.name, &bus.req, .NOT_IMPL, mode, bus.req.ea)
    }

    return
}

write_f256_with_mmu :: proc(bus: ^Bus, mode: MODE, ra, val: u32) {
    b          := &bus.model.(BUS_F256)

    bus.req.ra         = ra
    bus.req.mmu_bank   = ra & 0xE000                   // A15..A13 from req - index in MLUT
    bus.req.mmu_bank >>= 13
    bus.req.ea         = ra & 0x1FFF                   // A12..A0
    bus.req.ea        |= b.mlut_cur[bus.req.mmu_bank]  // A22..A13 from pre-calculated values

    switch ra {
    case 0x00      ..= 0x0F     : write_f256_mmu(b, ra, val)
                                  return
    case 0x10      ..= 0xEF_FFFF: // do not modify ea
    case 0xF0_0000 ..= 0xF3_FFFF: if b.move_io    do bus.req.ea = ra - 0xD8_0000
    case 0xF4_0000 ..= 0xF7_FFFF: if b.move_flash do bus.req.ea = ra - 0xE4_0000
    case 0xF8_0000 ..= 0xFF_FFFF: if b.move_flash do bus.req.ea = ra - 0xF0_0000
    }

   switch bus.req.ea {
    case  0x00_0002 ..= 0x07_FFFF:    bus.ram0->write(mode, bus.req.ea - 0x00_0000, val              ) // SRAM0     512
    case  0x08_0000 ..= 0x0F_FFFF:  bus.flash0->write(mode, bus.req.ea - 0x08_0000, val              ) // FLASH     512
    case  0x10_0000 ..= 0x13_FFFF:   bus.cart0->write(mode, bus.req.ea - 0x10_0000, val              ) // RAM/FLASH 256
    case  0x18_1000 ..= 0x18_101B:    bus.gpu0->write(mode, bus.req.ea - 0x18_1000, val, .MAIN       )
    case  0x18_1650 ..= 0x18_1657:  bus.timer0->write(mode, bus.req.ea - 0x18_1650, val              )
    case  0x18_1658 ..= 0x18_165F:  bus.timer1->write(mode, bus.req.ea - 0x18_1658, val              )
    case  0x18_1660 ..= 0x18_166E:    bus.pic0->write(mode, bus.req.ea - 0x18_1660, val              )
    case  0x18_1690 ..= 0x18_169F:    bus.rtc0->write(mode, bus.req.ea - 0x18_1690, val              ) 
    case  0x18_1800 ..= 0x18_183F:    bus.gpu0->write(mode, bus.req.ea - 0x18_1800, val, .TEXT_FG_LUT)
    case  0x18_1840 ..= 0x18_187F:    bus.gpu0->write(mode, bus.req.ea - 0x18_1840, val, .TEXT_BG_LUT)
    case  0x18_1D00 ..= 0x18_1D01:    bus.sdc0->write(mode, bus.req.ea - 0x18_1D00, val              )
    case  0x18_1DC0 ..= 0x18_1DC3:    bus.kbd0->write(mode, bus.req.ea - 0x18_1DC0, val              )
    case  0x18_1E00 ..= 0x18_1E1B:    bus.inu0->write(mode, bus.req.ea - 0x18_1E00, val              )
    case  0x18_2000 ..= 0x18_277F:    bus.gpu0->write(mode, bus.req.ea - 0x18_2000, val, .FONT_BANK0 )
    case  0x18_4000 ..= 0x18_5FFF:    bus.gpu0->write(mode, bus.req.ea - 0x18_4000, val, .TEXT       )
    case  0x18_6000 ..= 0x18_7FFF:    bus.gpu0->write(mode, bus.req.ea - 0x18_6000, val, .TEXT_COLOR )

    case  0x18_0000 ..= 0x18_FFFF:   emu.error_write(bus.name, &bus.req, .NOT_IMPL, mode, bus.req.ea, val)
    case  0x20_0000 ..= 0x27_FFFF:    bus.ram1->write(mode, bus.req.ea - 0x20_0000, val               ) // SRAM1     512
    case  0x40_0000 ..= 0x47_FFFF:    bus.ram2->write(mode, bus.req.ea - 0x40_0000, val               ) // SRAM2     512
    case  0x60_0000 ..= 0x67_FFFF:    bus.ram3->write(mode, bus.req.ea - 0x60_0000, val               ) // SRAM3     512
    case                         :   emu.error_write(bus.name, &bus.req, .NOT_IMPL, mode, bus.req.ea,  val)
    }

    return
}

// memory handling strategy for MMU 
// 0..1   - always in mmu_mem[0..1]
// 2..3   - if  edit_enable then in mlut_mem[mlut_edit][2..3]
//          if !edit_enable then in mmu_mem[2..3]
// 4..7   - always in mmu_mem[4..7]
// 8..15  - if  edit_enable then in mlut_mem[mlut_edit][8..15]
//          if !edit_enable then in mmu_mem[8..15]
read_f256_mmu :: proc(b: ^BUS_F256, addr: u32) -> (out: u32) {
    switch addr {
    case  0x00 ..= 0x01: out = b.mmu_mem[addr]
    case  0x02 ..= 0x03: out = b.mmu_mem[addr] if !b.mlut_edit_en else  b.mlut_mem[b.mlut_edited][addr] 
    case  0x04 ..= 0x07: out = b.mmu_mem[addr]
    case  0x08 ..= 0x0F: out = b.mmu_mem[addr] if !b.mlut_edit_en else  b.mlut_mem[b.mlut_edited][addr]
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

// eof
