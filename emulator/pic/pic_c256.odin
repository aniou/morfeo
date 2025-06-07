
package pic

PIC_C256 :: struct {
    using pic: ^PIC
}


pic_c256_make :: proc(name: string) -> ^PIC {
    pic          := new(PIC)
    pic.name      = name
    pic.id        = 0
    pic.data      = new([32]u8)
    pic.current   = .NONE
    pic.group     = .GRP_NONE
    //pic.irqs      = M68K_IRQ
    pic.irq_clear = false
    pic.irq_active= false

    /*
    pic.trigger   = m68040_trigger
    pic.clean     = m68040_clean
    pic.read8     = pic_m68k_read8
    pic.write8    = pic_m68k_write8
    pic.read      = pic_m68k_read
    pic.write     = pic_m68k_write
    pic.delete    = pic_m68k_delete
    */
    p            := PIC_C256{pic = pic}
    pic.model     = p
    return pic
} 
