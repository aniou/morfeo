
package pic

import "lib:emu"

BITS :: emu.Bitsize
PIC  :: struct {
    name:       string,
    id:         int, 

    read:       proc(^PIC, BITS, u32, u32) -> u32,
    write:      proc(^PIC, BITS, u32, u32,    u32),
    read8:      proc(^PIC, u32) -> u8,
    write8:     proc(^PIC, u32, u8),
    trigger:    proc(^PIC, IRQ),
    clean:      proc(^PIC),
    delete:     proc(^PIC),

    data:       ^[32]u8,                  // all registers, visible as memory
    irqs:       [IRQ]Irq_table,

    current:    IRQ,                     // active IRQ
    group:      IRQ_GROUP,               // active IRQ group

    vector:     uint,
    irq:        uint,
                                 // XXX - maybe states will be better?
    irq_active: bool,            // IRQ is processed?
    irq_clear:  bool,            // IRQ should be cleared?

    model: union {PIC_M68K, PIC_C256}
}

