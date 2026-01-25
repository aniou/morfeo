package pic

// a simple PIC that does nothing

import "core:fmt"
import "core:log"

import "lib:emu"

make_pic_fake    :: proc(name: string, dcb: ^emu.DeviceConfig) -> ^PIC {
    pic           := new(PIC)
    pic.name       = name
    pic.req        = dcb.req

    pic.delete     =  delete_pic_fake
    pic.read       =    read_pic_fake
    pic.write      =   write_pic_fake
    pic.trigger    = trigger_pic_fake
    pic.clean      =   clean_pic_fake

    pic.irq_clear  = false
    pic.irq_active = false

    return pic
} 

delete_pic_fake  :: proc(pic: ^PIC) {
    free(pic)
}

read_pic_fake    :: proc(pic: ^PIC, mode: MODE, addr: u32) -> (out: u32) { return }
write_pic_fake   :: proc(pic: ^PIC, mode: MODE, addr, val: u32)          {        }
trigger_pic_fake :: proc(pic: ^PIC, irq: IRQ)                            {        }
clean_pic_fake   :: proc(pic: ^PIC)                                      {        }

// eof
