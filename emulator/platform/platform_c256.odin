package platform

import "emulator:ata"
import "emulator:bus"
import "emulator:cpu"
import "emulator:inu"
import "emulator:joy"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:rtc"
import "emulator:ram"
import "emulator:rng"
import "emulator:timer"

import "core:fmt"
import "core:log"

import "lib:emu"
 
// XXX: I'm not sure how, but version after version a init routine
// have been evolving into disharmony. It was inevitable, I presume.
//
c256_make :: proc(config: ^emu.Config) -> (p: ^Platform, ok: bool = true)  {
    p            = new(Platform)
    p.cfg        = config
    p.bus        = bus.make_c256      ("bus0", config)
    p.cpu        = cpu.make_w65c816   ("cpu0", p.bus )

    // temporary block, used for passing parameters
    dcb         := new(emu.DeviceConfig)
    dcb.cfg      = config
    dcb.req      = &p.bus.req
    defer free(dcb)

    pic         :=   pic.make_pic_c256  ("pic0",   dcb)
    p.bus.pic0   =   pic
    p.bus.ram0   =   ram.make_ram       ("ram0",   dcb,        size = emu.SRAMSIZE)
    p.bus.gpu0   =   gpu.make_vicky2    ("gpu0",   dcb,  pic,  size = emu.VRAMSIZE)
    p.bus.gpu1   =   gpu.make_C200      ("gpu1",   dcb,  pic,  size = emu.VRAMSIZE)
    p.bus.ps20   =   ps2.make_ps2       ("ps2",    dcb,  pic)
    p.bus.rtc0   =   rtc.make_bq4802    ("rtc0",   dcb,  pic)
    p.bus.inu0   =   inu.make_inu_c256  ("inu0",   dcb)
    p.bus.ata0   =   ata.make_pata      ("ata0",   dcb)                     // XXX - update to PIC
    p.bus.timer0 = timer.timer_c256_make("timer0", dcb,  pic,  id = 0)
    p.bus.timer1 = timer.timer_c256_make("timer1", dcb,  pic,  id = 1)
    p.bus.timer2 = timer.timer_c256_make("timer2", dcb,  pic,  id = 2)
    p.bus.joy0   =   joy.make_joy_c256  ("joy0",   dcb)
    p.bus.rng    =   rng.make_rng_c256  ("rng0",   dcb)
    

    p.delete     = c256_delete
    p.init       = c256_init

    return
}

c256_delete :: proc(p: ^Platform) {
         p.cpu->delete()
    p.bus.ata0->delete()
    p.bus.gpu0->delete()
    p.bus.gpu1->delete()
  p.bus.timer0->delete()
  p.bus.timer1->delete()
  p.bus.timer2->delete()
    p.bus.rtc0->delete()
    p.bus.ps20->delete()
    p.bus.ram0->delete()
    p.bus.inu0->delete()
    p.bus.pic0->delete()
    p.bus.joy0->delete()
     p.bus.rng->delete()
         p.bus->delete()

    free(p);
    return
}

c256_init :: proc(p: ^Platform) {

    // On boot, Gavin copies the first 64KB of the content of System Flash                                                          
    // (or User Flash, if present) to Bank $00.  The entire 512KB are copied 
    // to address range $18:0000 to $1F:FFFF (or 38:000 to 3F:FFFF)

}

