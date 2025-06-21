package ps2

import "core:log"
import "emulator:pic"
import "lib:emu"

// https://wiki.osdev.org/%228042%22_PS/2_Controller


// Bit  Meaning
// 0    Output buffer status (0 = empty, 1 = full)
//       (must be set before attempting to read data from IO port 0x60)
// 1    Input buffer status (0 = empty, 1 = full)
//       (must be clear before attempting to write data to IO port 0x60 or IO port 0x64)
// 2    System Flag
//       Meant to be cleared on reset and set by firmware (via. PS/2 Controller
//       Configuration Byte) if the system passes self tests (POST)
// 3    Command/data (0 = data written to input buffer is data for PS/2 device, 
//       1 = data written to input buffer is data for PS/2 controller command)
// 4    Unknown (chipset specific)     May be "keyboard lock" (more likely unused on modern systems)
// 5    Unknown (chipset specific)    May be "receive time-out" or "second PS/2 port output buffer full"
// 6    Time-out error (0 = no error, 1 = time-out error)
// 7    Parity error (0 = no error, 1 = parity error) 

PS2_STAT_OBF    :: u8(0x01)
PS2_STAT_IBF    :: u8(0x02)
PS2_STAT_SYS    :: u8(0x04)
PS2_STAT_CMD    :: u8(0x08)
PS2_STAT_INH    :: u8(0x10)
PS2_STAT_TTO    :: u8(0x20)
PS2_STAT_RTO    :: u8(0x40)
PS2_STAT_PE     :: u8(0x80)

PS2_RESP_ACK    :: u8(0xFA)

KBD_DATA        :: 0x00 // $AF1803 (FMX: $AF1060) for reading and writing
KBD_COMMAND     :: 0x04 // $AF1807 (FMX: $AF1064) for writing
KBD_STATUS      :: 0x04 // $AF1807 (FMX: $AF1064) for reading

BITS :: emu.Bitsize
PS2  :: struct {
    read:     proc(^PS2, BITS, u32, u32) -> u32,
    write:    proc(^PS2, BITS, u32, u32,    u32),
    read8:    proc(^PS2, u32) -> u8,
    write8:   proc(^PS2, u32, u8),
    send_key: proc(^PS2, u8),
    delete:   proc(^PS2),

    pic:            ^pic.PIC,

    name:           string,
    id:             int,

    data:           u8,     // data (usually keycode)
    status:         u8,     // controller status
    CCB:            u8,     // controller configuration byte
    ccb_write_mode: bool,   // denotes that next write should go to CCB
    fmx:            bool,   // if it is FMX one, then change addressess

    first_enabled:  bool,
    second_enabled: bool,

    debug:          bool,   // temporary
}

ps2_make :: proc(name: string, pic: ^pic.PIC, type: emu.Type) -> ^PS2 {
    s         := new(PS2)
    s.pic      = pic
    s.read     = ps2_read
    s.write    = ps2_write
    s.delete   = ps2_delete
    s.read8    = ps2_read8
    s.write8   = ps2_write8
    s.send_key = ps2_send_key
    s.status   = 0
    s.debug    = true
    s.CCB      = 0
    s.name     = name
    s.fmx      = type == .C256FMX  // only FMX has different port
    
    return s
}

ps2_send_key :: proc(s: ^PS2, val: u8) {
        log.debugf("ps2: %6s send_key %02x current status %02x", s.name, val, s.status)
        s.data = val
        s.status = s.status | PS2_STAT_OBF

        s.pic->trigger(.KBD_PS2)
        return
}

/*

default:

    KBD_DATA        :: 0x03 // $AF1803 for reading and writing
    KBD_COMMAND     :: 0x07 // $AF1807 for writing
    KBD_STATUS      :: 0x07 // $AF1807 for reading

FMX:
    KBD_DATA        :: 0x00 // $AF1060 for reading and writing
    KBD_COMMAND     :: 0x04 // $AF1064 for writing
    KBD_STATUS      :: 0x04 // $AF1064 for reading
*/

ps2_read :: proc(s: ^PS2, mode: BITS, base, busaddr: u32) -> (val: u32) {

    if mode != .bits_8 {
        emu.unsupported_read_size(#procedure, s.name, s.id, mode, busaddr)
        return
    }

    val = cast(u32) ps2_read8(s, busaddr - base)

    return
}

ps2_write :: proc(s: ^PS2, mode: BITS, base, busaddr, val: u32) {

    if mode != .bits_8 {
        emu.unsupported_write_size(#procedure, s.name, s.id, mode, busaddr, val)
        return
    }

    ps2_write8(s, busaddr - base,   u8(val))

    return
}

ps2_read8 :: proc(s: ^PS2, addr: u32) -> (val: u8) {
    switch addr {
    case KBD_DATA:          // 0x60
        log.debugf("ps2: %6s read     KBD_DATA: val %02x", s.name, s.data)
        s.status = s.status & ~PS2_STAT_OBF
        val = s.data

    case KBD_STATUS:        // 0x64
        if s.debug {
            log.debugf("ps2: %6s read   KBD_STATUS: val %02x", s.name, s.status)
        }
        val = s.status
    case:
        log.warnf("ps2: %6s Read  addr %6x is not implemented, 0 returned", s.name, addr)
        val = 0
    }

    return
}

ps2_write8 :: proc(s: ^PS2, addr: u32, val: u8) {
    switch addr {
    case KBD_DATA: // 0x60
        if s.ccb_write_mode {
            log.debugf("ps2: %6s write    KBD_DATA: val %02x -> CCB", s.name, val)

             s.ccb_write_mode  = false
             s.CCB             = val
             return 
        }

        switch val {
        case 0xf4: // mouse/keyboard enable
            s.status = s.status | PS2_STAT_OBF
            s.data   = PS2_RESP_ACK
            s.debug  = false  // to get rid console messages in case of pooling
        case 0xf5: // mouse/keyboard disable
            s.status = s.status | PS2_STAT_OBF
        case 0xf6: // mouse - reset without self-test
            s.status = s.status | PS2_STAT_OBF
        case 0xff: // mouse/keyboard reset
            s.status = s.status | PS2_STAT_OBF

        case:
            log.debugf("ps2: %6s write    KBD_DATA: val %02x - data UNKNOWN", s.name, val)
        }

        log.debugf("ps2: %6s write    KBD_DATA: val %02x", s.name, val)
   case KBD_COMMAND: // 0x64 - command when write
        log.debugf("ps2: %6s write KBD_COMMAND: val %02x", s.name, val)
        switch val {
        case 0x60:
            s.ccb_write_mode    = true
        case 0xd4: // write next byte to second PS/2 port
            s.status = s.status | PS2_STAT_OBF
        case 0xa7: // disable second PS/2 port
            s.status = s.status | PS2_STAT_OBF
            s.second_enabled = false
        case 0xa8: // enable second PS/2 port
            s.second_enabled = true
        case 0xa9: // test second PS/2 port
            s.data = 0x00
            s.status = s.status | PS2_STAT_OBF
        case 0xaa: // test PS/2 controller
            s.data = 0x55
            s.status = s.status | PS2_STAT_OBF
        case 0xab: // test first PS/2 port
            s.data = 0x00
            s.status = s.status | PS2_STAT_OBF
        case 0xad: // disable first PS/2 port
            s.status = s.status | PS2_STAT_OBF
            s.first_enabled = false
        case 0xae: // enable first PS/2 port
            s.first_enabled = true
        case:
            log.debugf("ps2: %6s write KBD_COMMAND: val %02x - command UNKNOWN", s.name, val)
        }
   case:
        log.warnf("ps2: %6s Write addr %6x val %2x is not implemented", s.name, addr, val)
   }
        
    return
}

ps2_delete :: proc(d: ^PS2) {
    free(d)
}
