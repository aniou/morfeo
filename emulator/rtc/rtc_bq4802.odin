
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
  This implementations does not support:

  - daylight saving time functionality - usefulness of that is dubious
    in particular, for OS-es (if You need a time-zone aware OS then You
    should set internal clock to UTC and apply timezone correction at
    OS level) and in general - in various countires there are periodically 
    raised requests for abandoning that misfeature and some goverments 
    already did that

  - watchdog time - it is not usable on current hardware, but feel free
    to ask me for support if use-case will appear


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
    periodic:           int | 4,
    watchdog:           int | 3,
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


BQ4802_Value :: struct {    // universal value to simplify things
    val    :  u32,
    enabled: bool,           // used by alarms
    dirty  : bool,           // used by write clocks
}

BQ4802_Clock :: struct {
    second     : BQ4802_Value,
    minute     : BQ4802_Value,
    hour       : BQ4802_Value,
    day        : BQ4802_Value,
    dow        : BQ4802_Value,
    month      : BQ4802_Value,
    year       : BQ4802_Value,
    century    : BQ4802_Value,
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

    own        : BQ4802_Clock,       // internal clock, update once per second
    pub        : BQ4802_Clock,       // public clock, update if control.uti == 0
    alarm      : BQ4802_Clock,       // alarm clock

    days       : [12]u32,

    clock:           ^thread.Thread,
    clock_periodic:  ^thread.Thread,

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

    r.own.second.val      = u32(ldt.time.second)
    r.own.minute.val      = u32(ldt.time.minute)
    r.own.hour.val        = u32(ldt.time.hour)
    r.own.day.val         = u32(ldt.date.day)
    r.own.dow.val         = u32(time.weekday(ts))
    r.own.month.val       = u32(ldt.date.month)
    r.own.year.val        = u32(ldt.date.year % 100)
    r.own.century.val     = u32(ldt.date.year / 100)

    r.own.second.enabled  = true
    r.own.minute.enabled  = true
    r.own.hour.enabled    = true
    r.own.day.enabled     = true
    r.own.dow.enabled     = true
    r.own.month.enabled   = true
    r.own.year.enabled    = true
    r.own.century.enabled = true

    r.pub                 = r.own
    r.days                = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    r.control.mode_24h    = true

    update_leap_year(r)

    if t := thread.create_and_start_with_data(r, bq4802_worker_clock); t != nil {
        r.clock = t
    } else {
        log.errorf("%s bq4802 cannot create clock thread", r.name)
    }

    if t := thread.create_and_start_with_data(r, bq4802_worker_periodic); t != nil {
        r.clock_periodic = t
    } else {
        log.errorf("%s bq4802 cannot create periodic clock thread", r.name)
    }

    return r
}

bq4802_read :: proc(r: ^RTC, mode: BITS, base, busaddr: u32) -> (val: u32) {
    addr := busaddr - base

    if mode != .bits_8 {
        emu.unsupported_read_size(#procedure, r.name, r.id, mode, busaddr)
    }

    switch Register_bq4802(addr) {
    case .RTC_SEC        : val = time_to_bcd(r.pub.second)
    case .RTC_ALRM_SEC   : val = time_to_bcd(r.alarm.second)
    case .RTC_MIN        : val = time_to_bcd(r.pub.minute)
    case .RTC_ALRM_MIN   : val = time_to_bcd(r.alarm.minute)
    case .RTC_HOUR       : val = hour_to_bcd(r.pub.hour,    r.control.mode_24h)
    case .RTC_ALRM_HOUR  : val = hour_to_bcd(r.alarm.hour,  r.control.mode_24h)
    case .RTC_DAY        : val = time_to_bcd(r.pub.day)
    case .RTC_ALRM_DAY   : val = time_to_bcd(r.alarm.day)
    case .RTC_DAY_OF_WEEK: val = time_to_bcd(r.pub.dow)
    case .RTC_MONTH      : val = time_to_bcd(r.pub.month)
    case .RTC_YEAR       : val = time_to_bcd(r.pub.year)
    case .RTC_RATES      : val =         u32(r.rate)
    case .RTC_ENABLES    : val =         u32(r.enable)
    case .RTC_FLAGS      : val =         u32(r.flag)
    case .RTC_CTRL       : val =         u32(r.control)
    case .RTC_CENTURY    : val = time_to_bcd(r.pub.century)
    }
    //log.warnf("%s bq4802 read%d     from %x  %-15s not implemented", r.name, mode, busaddr, addr_name(addr))
    return
}

bq4802_write :: proc(r: ^RTC, mode: BITS, base, busaddr, val: u32) {
    addr := busaddr - base

    if mode != .bits_8 {
        emu.unsupported_write_size(#procedure, r.name, r.id, mode, busaddr, val)
    } 

    //log.debugf("%s bq4802 write%d %02x   to %x  %-15s", r.name, mode, val, busaddr, addr_name(addr))
    switch Register_bq4802(addr) {
    case .RTC_SEC        : r.pub.second   = time_from_bcd(val)
    case .RTC_ALRM_SEC   : r.alarm.second = time_from_bcd(val)
    case .RTC_MIN        : r.pub.minute   = time_from_bcd(val)
    case .RTC_ALRM_MIN   : r.alarm.minute = time_from_bcd(val)
    case .RTC_HOUR       : r.pub.hour     = hour_from_bcd(val,  r.control.mode_24h)
    case .RTC_ALRM_HOUR  : r.alarm.hour   = hour_from_bcd(val,  r.control.mode_24h)
    case .RTC_DAY        : r.pub.day      = time_from_bcd(val)
    case .RTC_ALRM_DAY   : r.alarm.day    = time_from_bcd(val)
    case .RTC_DAY_OF_WEEK: log.warnf("%s bq4802 write%d %02x   to %x  %-15s does nothing", r.name, mode, val, busaddr, addr_name(addr))
    case .RTC_MONTH      : r.pub.month    = time_from_bcd(val)
    case .RTC_YEAR       : r.pub.year     = time_from_bcd(val)
    case .RTC_RATES      : r.rate         = BQ4802_Rates(val)
    case .RTC_ENABLES    : r.enable       = BQ4802_Enables(val)
    case .RTC_FLAGS      : r.flag         = BQ4802_Flags(val);   r.flag = BQ4802_Flags(0)   // clear on read
    case .RTC_CTRL       : r.control      = BQ4802_Control(val)
    case .RTC_CENTURY    : r.pub.century  = time_from_bcd(val)
    }

    // if uti is not 0 then update
    if r.control.uti == true {
        return
    }

    if r.pub.second.dirty  { r.own.second.val  = r.pub.second.val;   r.pub.second.dirty  = false }
    if r.pub.minute.dirty  { r.own.minute.val  = r.pub.minute.val;   r.pub.minute.dirty  = false }
    if r.pub.hour.dirty    { r.own.hour.val    = r.pub.hour.val;     r.pub.hour.dirty    = false }
    if r.pub.day.dirty     { r.own.day.val     = r.pub.day.val;      r.pub.day.dirty     = false }
    if r.pub.month.dirty   { r.own.month.val   = r.pub.month.val;    r.pub.month.dirty   = false }
    if r.pub.year.dirty    { r.own.year.val    = r.pub.year.val;     r.pub.year.dirty    = false }
    if r.pub.century.dirty { r.own.century.val = r.pub.century.val;  r.pub.century.dirty = false }

    //log.warnf("%s bq4802 write%d %02x   to %x  %-15s not implemented", r.name, mode, val, busaddr, addr_name(addr))
    return
}

bq4802_delete :: proc(r: ^RTC) {
    r.shutdown = true
    thread.join(r.clock)
    thread.join(r.clock_periodic)
    free(r.clock)
    free(r)
}

// worker resposible for clock/calendar ticking, once per second
bq4802_worker_clock :: proc(p: rawptr) {
       logger_options := log.Options{.Level};
       context.logger  = log.create_console_logger(opt = logger_options)
       update_leap : bool

       r := transmute(^RTC)p
       for !r.shutdown {
            update_leap = false
            clock: {
                r.own.second.val      += 1
                if r.own.second.val    < 60 do break clock
                r.own.second.val       = 0

                r.own.minute.val      += 1
                if r.own.minute.val    < 60 do break clock
                r.own.minute.val       = 0

                r.own.hour.val        += 1
                if r.own.hour.val      < 24 do break clock
                r.own.hour.val         = 0

                r.own.dow.val += 1
                r.own.dow.val &= 7
                r.own.day.val         += 1
                if r.own.day.val      <= r.days[r.own.month.val - 1] do break clock
                r.own.day.val          = 1

                r.own.month.val       += 1
                if r.own.month.val     < 13 do break clock
                r.own.month.val        = 1
                
                update_leap            = true
                r.own.year.val        += 1
                if r.own.year.val     <= 99 do break clock
                r.own.year.val         = 0

                r.own.century.val     += 1
                if r.own.century.val  <= 99 do break clock
                r.own.century.val      = 0
            }

            if update_leap    do update_leap_year(r)
            if !r.control.uti do r.pub = r.own

            // spec (page 15): if all alarms are "disabled" then alarm is called once per second
            alarm: {
                if r.alarm.second.enabled && r.alarm.second.val != r.own.second.val do break alarm
                if r.alarm.minute.enabled && r.alarm.minute.val != r.own.minute.val do break alarm
                if r.alarm.hour.enabled   && r.alarm.hour.val   != r.own.hour.val   do break alarm
                if r.alarm.day.enabled    && r.alarm.day.val    != r.own.day.val    do break alarm

                if r.enable.alarm_irq && !r.flag.alarm_irq {
                    r.pic->trigger(.RTC)
                }
                r.flag.alarm_irq = true

                //log.debugf("%s bq4802 alarm %2d %2d:%2d:%2d", 
                //            r.name, r.own.day.val, r.own.hour.val, r.own.minute.val, r.own.second.val)
            }

            /*
            log.debugf("%s bq4802 %2d%2d-%2d-%2d (%d) %d:%d:%d (uti: %v)", r.name, 
                        r.own.century.val, r.own.year.val, r.own.month.val, r.own.day.val, r.own.dow.val,
                        r.own.hour.val, r.own.minute.val, r.own.second.val, r.control.uti)
            */

            time.sleep(time.Second)
        }
                  

        log.debugf("%s bq4802 shutdown clock thread", r.name)
        log.destroy_console_logger(context.logger)
}

// worker resposible for periodinc interrupts
bq4802_worker_periodic :: proc(p: rawptr) {
    logger_options := log.Options{.Level};
    context.logger  = log.create_console_logger(opt = logger_options)

    delay := [16]time.Duration {      // in Nanoseconds
       1000000000,             // NONE == 1 second, w/o irq
            30517,             //   30.5175 μs
            61035,             //   61.035  μs
           122070,             //  122.070  μs
           244141,             //  244.141  μs
           488281,             //  488.281  μs
           976562,             //  976.5625 μs
          1953150,             //   1.95315 ms
          3906250,             //   3.90625 ms
          7812500,             //    7.8125 ms
         15625000,             //    15.625 ms
         31250000,             //     31.25 ms
         62500000,             //      62.5 ms
        125000000,             //       125 ms
        250000000,             //       250 ms
        500000000,             //       500 ms
    }

    r := transmute(^RTC)p
    for !r.shutdown {
        time.sleep(delay[r.rate.periodic])
        if r.rate.periodic == 0 do continue

        if r.enable.periodic_irq && !r.flag.periodic_irq {
            r.pic->trigger(.RTC)
        }
        r.flag.periodic_irq = true
    }

    log.debugf("%s bq4802 shutdown periodic clock thread", r.name)
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
    if leap_year(r.own.year.val) {
        r.days[1] = 29
    } else {
        r.days[1] = 28
    }
}

@private
hour_to_bcd :: proc(hour: BQ4802_Value, mode_24h: bool) -> (val: u32) {
    if mode_24h {
        val = time_to_bcd(hour)
    } else {
        hour := hour
        switch hour.val {
        case 0       : hour.val += 12; val = time_to_bcd(hour)  ; val |= 0x80
        case 1 ..= 12:                 val = time_to_bcd(hour)
        case         : hour.val -= 12; val = time_to_bcd(hour)  ; val |= 0x80
        }
    }

    return
}

@private
time_to_bcd :: proc(arg: BQ4802_Value) -> (val: u32) {
    tens :=  arg.val     / 10
    ones :=  arg.val     % 10
    val   = (tens <<  4) | ones
    val  |= 0xC0 if !arg.enabled else 0
    return
}

@private
time_from_bcd :: proc(arg: u32) -> (val: BQ4802_Value) {
    val.dirty    = true
    val.enabled  =  arg  & 0xc0  != 0xc0
    tens        := (arg  & 0xf0) >> 4
    ones        :=  arg  & 0x0f
    val.val      = (tens *   10)  + ones
    return
}

@private
// special case for hours
hour_from_bcd :: proc(arg: u32, mode_24h: bool) -> (val: BQ4802_Value) {
    pm    :=  arg  & 0x80  == 0x80
    val    =  time_from_bcd(arg)

    if !mode_24h && pm do val.val = arg + 12
    if val.val == 24   do val.val = 0

    return
}

/* --------- some final notes 

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


