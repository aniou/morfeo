
package pic

import "lib:emu"

MODE :: emu.OpMode

PIC  :: struct {
    name:       string,
    delete:     proc(^PIC),
    read:       proc(^PIC, MODE, u32, u32) -> u32,
    write:      proc(^PIC, MODE, u32, u32,    u32),

    trigger:    proc(^PIC, IRQ),
    clean:      proc(^PIC),

    data:       ^[32]u8,                  // all registers, visible as memory
    irqs:       [IRQ]Irq_table,

    current:    IRQ,                     // active IRQ
    group:      IRQ_GROUP,               // active IRQ group

    vector:     uint,
    irq:        uint,
                                 // XXX - maybe states will be better?
    irq_active: bool,            // IRQ is processed?
    irq_clear:  bool,            // IRQ should be cleared?

    model: union {PIC_M68K, PIC_C256, PIC_F256}
}

