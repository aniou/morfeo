
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

    mlut:       [4][8]u32,
    mlut_active:       u32,        // 0-3 - currently active MLUT
    mlut_edit:      u32,        // what MLUT table we editing?
    edit_enable: bool,       // are we currently editing MLUT table?
    io_disable:  bool,       // if set then bank6 is mapped to memory
    io_bank:     u32,        // 0-3 - IO set
}

// XXX: parametrize make_bus routine - common enum or smth.
make_f256    :: proc(name: string, pic: ^pic.PIC) -> ^Bus {
    d        := new(Bus)
    d.name    = name
    d.pic0    = pic
    d.read    = read_f256
    d.write   = write_f256
    d.delete  = delete_f256

    // power-on init, XXX: add flash version, page 17 of manual
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

// bits A15...A13 are used to lookup to 8-element, 8 bit table
// and that result is shifted to positon A20-A13
//
read_f256 :: proc(bus: ^Bus, size: emu.Bitsize, addr: u32) -> (val: u32) {
    b     := &bus.model.(BUS_F256)
    bank  := addr & 0xE000              // A15..A13 from addr
    bank >>= 13

    switch addr {
    case  0x00_0000              :              // MMU_MEM_CTRL  edit/select mlut
        val |= 0x80 if b.edit_enable else 0
        val |= b.mlut_edit << 4
        val |= b.mlut_active
        return
    case  0x00_0001              :              // MMU_IO_CTRL   IO enable/select
        val |= 0x04 if b.io_disable  else 0
        val |= b.io_bank
        return
    case  0x00_0008 ..= 0x00_000F:              // MMU LUT if edit_enable == true
        if b.edit_enable {
            ea  := addr - 8
            val  = b.mlut[b.mlut_edit][ea] >> 20
            return
        }
    }

    if !b.io_disable && bank == 6 {
        switch b.io_bank {
        case 0x00: // low-level IO
        case 0x01: 
        // Text display font memory and graphics color MLUTs
        case 0x02: val = bus.gpu0->read(size, addr, addr - 0xC000, .TEXT)
        case 0x03: val = bus.gpu0->read(size, addr, addr - 0xC000, .TEXT_COLOR)
        case     : emu.read_not_implemented(#procedure, "IO", size, addr)
        }
        return
    }

    ea    := addr & 0x1FFF                  // A12..A0
    ea    |= b.mlut[b.mlut_active][bank]    // A20..A13
    switch ea {
    case  0x00_0002 ..= 0x07_FFFF: val = bus.ram0->read(size, 0x00, addr)                            // RAM   512
    case  0x08_0000 ..= 0x0F_FFFF: emu.read_not_implemented(#procedure, "ram2", size, addr)         // FLASH 512
    case  0x10_0000 ..= 0x13_FFFF: emu.read_not_implemented(#procedure, "ram3", size, addr)         // RAM   256   (expansion)
    case                         : emu.read_not_implemented(#procedure, "bus0", size, addr)
    }
    return
}
    //case 0x0000 ..= 0xFFFF:  val = bus.ram0->read(size, addr)


write_f256   :: proc(bus: ^Bus, size: emu.Bitsize, addr, val: u32) {
    b     := &bus.model.(BUS_F256)
    bank  := addr & 0xE000                      // A15..A13 from addr
    bank >>= 13

    switch addr {
    case  0x00_0000              :              // MMU_MEM_CTRL  edit/select mlut
        b.edit_enable = (val & 0x80) == 0x80
        b.mlut_edit   = (val & 0x30) >> 4 
        b.mlut_active = (val & 0x03)
        return
    case  0x00_0001              :              // MMU_IO_CTRL   IO enable/select
        b.io_disable  = (val & 0x04) == 0x04
        b.io_bank     = (val & 0x03)
        return
    case  0x00_0008 ..= 0x00_000F:              // MMU LUT if edit_enable == true
        if b.edit_enable {
            ea := addr - 8
            b.mlut[b.mlut_edit][ea] = val << 20
            return
        }
    }

    if !b.io_disable && bank == 6 {
        switch b.io_bank {
        case 0x00: // low-level IO
        case 0x01: // Text display font memory and graphics color MLUTs
            switch addr {
                case 0xC000 ..= 0xC7FF: bus.gpu0->write(size, addr, addr - 0xC000, val, .FONT_BANK0)
                case 0xC800 ..= 0xCFFF: bus.gpu0->write(size, addr, addr - 0xC800, val, .FONT_BANK1)
                case 0xD000 ..= 0xDFFF: bus.gpu0->write(size, addr, addr - 0xD000, val, .LUT)
            }
        case 0x02: bus.gpu0->write(size, addr, addr - 0xC000, val, .TEXT)
        case 0x03: bus.gpu0->write(size, addr, addr - 0xC000, val, .TEXT_COLOR)
        case     : emu.write_not_implemented(#procedure, "IO", size, addr, val)
        }
        return
    }

    ea    := addr & 0x1FFF                  // A12..A0
    ea    |= b.mlut[b.mlut_active][bank]    // A20..A13
    switch ea {
    case  0x00_0002 ..= 0x07_FFFF:  bus.ram0->write(size, 0x00_0000, addr, val)                      // RAM   512
    case  0x08_0000 ..= 0x0F_FFFF:  emu.write_not_implemented(#procedure, "ram2", size, addr, val)   // FLASH 512
    case  0x10_0000 ..= 0x13_FFFF:  emu.write_not_implemented(#procedure, "ram3", size, addr, val)   // RAM   256   (expansion)
    case                         :  emu.write_not_implemented(#procedure, "bus0", size, addr, val)
    }
    return
}

