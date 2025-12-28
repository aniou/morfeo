
package bus

import "core:log"
import "core:fmt"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:ram"

import "lib:emu"

import "core:prof/spall"

BUS_F256 :: struct {
    using bus: ^Bus,

    mlut_edit_en:    bool,  // is MLUT edited?
    mlut_active:      u32,  // 0-3 - currently active MLUT
    mlut_edited:      u32,  // 0-3 - currently edited MLUT

    mlut_mem:      [4][16]u32,  // raw mlut memory, used for addr 2,3 and 8 to 15
    mmu_mem:          [16]u32,  // raw mmu memory, exposed as helper or when !mlut_edit_en

    mlut_val:       [4][8]u32,  // re-calculated bits 0..8   of MLUT: moved to A20..A13
    mlut_ext:       [4][8]u32,  // re-calculated bits 9..10  of MLUT: moved to A22..A21
    mlut_cur:          [8]u32,  // reals addr for current mlut, usually mlut_val | mlut_ext

    io_disable:      bool,  // if set then bank6 is mapped to memory
    io_page:          u32,  // 0-3 - IO set
}

// XXX: parametrize make_bus routine - common enum or smth.
make_f256    :: proc(name: string, pic: ^pic.PIC) -> ^Bus {
    d        := new(Bus)
    d.name    = name
    d.pic0    = pic
    d.read    = read_f256_mmu
    d.write   = write_f256_mmu
    d.delete  = delete_f256

    // power-on init, XXX: add flash version, page 17 of manual
    // change to proper
    b          := BUS_F256{mlut_active = 0}
    b.mlut[0]   = {0 << 20, 1 << 20, 2 << 20, 3 << 20, 4 << 20, 5 << 20, 6 << 20, 7 << 20}
    b.mlut[1]   = {0 << 20, 1 << 20, 2 << 20, 3 << 20, 4 << 20, 5 << 20, 6 << 20, 7 << 20}
    b.mlut[2]   = {0 << 20, 1 << 20, 2 << 20, 3 << 20, 4 << 20, 5 << 20, 6 << 20, 7 << 20}
    b.mlut[3]   = {0 << 20, 1 << 20, 2 << 20, 3 << 20, 4 << 20, 5 << 20, 6 << 20, 7 << 20}

    d.model   = b
    return d
}

delete_f256 :: proc(bus: ^Bus) {
    free(bus)
    return
}

// not-defined reads returns $55
read_f256_mmu :: proc(bus: ^Bus, size: emu.Bitsize, addr: u32) -> (val: u32 = $55) {
    b     := &bus.model.(BUS_F256)
    bank  := addr & 0xE000                      // A15..A13 from addr - index in MLUT
    bank >>= 13
    ea    := addr & 0x1FFF                      // A12..A0
    ea    |= b.mlut_val[b.mlut_active][bank]    // A22..A13 from pre-calculated values

    switch addr {
    case 0x00      ..= 0x0F     : val = fetch_f256_mmu(b, addr, val)
                                  return
    case 0x10      ..= 0xEF_FFFF: // do not modify ea
    case 0xF0_0000 ..= 0xF3_FFFF: if b.move_io ea do ea = addr - 0xD8_0000
    case 0xF4_0000 ..= 0xF7_FFFF: if b.move_flash do ea = addr - 0xE4_0000
    case 0xF8_0000 ..= 0xFF_FFFF: if b.move_flash do ea = addr - 0xF0_0000
    }

    switch ea {
    case  0x00_0002 ..= 0x07_FFFF:  val = bus.ram0->read(size, 0x00_0000, ea)                          // SRAM0     512
    case  0x08_0000 ..= 0x0F_FFFF:  emu.read_not_implemented(#procedure, "flash0", size, addr, ea)     // FLASH     512
    case  0x10_0000 ..= 0x13_FFFF:  emu.read_not_implemented(#procedure, "cart0",  size, addr, ea)     // RAM/FLASH 256
    case  0x18_0000 ..= 0x18_FFFF:  emu.read_not_implemented(#procedure, "io0",    size, addr, ea)     // misc IO - XXX: tbd
    case  0x20_0000 ..= 0x27_FFFF:  val = bus.ram1->read(size, 0x20_0000, addr)                        // SRAM1     512
    case  0x40_0000 ..= 0x47_FFFF:  val = bus.ram2->read(size, 0x40_0000, addr)                        // SRAM2     512
    case  0x60_0000 ..= 0x67_FFFF:  val = bus.ram3->read(size, 0x60_0000, addr)                        // SRAM3     512
    case                         :  emu.read_not_implemented(#procedure, "bus0",   size, addr, ea)
    }
    return
}

write_f256_mmu :: proc(bus: ^Bus, size: emu.Bitsize, addr, val: u32) {
    b     := &bus.model.(BUS_F256)
    bank  := addr & 0xE000                      // A15..A13 from addr - index in MLUT
    bank >>= 13
    ea    := addr & 0x1FFF                      // A12..A0
    ea    |= b.mlut_val[b.mlut_active][bank]    // A22..A13 from pre-calculated values

    switch addr {
    case 0x00      ..= 0x0F     : val = fetch_f256_mmu(b, addr)
                                  return
    case 0x10      ..= 0xEF_FFFF: // do not modify ea
    case 0xF0_0000 ..= 0xF3_FFFF: if b.move_io ea do ea = addr - 0xD8_0000
    case 0xF4_0000 ..= 0xF7_FFFF: if b.move_flash do ea = addr - 0xE4_0000
    case 0xF8_0000 ..= 0xFF_FFFF: if b.move_flash do ea = addr - 0xF0_0000
    }

    switch ea {
    case  0x00_0002 ..= 0x07_FFFF:  bus.ram0->write(size, 0x00_0000, ea, val)                            // SRAM0     512
    case  0x08_0000 ..= 0x0F_FFFF:  emu.write_not_implemented(#procedure, "flash0", size, addr, val, ea) // FLASH     512
    case  0x10_0000 ..= 0x13_FFFF:  emu.write_not_implemented(#procedure, "cart0",  size, addr, val, ea) // RAM/FLASH 256
    case  0x18_0000 ..= 0x18_FFFF:  emu.write_not_implemented(#procedure, "io0",    size, addr, val, ea) // misc IO - XXX: tbd
    case  0x20_0000 ..= 0x27_FFFF:  bus.ram1->write(size, 0x20_0000, ea, val)                            // SRAM1     512
    case  0x40_0000 ..= 0x47_FFFF:  bus.ram2->write(size, 0x40_0000, ea, val)                            // SRAM2     512
    case  0x60_0000 ..= 0x67_FFFF:  bus.ram3->write(size, 0x60_0000, ea, val)                            // SRAM3     512
    case                         :  emu.write_not_implemented(#procedure, "bus0", size, addr, val, ea)
    }
}

// memory handling strategy for MMU 
// 0..1   - always in mmu_mem[0..1]
// 2..3   - if  edit_enable then in mlut_mem[mlut_edit][2..3]
//          if !edit_enable then in mmu_mem[2..3]
// 4..7   - always in mmu_mem[4..7]
// 8..15  - if  edit_enable then in mlut_mem[mlut_edit][8..15]
//          if !edit_enable then in mmu_mem[8..15]

fetch_f256_mmu :: proc(b: ^BUS_F256, addr) -> (val: u32) {
    switch addr {
    case  0x00 ..= 0x01: val = mmu_mem[addr]
    case  0x02 ..= 0x03: val = mmu_mem[addr] if !b.mlut_edit else  b.mlut_mem[b.mlut_edited][addr] 
    case  0x04 ..= 0x07: val = mmu_mem[addr]
    case  0x08 ..= 0x0F: val = mmu_mem[addr] if !b.mlut_edit else  b.mlut_mem[b.mlut_edited][addr]
    }
}

update_f256_mmu :: proc(b: ^BUS_F256, addr, val) {
    switch addr {
    case  0x00:
        mmu_mem[0]     = val
        b.mlut_edit_en = (val & 0x80) == 0x80
        b.mlut_edited  = (val & 0x30) >> 4 
        b.sram_en      = (val & 0x08) == 0x08    // core2x: flat access to SRAM
        b.mlut_active  = (val & 0x03)
    case  0x01:
        mmu_mem[1]     = val
        b.io_disable   = (val & 0x04) == 0x04
        b.io_page      = (val & 0x03)
        b.io_page     |= (val & 0x08) >> 1       // core2x: IO_PAGE_EXT
        b.move_io      = (val & 0x10) == 0x10    // core2x: IO to F0:0000
        b.move_flash   = (val & 0x20) == 0x20    // core2x: IO to F4:0000 and F8:0000
        b.sprite_high  = (val & 0x40) == 0x40    // core2x: 0 - sprite 0-63, 1 - sprite 64-127
    case  0x02:
        if !b.mlut_edit_en {
            mmu_mem[2] = val
            return
        }
        b.mlut_mem[b.mlut_edited][2]  = val

        b.mlut_ext[b.mlut_edited][0]  = (val & 0x03) << 22
        b.mlut_ext[b.mlut_edited][1]  = (val & 0x0c) << 20
        b.mlut_ext[b.mlut_edited][2]  = (val & 0x30) << 18
        b.mlut_ext[b.mlut_edited][3]  = (val & 0xc0) << 16
    case  0x03: 
        if !b.mlut_edit_en {
            mmu_mem[3] = val
            return
        }
        b.mlut_mem[b.mlut_edited][3]  = val

        b.mlut_ext[b.mlut_edited][4]  = (val & 0x03) << 22
        b.mlut_ext[b.mlut_edited][5]  = (val & 0x0c) << 20
        b.mlut_ext[b.mlut_edited][6]  = (val & 0x30) << 18
        b.mlut_ext[b.mlut_edited][7]  = (val & 0xc0) << 16
    case  0x04 ..= 0x07:        // normal memory, but handled here
        mmu_mem[addr] = val
        return
    case  0x08 ..= 0x0F: 
        if !b.mlut_edit_en {
            mmu_mem[addr] = val
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

