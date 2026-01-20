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

c256_make :: proc(config: ^emu.Config) -> (p: ^Platform, ok: bool = true)  {
    p            = new(Platform)
    p.bus        =   bus.make_c256      ("bus0",                      config)
    pic         :=   pic.pic_c256_make  ("pic0")
    p.bus.pic0   =   pic
    p.bus.ram0   =   ram.make_ram       ("ram0",        emu.SRAMSIZE)
    p.bus.gpu0   =   gpu.make_vicky2    ("gpu0",   pic, emu.VRAMSIZE, config)
    p.bus.gpu1   =   gpu.make_C200      ("gpu1",   pic, emu.VRAMSIZE, config)
    p.bus.ps20   =   ps2.ps2_make       ("ps2",    pic)
    p.bus.rtc0   =   rtc.bq4802_make    ("rtc0",   pic)
    p.bus.inu0   =   inu.inu_c256_make  ("inu0")
    p.bus.ata0   =   ata.pata_make      ("ata0")          // XXX - update to PIC
    p.bus.timer0 = timer.timer_c256_make("timer0", pic, 0)
    p.bus.timer1 = timer.timer_c256_make("timer1", pic, 1)
    p.bus.timer2 = timer.timer_c256_make("timer2", pic, 2)
    p.bus.joy0   =   joy.joy_c256_make  ("joy0")
    p.bus.rng    =   rng.rng_c256_make  ("rng0")
    p.cpu        =   cpu.make_w65c816   ("cpu0", p.bus)
    
    p.cfg        = config

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

