
package timer

import "core:fmt"
import "core:log"
import "core:sys/linux"
import "core:time"
import "core:thread"
import "emulator:pic"
import "lib:emu"

// there are fifth timers in A2560X
// for compare: c256  at  14318180 Hz
// 0 clicks at CPU Clock (33000000 Hz)
// 1 clicks at CPU Clock (33000000 Hz)
// 2 clicks at CPU Clock (33000000 Hz)
// 3 should click at Vicky3 A SOF
// 4 should click at Vicky3 B SOF
//
// in my case Timers 3 and 4 will be "clicked" externally, from SDL routine 
// when and start of rendering (thus: Start Of Frame) will be called, with 
// rat corresponding to refresh rate for particular graphics mode 

TIMER_A2560X_CTRL_0   :: 0x00       // for timers 0-2
TIMER_A2560X_CTRL_1   :: 0x04       // for timers 3-4
TIMER_A2560X_T0_VAL   :: 0x08
TIMER_A2560X_T0_CMP   :: 0x0C
TIMER_A2560X_T1_VAL   :: 0x10
TIMER_A2560X_T1_CMP   :: 0x14
TIMER_A2560X_T2_VAL   :: 0x18
TIMER_A2560X_T2_CMP   :: 0x1C
TIMER_A2560X_T3_VAL   :: 0x20
TIMER_A2560X_T3_CMP   :: 0x24
TIMER_A2560X_T4_VAL   :: 0x28
TIMER_A2560X_T4_CMP   :: 0x2C

Timer_a2560x_ctrl :: bit_field u32 {
    enabled: bool | 1,
    sclr:    bool | 1,
    sload:   bool | 1,
    countup: bool | 1,      // 1 - count up, 0 - count down
    reclr:   bool | 1,      // only on timer 3 and 4?
    reload:  bool | 1,      // only on timer 3 and 4?
    none:    bool | 1,
    irq_en:  bool | 1,
}

TIMER_A2560X_THREAD :: struct {
    id:           int,            // internal, thread id
    ctrl:         Timer_a2560x_ctrl,

    charge:       u32,            // initial value when counts down
    compare:      u32,            // max value when counts up
    counter:      u32,            // internal counter
    is_equal:     bool,           // denote being equal to

    irq:          pic.IRQ,        // irq type to send when counter is equal
    pic:         ^pic.PIC,
}

TIMER_A2560X :: struct {
    using timer: ^TIMER,
    clock:       ^thread.Thread,
    shutdown:     bool,           // used by thread to graceful shutdown

    tth:      [5]TIMER_A2560X_THREAD,
}

timer_a2560x_make :: proc(name: string, pic_ctrl: ^pic.PIC, id: int) -> ^TIMER {
    timer         := new(TIMER)
    timer.name     = name
    timer.id       = id
    timer.delete   = timer_a2560x_delete
    timer.read     = timer_a2560x_read
    timer.write    = timer_a2560x_write
    timer.tick     = timer_a2560x_external_tick
    t             := TIMER_A2560X{timer = timer}
    t.shutdown     = false

    irq_table     := [5]pic.IRQ{.TIMER0, .TIMER1, .TIMER2, .TIMER3, .TIMER4}

    for i in 0..=4 {
        t.tth[i]              = TIMER_A2560X_THREAD{}
        t.tth[i].id           = i
        t.tth[i].ctrl.countup = true
        t.tth[i].irq          = irq_table[i]
        t.tth[i].pic          = pic_ctrl
        t.tth[i].ctrl.enabled = false
    }

    t.tth[3].ctrl.enabled = true
    t.tth[4].ctrl.enabled = true

    if c := thread.create_and_start_with_data(timer, timer_a2560x_worker_proc); c != nil {
        t.clock = c
    } else {
        log.errorf("%s TIMER%d cannot create clock thread", t.name, t.id)
    }

    timer.model    = t
    return timer
}

// according to behaviour from FoenixIDE
timer_a2560x_read :: proc(d: ^TIMER, mode: MODE, addr, ra: u32) -> (val: u32) {

    if mode != .mode_32be {
        emu.error_read(d.name, .BAD_MODE, mode, addr, ra, .NONE)
        return
    }

    t    := &d.model.(TIMER_A2560X)
    switch addr {
	case TIMER_A2560X_CTRL_0  : 
        val = u32(t.tth[0].ctrl)       | 
              u32(t.tth[1].ctrl) << 8  | 
              u32(t.tth[2].ctrl) << 16

	case TIMER_A2560X_CTRL_1  : 
        val  = u32(t.tth[3].ctrl)       | 
               u32(t.tth[3].ctrl) << 8

        val |= 0x0400_0000 if t.tth[0].is_equal else 0
        val |= 0x1000_0000 if t.tth[1].is_equal else 0
        val |= 0x2000_0000 if t.tth[2].is_equal else 0
        val |= 0x4000_0000 if t.tth[3].is_equal else 0
        // no compare for TIMER4?

    case TIMER_A2560X_T0_VAL  : val = t.tth[0].counter
    case TIMER_A2560X_T0_CMP  : val = 0
    case TIMER_A2560X_T1_VAL  : val = t.tth[1].counter
    case TIMER_A2560X_T1_CMP  : val = 0
    case TIMER_A2560X_T2_VAL  : val = t.tth[2].counter
    case TIMER_A2560X_T2_CMP  : val = 0
    case TIMER_A2560X_T3_VAL  : val = t.tth[3].counter
    case TIMER_A2560X_T3_CMP  : val = 0
    case TIMER_A2560X_T4_VAL  : val = t.tth[4].counter
    case TIMER_A2560X_T4_CMP  : val = 0
    }
    //log.debugf("TIMER: returned %08x %08x %08x", addr, busaddr, val)
    return
}

timer_a2560x_write :: proc(d: ^TIMER, mode: MODE, addr, ra, val: u32) {

    if mode != .mode_32be {
        emu.error_read(d.name, .BAD_MODE, mode, addr, ra, .NONE)
        return
    }

    t    := &d.model.(TIMER_A2560X)
    switch addr {
	case TIMER_A2560X_CTRL_0  : 
        //log.debugf("WRITE TIMER CTRL_0 %08x", val)
        t.tth[0].ctrl = Timer_a2560x_ctrl((val      ) & 0x8F)
        t.tth[1].ctrl = Timer_a2560x_ctrl((val >>  8) & 0x8F)
        t.tth[2].ctrl = Timer_a2560x_ctrl((val >> 16) & 0x8F)

        for i in 0 ..= 2 {
            switch {
            case t.tth[i].ctrl.sclr : t.tth[i].counter = 0
            case t.tth[i].ctrl.sload: t.tth[i].counter = t.tth[i].charge
            }
        }

	case TIMER_A2560X_CTRL_1  : 
        //log.debugf("WRITE TIMER CTRL_1 %08x", val)
        t.tth[3].ctrl = Timer_a2560x_ctrl( val      )
        t.tth[4].ctrl = Timer_a2560x_ctrl( val >>  8)

        for i in 3 ..= 4 {
            switch {
            case t.tth[i].ctrl.sclr : t.tth[i].counter = 0
            case t.tth[i].ctrl.sload: t.tth[i].counter = t.tth[i].charge
            }
        }
    case TIMER_A2560X_T0_VAL  : t.tth[0].charge  = val / 10     // because emulator is too slow
    case TIMER_A2560X_T0_CMP  : t.tth[0].compare = val / 10
    case TIMER_A2560X_T1_VAL  : t.tth[1].charge  = val / 10
    case TIMER_A2560X_T1_CMP  : t.tth[1].compare = val / 10
    case TIMER_A2560X_T2_VAL  : t.tth[2].charge  = val / 10
    case TIMER_A2560X_T2_CMP  : t.tth[2].compare = val / 10
    case TIMER_A2560X_T3_VAL  : t.tth[3].charge  = val 
    case TIMER_A2560X_T3_CMP  : t.tth[3].compare = val
    case TIMER_A2560X_T4_VAL  : t.tth[4].charge  = val
    case TIMER_A2560X_T4_CMP  : t.tth[4].compare = val
    }
}

timer_a2560x_delete :: proc(d: ^TIMER) {
    t    := &d.model.(TIMER_A2560X)
    // TIMER3 and 4 in A2560X doesn't have a clock thread
    for i in 0..=2 {
        t.shutdown = true
        thread.join(t.clock)
        //free(t.clock)
    }
    free(d)
}

// internal tick, should be used for TIMER3 or TIMER4
timer_a2560x_external_tick :: proc(d: ^TIMER, id: int = 0) {
    t    := &d.model.(TIMER_A2560X)
    if id == 3 || id == 4 {
        timer_a2560x_internal_tick(&t.tth[id])
    } else {
        log.errorf("%s TIMER%d should not be externally ticked", t.name, id)
    }
}

// internal tick
timer_a2560x_internal_tick :: proc(t: ^TIMER_A2560X_THREAD) {
    if !t.ctrl.enabled {
        return
    }

    if t.counter > 330000 do log.debugf("TIMER%d internal tick, count %d compare %d", t.id, t.counter, t.compare)

    t.is_equal = false
    if t.ctrl.countup {
        t.counter += 1
        if t.counter == t.compare {
            if t.ctrl.reclr || t.id == 0 {   // bad workaround for too slow emulator
                t.counter     = 0
            } else {
                t.ctrl.enabled = false
            }
            t.is_equal = true
            if t.ctrl.irq_en do t.pic->trigger(t.irq)
            //log.debugf("TIMER%d hit countup irq %v ", t.id, t.irq)
        }

    } else {
        t.counter -= 1
        if t.counter == t.compare {
            if t.ctrl.reload || t.id == 0 {
                t.counter     = t.charge
            } else {
                t.ctrl.enabled = false
            }
            t.is_equal = true
            if t.ctrl.irq_en do t.pic->trigger(t.irq)
            //log.debugf("TIMER%d hit countdown irq %v ", t.id, t.irq)
        }
    }

}

timer_a2560x_worker_proc :: proc(p: rawptr) {
        logger_options := log.Options{.Level};
        context.logger  = log.create_console_logger(opt = logger_options)

        d := transmute(^TIMER)p
        t := &d.model.(TIMER_A2560X)
        nextime := time.now()._nsec + 400
        for !t.shutdown {
            if time.now()._nsec > nextime {
                nextime = time.now()._nsec + 400
                if t.tth[0].ctrl.enabled do timer_a2560x_internal_tick(&t.tth[0])
                if t.tth[1].ctrl.enabled do timer_a2560x_internal_tick(&t.tth[1])
                if t.tth[2].ctrl.enabled do timer_a2560x_internal_tick(&t.tth[2])
            }
            //log.debugf("internal thread TIMER%d tick", t.id)
        }
        log.debugf("internal thread TIMER%d shutdown clock thread", t.id)
        log.destroy_console_logger(context.logger)
}

// eof
