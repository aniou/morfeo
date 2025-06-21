
package rtc

import "core:fmt"
import "core:log"
import "core:time"
import "core:thread"
import "emulator:pic"
import "lib:emu"

BITS :: emu.Bitsize

/*

 bq4802Y: 5-V   Operation
bq4802LY: 3.3-V Operation

 - following implementation is a very loose variation about 
 interfaces, nor voltage or reaction times, so...

*/

// MODEL == MODEL_FOENIX_A2560K || MODEL == MODEL_FOENIX_GENX || MODEL == MODEL_FOENIX_A2560X

RTC_SEC         :: 0x00
RTC_ALRM_SEC    :: 0x01
RTC_MIN         :: 0x02
RTC_ALRM_MIN    :: 0x03
RTC_HOUR        :: 0x04
RTC_ALRM_HOUR   :: 0x05
RTC_DAY         :: 0x06
RTC_ALRM_DAY    :: 0x07
RTC_DAY_OF_WEEK :: 0x08
RTC_MONTH       :: 0x09
RTC_YEAR        :: 0x0A
RTC_RATES       :: 0x0B
RTC_ENABLES     :: 0x0C
RTC_FLAGS       :: 0x0D
RTC_CTRL        :: 0x0E
RTC_CENTURY     :: 0x0F

/*
lookup :: #force_inline proc(kind: Kind) -> string {
  @static table := TABLE;
  return table[kind];
}
*/

REGISTERS :: [?]string {
    "RTC_SEC",
    "RTC_ALRM_SEC",
    "RTC_MIN",
    "RTC_ALRM_MIN",
    "RTC_HOUR",
    "RTC_ALRM_HOUR",
    "RTC_DAY",
    "RTC_ALRM_DAY",
    "RTC_DAY_OF_WEEK",
    "RTC_MONTH",
    "RTC_YEAR",
    "RTC_RATES",
    "RTC_ENABLES",
    "RTC_FLAGS",
    "RTC_CTRL",
    "RTC_CENTURY",
}

RTC :: struct {
    name:   string,
    id:     u8,
    pic:    ^pic.PIC,

    read:     proc(^RTC, BITS, u32, u32) -> u32,
    write:    proc(^RTC, BITS, u32, u32,    u32),
    //read8:    proc(^RTC, u32) -> u8,
    //write8:   proc(^RTC, u32, u8),
    delete:   proc(^RTC),

    clock:    ^thread.Thread,
    shutdown: bool,
}

bq4802_make :: proc(name: string, pic: ^pic.PIC) -> ^RTC {
    r         := new(RTC)
    r.name     = name
    r.pic      = pic
    //r.read8    = bq4802_read8
    //r.write8   = bq4802_write8
    r.delete   = bq4802_delete
    r.read     = bq4802_read
    r.write    = bq4802_write
    r.shutdown = false          // used to stop threads

    //if t := thread.create_and_start_with_data(r, worker_proc, context); t != nil {
    if t := thread.create_and_start_with_data(r, worker_proc); t != nil {
        r.clock = t
    } else {
        log.errorf("%s bq4802 cannot create clock thread", r.name)
    }


    return r
}

bq4802_read :: proc(r: ^RTC, mode: BITS, base, busaddr: u32) -> (val: u32) {
    addr := busaddr - base
    log.warnf("%s bq4802 read%d     from %2x  %-15s not implemented", r.name, mode, busaddr, addr_name(addr))
    return 0
}

bq4802_write :: proc(r: ^RTC, mode: BITS, base, busaddr, val: u32) {
    addr := busaddr - base
    log.warnf("%s bq4802 write%d      to  %-15s not implemented", r.name, mode, busaddr, addr_name(addr))
    return
}

// XXX - not used?
/*
bq4802_read8 :: proc(r: ^RTC, addr: u32) -> (val: u8) {
    log.warnf("%s bq4802 read     from %2x  %-15s not implemented", r.name, addr, addr_name(addr))
    return 0
}

bq4802_write8 :: proc(r: ^RTC, addr: u32, val: u8) {
    log.warnf("%s bq4802 write %02x to   %2x  %-15s not implemented", r.name, val, addr, addr_name(addr))
    return
}
*/

bq4802_delete :: proc(r: ^RTC) {
    r.shutdown = true
    thread.join(r.clock)
    free(r.clock)
    free(r)
}

worker_proc :: proc(p: rawptr) {
        logger_options := log.Options{.Level};
        context.logger  = log.create_console_logger(opt = logger_options)

        r := transmute(^RTC)p
        for !r.shutdown {
            //log.debugf("%s bq4802 tick from thread", r.name)
            time.sleep(100 * time.Millisecond)
        }
        log.debugf("%s bq4802 shutdown clock thread", r.name)
        log.destroy_console_logger(context.logger)
}

// XXX - not used?
bq4802_clock :: proc(r: ^RTC) {
    
    if t := thread.create_and_start_with_data(r, worker_proc, context); t != nil {
        r.clock = t
    } else {
        log.errorf("%s bq4802 cannot create clock thread", r.name)
    }

}

@private
addr_name :: #force_inline proc(i: u32) -> string {
  @static table := REGISTERS
  return table[i]
}


