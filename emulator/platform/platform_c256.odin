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


c256_make :: proc(config: ^emu.Config) -> (p: ^Platform, ok: bool = true)  {
    ramsize  : int
    vramsize : int

    switch config.model {
        case .C256FMX: 
            ramsize  = 4 * 1024*1024
            vramsize = 4 * 1024*1024
        case .C256UPLUS: 
            ramsize  = 4 * 1024*1024
            vramsize = 2 * 1024*1024
        case .C256U: 
            ramsize  = 2 * 1024*1024
            vramsize = 2 * 1024*1024
        case:
            log.errorf("Unknown platform type: %v", config.model)
            ok = false
            return
    }

    p           = new(Platform)
    pic        := pic.pic_c256_make  ("pic0")
    p.bus       = bus.c256_make      ("bus0", pic)
    p.bus.ram0  = ram.make_ram       ("ram0", ramsize)
    p.bus.gpu0  = gpu.vicky2_make    ("gpu0", pic, 0, vramsize, config.dip)
    p.bus.ps2   = ps2.ps2_make       ("ps2",  pic, config.model)
    p.bus.rtc   = rtc.bq4802_make    ("rtc0", pic)
    p.bus.intu  = intu.intu_c256_make("math0")
    p.bus.ata0  = ata.pata_make      ("pata0")          // XXX - update to PIC
    p.cpu       = cpu.make_w65c816   ("cpu0", p.bus)
    p.delete    = c256_delete
    p.init      = c256_init
    p.model     = config.model

    return
}

c256_delete :: proc(p: ^Platform) {
         p.cpu->delete()
    p.bus.ata0->delete()
    p.bus.gpu0->delete()
     p.bus.pic->delete()
     p.bus.ps2->delete()
    p.bus.ram0->delete()
     p.bus.rtc->delete()
    p.bus.intu->delete()
         p.bus->delete()

    free(p);
    return
}

c256_init :: proc(p: ^Platform) {

    // On boot, Gavin copies the first 64KB of the content of System Flash                                                          
    // (or User Flash, if present) to Bank $00.  The entire 512KB are copied 
    // to address range $18:0000 to $1F:FFFF (or 38:000 to 3F:FFFF)

    source : u32 = 0x18_0000 if p.model == .C256U else 0x38_0000

    // act ersatz - copy jump table
    for j in u32(0x1000) ..< u32(0x2000) {
    	val := p.bus->read(.bits_8, source + j)
    	p.bus->write(.bits_8, j, val)
    }
 
    // probably redundant
    p.bus->write(.bits_8, 0xFFFC, 0x00)
    p.bus->write(.bits_8, 0xFFFD, 0x10)

}

