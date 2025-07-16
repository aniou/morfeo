
package rtc


import "core:fmt"
import "core:log"
import "core:sync"
import "core:time"
import "core:time/datetime"
import "core:time/timezone"
import "core:thread"

import "lib:emu"

import "emulator:pic"


BITS :: emu.Bitsize

/*

bq4802 Y: 5-V   Operation
bq4802LY: 3.3-V Operation

 - following implementation is a very loose variation about 
 interfaces, nor voltage or reaction times, so...

  Microsecond :: 1000 * Nanosecond
                 1 μs = 10-6 s = 1/1 000 000 s

*/

Register_bq4802 :: enum u32 {
    RTC_SEC          = 0x00,
    RTC_ALRM_SEC     = 0x01,
    RTC_MIN          = 0x02,
    RTC_ALRM_MIN     = 0x03,
    RTC_HOUR         = 0x04,
    RTC_ALRM_HOUR    = 0x05,
    RTC_DAY          = 0x06,
    RTC_ALRM_DAY     = 0x07,
    RTC_DAY_OF_WEEK  = 0x08,
    RTC_MONTH        = 0x09,
    RTC_YEAR         = 0x0A,
    RTC_RATES        = 0x0B,
    RTC_ENABLES      = 0x0C,
    RTC_FLAGS        = 0x0D,
    RTC_CTRL         = 0x0E,
    RTC_CENTURY      = 0x0F,
}

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

BQ4802_Rates :: bit_field u32 {
    irq_rate:           int | 4,
    watchdog_rate:      int | 3,
}

BQ4802_Flags :: bit_field u32 {
    battery_valid:     bool | 1,
    power_fail:        bool | 1,
    periodic_irq:      bool | 1,
    alarm_irq:         bool | 1,
}

BQ4802_Enables :: bit_field u32 {
    alarm_in_battery : bool | 1,
    power_fail_irq:    bool | 1,
    periodic_irq:      bool | 1,
    alarm_irq:         bool | 1,
}

BQ4802_Control :: bit_field u32 {
    dse:               bool | 1,    // daylight savings enable  
    mode_24h:          bool | 1,
    enable_on_battery: bool | 1,
    uti:               bool | 1,    // update transfer inhibit (don't update public from internal counters)
}

BQ4802_Clock :: struct {
    second     : u32,
    minute     : u32,
    hour       : u32,
    day        : u32,
    day_of_week: u32,
    month      : u32,
    year       : u32,
}


RTC :: struct {
    name:   string,
    id:     int,
    pic:    ^pic.PIC,

    read:     proc(^RTC, BITS, u32, u32) -> u32,
    write:    proc(^RTC, BITS, u32, u32,    u32),
    delete:   proc(^RTC),


    rate       : BQ4802_Rates,
    flag       : BQ4802_Flags,
    enable     : BQ4802_Enables,
    control    : BQ4802_Control,

    own        : BQ4802_Clock,    // internal clock, update once per second
    pub        : BQ4802_Clock,    // public clock, update if control.uti == 0
    alarm      : BQ4802_Clock,    // alarm clock

    days       : [12]u32,

    clock:    ^thread.Thread,
	//mutex:    sync.Mutex,       // ok, there is a small window to desync r/w of date, but...
    shutdown: bool,

}

bq4802_make :: proc(name: string, pic: ^pic.PIC) -> ^RTC {
    r         := new(RTC)
    r.name     = name
    r.pic      = pic
    r.delete   = bq4802_delete
    r.read     = bq4802_read
    r.write    = bq4802_write
    r.shutdown = false          // used to stop threads

    ts     := time.now()
    dt,  _ := time.time_to_datetime(ts)
    tz,  _ := timezone.region_load("local")
    ldt, _ := timezone.datetime_to_tz(dt, tz)
    ts,  _  = time.datetime_to_time(ldt)        // time corrected for weekday below

    r.own.second      = u32(ldt.time.second)
    r.own.minute      = u32(ldt.time.minute)
    r.own.hour        = u32(ldt.time.hour)
    r.own.day         = u32(ldt.date.day)
    r.own.day_of_week = u32(time.weekday(ts))
    r.own.month       = u32(ldt.date.month)
    r.own.year        = u32(ldt.date.year)

    r.pub             = r.own
    r.days            = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}

    update_leap_year(r)

    if t := thread.create_and_start_with_data(r, bq4802_worker_clock); t != nil {
        r.clock = t
    } else {
        log.errorf("%s bq4802 cannot create clock thread", r.name)
    }


    return r
}

bq4802_read :: proc(d: ^RTC, mode: BITS, base, busaddr: u32) -> (val: u32) {
    addr := busaddr - base

    if mode != .bits_8 {
        emu.unsupported_read_size(#procedure, d.name, d.id, mode, busaddr)
    }

    log.warnf("%s bq4802 read%d     from %x  %-15s not implemented", d.name, mode, busaddr, addr_name(addr))
    return 0
}

bq4802_write :: proc(d: ^RTC, mode: BITS, base, busaddr, val: u32) {
    addr := busaddr - base

    if mode != .bits_8 {
        emu.unsupported_write_size(#procedure, d.name, d.id, mode, busaddr, val)
    } 


    log.warnf("%s bq4802 write%d %02x   to %x  %-15s not implemented", d.name, mode, val, busaddr, addr_name(addr))
    return
}

bq4802_delete :: proc(r: ^RTC) {
    r.shutdown = true
    thread.join(r.clock)
    free(r.clock)
    free(r)
}

// worker resposible for clock/calendar ticking, once per second
bq4802_worker_clock :: proc(p: rawptr) {
       logger_options := log.Options{.Level};
       context.logger  = log.create_console_logger(opt = logger_options)

       r := transmute(^RTC)p
       for !r.shutdown {
			clock: {
                r.own.second      += 1
			    if r.own.second    < 60 do break clock
                r.own.second       = 0

                r.own.minute      += 1
			    if r.own.minute    < 60 do break clock
                r.own.minute       = 0

                r.own.hour        += 1
			    if r.own.minute    < 24 do break clock
                r.own.hour         = 0

                r.own.day_of_week += 1
                r.own.day_of_week &= 7
                r.own.day         += 1
                if r.own.day      <= r.days[r.own.month] do break clock
                r.own.day          = 1

                r.own.month       += 1
                if r.own.month     < 13 do break clock
                r.own.month        = 1
                
                r.own.year        += 1
                if r.own.year      > 9999 do r.own.year = 0
                update_leap_year(r)
			}

            if !r.control.uti {
                r.pub = r.own
            }

            // XXX: alarm check there

			log.debugf("%s bq4802 %4d-%2d-%2d (%d) %d:%d:%d (uti: %v)", 
                        r.name, 
                        r.own.year, r.own.month, r.own.day, 
                        r.own.day_of_week,
                        r.own.hour, r.own.minute, r.own.second,
                        r.control.uti
                    )


            time.sleep(time.Second)
        }
                  

        log.debugf("%s bq4802 shutdown clock thread", r.name)
        log.destroy_console_logger(context.logger)
}

@private
addr_name :: #force_inline proc(i: u32) -> string {
  @static table := REGISTERS
  return table[i]
}

@private
leap_year :: #force_inline proc(year: u32) -> bool {
    return ((year % 400 == 0 || year % 100 != 0) && (year % 4 == 0))
}

@private
update_leap_year :: proc(r: ^RTC) {
    if leap_year(r.own.year) {
        r.days[1] = 29
    } else {
        r.days[1] = 28
    }
}

/* --------- some notes 

1. Daylight savings from https://stackoverflow.com/a/22761920

   to summer: mar 01 UTC -> 02 UTC
   to winter: oct 01 UTC -> 00 UTC

    public static bool IsDst(int day, int month, int dow)
    {
        if (month < 3 || month > 10)  return false;
        if (month > 3 && month < 10)  return true;

        int previousSunday = day - dow;

        if (month == 3) return previousSunday >= 25;
        if (month == 10) return previousSunday < 25;

        return false; // this line never gonna happend
    }

*/


