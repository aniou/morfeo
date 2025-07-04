package platform

import "emulator:ata"
import "emulator:bus"
import "emulator:cpu"
import "emulator:inu"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:rtc"
import "emulator:ram"
import "emulator:timer"

import "core:fmt"
import "core:log"

import "lib:emu"

c256_make :: proc(config: ^emu.Config) -> (p: ^Platform, ok: bool = true)  {
    p            = new(Platform)
    pic         :=   pic.pic_c256_make  ("pic0")
    p.bus        =   bus.c256_make      ("bus0",   pic,                  config)
    p.bus.ram0   =   ram.ram_make       ("ram0",           emu.SRAMSIZE)
    p.bus.gpu0   =   gpu.vicky2_make    ("gpu0",   pic, 0, emu.VRAMSIZE, config)
    p.bus.gpu1   =   gpu.C200_make      ("gpu1",   pic, 1, emu.VRAMSIZE, config)
    p.bus.ps20   =   ps2.ps2_make       ("ps2",    pic)
    p.bus.rtc0   =   rtc.bq4802_make    ("rtc0",   pic)
    p.bus.inu0   =   inu.inu_c256_make  ("inu0")
    p.bus.ata0   =   ata.pata_make      ("ata0")          // XXX - update to PIC
    p.bus.timer0 = timer.timer_c256_make("timer0", pic, 0)
    p.bus.timer1 = timer.timer_c256_make("timer1", pic, 1)
    p.bus.timer2 = timer.timer_c256_make("timer2", pic, 2)
    p.cpu        =   cpu.make_w65c816   ("cpu0", p.bus)

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
         p.bus->delete()

    free(p);
    return
}

c256_init :: proc(p: ^Platform) {

    // On boot, Gavin copies the first 64KB of the content of System Flash                                                          
    // (or User Flash, if present) to Bank $00.  The entire 512KB are copied 
    // to address range $18:0000 to $1F:FFFF (or 38:000 to 3F:FFFF)

}

