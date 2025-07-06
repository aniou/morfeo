
package timer

import "core:fmt"
import "core:log"
import "core:time"
import "core:thread"
import "emulator:pic"
import "lib:emu"

BITS :: emu.Bitsize

// there are three timers i C256
// 0 clicks at 14318180Hz
// 1 clicks at 14318180Hz too
// 2 should click at Vicky2 SOF but in Foenix IDE it also has 14MHz timer
//
// in my case Timer2 will be "clicked" externally, from SDL routine when
// and start of rendering (thus: Start Of Frame) will be called, with rate
// corresponding to refresh rate for particular graphics mode 

TIMER_CTRL_REG :: 0x00
TIMER_CHARGE_L :: 0x01
TIMER_CHARGE_M :: 0x02
TIMER_CHARGE_H :: 0x03
TIMER_CMP_REG  :: 0x04
TIMER_CMP_L    :: 0x05
TIMER_CMP_M    :: 0x06
TIMER_CMP_H    :: 0x07

Timer_ctrl :: bit_field u32 {
    enabled: bool | 1,
    sclr:    bool | 1,
    sload:   bool | 1,
    countup: bool | 1,           // 1 - count up, 2 - count down
}

Timer_cmp :: bit_field u32 {
    reclr:   bool | 1,           // set to 0 (cycle) when count up and == comparec
    reload:  bool | 1,           // reload from chargec when counting down
}

TIMER :: struct {
    name:       string,
    id:         u8,
    irq:         pic.IRQ,             // irq type to send when counter is equal
    pic:        ^pic.PIC,

    read:       proc(^TIMER, BITS, u32, u32) -> u32,
    write:      proc(^TIMER, BITS, u32, u32,    u32),
    delete:     proc(^TIMER),
    tick:       proc(^TIMER),

    clock:        ^thread.Thread,
    ctrl:         Timer_ctrl,
    cmp:          Timer_cmp,
    sleep:        time.Duration,  // how long to sleep between calls

    charge:       u32,            // initial value when counts down
    compare:      u32,            // max value when counts up

    counter:      u32,            // internal counter
    shutdown:     bool,           // used by thread to graceful shutdown
}

timer_c256_make :: proc(name: string, pic: ^pic.PIC, id: u8) -> ^TIMER {
    t             := new(TIMER)
    t.name         = name
    t.id           = id
    t.pic          = pic
    t.delete       = timer_c256_delete
    t.read         = timer_c256_read
    t.write        = timer_c256_write
    t.tick         = timer_c256_tick
    t.shutdown     = false          // used to stop threads
    t.ctrl.enabled = false
    t.sleep        = 69 * time.Nanosecond

    switch id {
    case 0: t.irq = .TIMER0
    case 1: t.irq = .TIMER1
    case 2: t.irq = .TIMER2
    case  : log.errorf("%s cannot assign IRQ for timer id %d", #procedure, id)
    }

    // TIMER2 is ticked by start of frame (in fact - from SDL code)
    if id != 2 {
        if c := thread.create_and_start_with_data(t, worker_proc); t != nil {
            t.clock = c
        } else {
            log.errorf("%s TIMER cannot create clock thread", t.name)
        }
    }

    return t
}

// according to behaviour from FoenixIDE
timer_c256_read :: proc(t: ^TIMER, mode: BITS, base, busaddr: u32) -> (val: u32) {
    addr := busaddr - base
    switch addr {
    case TIMER_CTRL_REG: val = 1 if t.counter == t.compare else 0
    case TIMER_CHARGE_L: val = emu.get_byte1(t.counter)     // not charge
    case TIMER_CHARGE_M: val = emu.get_byte2(t.counter)     // not charge
    case TIMER_CHARGE_H: val = emu.get_byte3(t.counter)     // not charge
    case TIMER_CMP_REG : val = u32(t.cmp)
    case TIMER_CMP_L   : val = emu.get_byte1(t.compare)
    case TIMER_CMP_M   : val = emu.get_byte1(t.compare)
    case TIMER_CMP_H   : val = emu.get_byte1(t.compare)
    }
    return
}

timer_c256_write :: proc(t: ^TIMER, mode: BITS, base, busaddr, val: u32) {
    addr := busaddr - base
    switch addr {
    case TIMER_CTRL_REG: 
        t.ctrl       = cast(Timer_ctrl) val
        switch {
        case t.ctrl.sclr : t.counter = 0
        case t.ctrl.sload: t.counter = t.charge
        }
        log.debugf("%s enabled %v sclr %v sload %v countup %v",
                    t.name, t.ctrl.enabled, t.ctrl.sclr, t.ctrl.sload, t.ctrl.countup)

    case TIMER_CHARGE_L: t.charge  = emu.assign_byte1(t.charge,  val)
    case TIMER_CHARGE_M: t.charge  = emu.assign_byte2(t.charge,  val)
    case TIMER_CHARGE_H: t.charge  = emu.assign_byte3(t.charge,  val)
    case TIMER_CMP_REG : t.cmp     = cast(Timer_cmp)         val
    case TIMER_CMP_L   : t.compare = emu.assign_byte1(t.compare, val)
    case TIMER_CMP_M   : t.compare = emu.assign_byte2(t.compare, val)
    case TIMER_CMP_H   : t.compare = emu.assign_byte3(t.compare, val)
    }
}

timer_c256_delete :: proc(t: ^TIMER) {
    t.shutdown = true

    // timer2 in c256 doesn't have a clock thread
    if t.id != 2 {
        thread.join(t.clock)
        free(t.clock)
    }

    free(t)
}

// may be called internally or externally
timer_c256_tick :: proc(t: ^TIMER) {
    if !t.ctrl.enabled {
        return
    }
    //log.debugf("%s tick", t.name)

    if t.ctrl.countup {
        t.counter += 1
        t.counter &= 0x00FF_FFFF
        if t.counter == t.compare {
            if t.cmp.reclr {
                t.counter     = 0
            } else {
                //t.ctrl.enabled = false
            }
            t.pic->trigger(t.irq)
            //log.debugf("%s hit countup", t.name)
        }

    } else {
        t.counter -= 1
        t.counter &= 0x00FF_FFFF
        if t.counter == t.compare {
            if t.cmp.reload {
                t.counter     = t.charge
            } else {
                //t.ctrl.enabled = false
            }
            t.pic->trigger(t.irq)
            //log.debugf("%s hit countdown", t.name)
        }
    }

}

worker_proc :: proc(p: rawptr) {
        logger_options := log.Options{.Level};
        context.logger  = log.create_console_logger(opt = logger_options)

        t := transmute(^TIMER)p
        for !t.shutdown {
            time.sleep(t.sleep)
            timer_c256_tick(t)
        }
        log.debugf("%s TIMER shutdown clock thread", t.name)
        log.destroy_console_logger(context.logger)
}

// eof
