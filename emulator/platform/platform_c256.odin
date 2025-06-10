package platform

import "emulator:ata"
import "emulator:bus"
import "emulator:cpu"
import "emulator:intu"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:rtc"
import "emulator:ram"

import "core:fmt"
import "core:log"

import "lib:emu"

c256_make :: proc(type: emu.Type) -> ^Platform {
    mem        := 0x40_0000 if type == .C256Uplus else 0x20_0000

    p          := new(Platform)
    pic        := pic.pic_c256_make ("pic0")         // XXX: dummy, so far
    p.bus       = bus.c256_make     ("bus0", pic, type)
    p.bus.ram0  = ram.make_ram      ("ram0", mem)
    p.bus.gpu0  = gpu.vicky2_make   ("gpu0", pic, 0, 0)   // XXX: fake DIP switch
    p.bus.ps2   = ps2.ps2_make      ("ps2",  pic)
    p.bus.rtc   = rtc.bq4802_make   ("rtc0", pic)
    p.bus.intu  = intu.intu_c256_make("math0")
    p.cpu       = cpu.make_w65c816  ("cpu0", p.bus)
    p.delete    = c256_delete
    p.init      = c256_init

    return p
}

c256_delete :: proc(p: ^Platform) {
    p.bus.gpu0->delete()
     p.bus.pic->delete()
     p.bus.ps2->delete()
    p.bus.ram0->delete()
     p.bus.rtc->delete()
    p.bus.intu->delete()
         p.cpu->delete()
         p.bus->delete()

    free(p);
    return
}

c256_init :: proc(p: ^Platform) {

    // On boot, Gavin copies the first 64KB of the content of System Flash                                                          
    // (or User Flash, if present) to Bank $00.  The entire 512KB are copied 
    // to address range $18:0000 to $1F:FFFF (or 38:000 to 3F:FFFF)

    // act ersatz - copy jump table
    for j in u32(0x1000) ..< u32(0x2000) {
    	val := p.bus->read(.bits_8, 0x38_0000 + j)
    	p.bus->write(.bits_8, j, val)
    }
 
    // probably redundant
    p.bus->write(.bits_8, 0xFFFC, 0x00)
    p.bus->write(.bits_8, 0xFFFD, 0x10)

}

