package ps2

import "core:container/queue"
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

PS2_RESP_ERR0   :: u8(0x00)
PS2_RESP_ACK    :: u8(0xFA)
PS2_RESP_RESEND :: u8(0xFE)

KBD_DATA        :: 0x00 // $AF1803 (FMX: $AF1060) for reading and writing
KBD_COMMAND     :: 0x04 // $AF1807 (FMX: $AF1064) for writing
KBD_STATUS      :: 0x04 // $AF1807 (FMX: $AF1064) for reading

BITS :: emu.Bitsize
PS2  :: struct {
    read:     proc(^PS2, BITS, u32, u32) -> u32,
    write:    proc(^PS2, BITS, u32, u32,    u32),
    //send_key: proc(^PS2, u8)  -> bool,
    send_key: proc(^PS2, emu.KEY, emu.KEY_STATE),
    delete:   proc(^PS2),
    kick:     proc(^PS2),

    pic:            ^pic.PIC,

    name:           string,
    id:             int,

    //data:           u8,     // data (usually keycode)
    status:         u8,     // controller status
    CCB:            u8,     // controller configuration byte
    ccb_write_mode: bool,   // denotes that next write should go to CCB
    cmd:            u8,     // if command has a argument, then command code is here
    cmd_write_mode: bool,   // denotes that next write should be a command argument
    scancode_set:   SCANCODE_NR,
    outbuf:         queue.Queue(u8),

    first_enabled:  bool,
    second_enabled: bool,

    debug:          bool,   // temporary
}

ps2_make :: proc(name: string, pic: ^pic.PIC) -> ^PS2 {
    s         := new(PS2)
    s.pic          = pic
    s.read         = ps2_read
    s.write        = ps2_write
    s.delete       = ps2_delete
    s.send_key     = ps2_send_key
    s.kick         = ps2_kick_queue
	s.status       = 0
    s.debug        = true
    s.CCB          = 0
    s.name         = name
    s.scancode_set = .one

    queue.init(&s.outbuf)
    return s
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
        if queue.len(s.outbuf) == 0 {
            val = 0
			s.status = s.status & ~PS2_STAT_OBF
            log.debugf("ps2: %6s read     KBD_DATA: queue empty", s.name)
            return
        }

        log.debugf("ps2: %6s read     KBD_DATA:          qlen: %d", s.name, queue.len(s.outbuf))
        val = queue.pop_front(&s.outbuf)
        if queue.len(s.outbuf) == 0 {
			s.status = s.status & ~PS2_STAT_OBF
		} else {
			s.status = s.status | PS2_STAT_OBF    // redundant, but to be sure...
		}
        log.debugf("ps2: %6s read     KBD_DATA: val %02x qlen: %d", s.name, val, queue.len(s.outbuf))

    case KBD_STATUS:        // 0x64
        if s.debug do log.debugf("ps2: %6s read   KBD_STATUS: val %02x", s.name, s.status)
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
        if s.debug do log.debugf("ps2: %6s write    KBD_DATA: val %02x", s.name, val)

        if s.ccb_write_mode {
            if s.debug do log.debugf("ps2: %6s write    KBD_DATA: val %02x -> CCB", s.name, val)

            s.ccb_write_mode  = false
            s.CCB             = val
            return 
        }

        switch val {
        case 0xf4: // mouse/keyboard enable
            s.status = s.status | PS2_STAT_OBF
            //s.data   = PS2_RESP_ACK
			queue.push_back(&s.outbuf, PS2_RESP_ACK)
            s.debug  = false  // to get rid console messages in case of pooling
        case 0xf5: // mouse/keyboard disable
            s.status = s.status | PS2_STAT_OBF
        case 0xf6: // mouse - reset without self-test
            s.status = s.status | PS2_STAT_OBF
        case 0xff: // mouse/keyboard reset
            s.status = s.status | PS2_STAT_OBF
            log.debugf("ps2: %6s write    KBD_DATA: val %02x - RESET from CCB?", s.name, val)
        case:
            log.debugf("ps2: %6s write    KBD_DATA: val %02x - data UNKNOWN", s.name, val)
        }

   case KBD_COMMAND: // 0x64 - command when write
        if s.debug do log.debugf("ps2: %6s write KBD_COMMAND: val %02x", s.name, val)

        if s.cmd_write_mode {
            s.cmd_write_mode  = false
            switch s.cmd {
            case 0xed: 
                s.status = s.status | PS2_STAT_OBF
                //s.data   = PS2_RESP_ACK
                queue.push_back(&s.outbuf, PS2_RESP_ACK)
                log.warnf("ps2: %6s write arg for KBD_COMMAND LED (0xed): val %02x not supported", s.name, val)
            case 0xf0:  // for support of get scancode I need a queue...
                switch val {
				case 0:
					queue.push_back(&s.outbuf, PS2_RESP_ACK)
					queue.push_back(&s.outbuf, u8(s.scancode_set))
				case 1 ..= 3:	
                    s.status       = s.status | PS2_STAT_OBF
                    //s.data         = PS2_RESP_ACK
					queue.push_back(&s.outbuf, PS2_RESP_ACK)
                    s.scancode_set = SCANCODE_NR(val)
                case:
                    s.status       = s.status | PS2_STAT_OBF
                    //s.data         = PS2_RESP_ERR0
					queue.push_back(&s.outbuf, PS2_RESP_ERR0)
                }
                log.warnf("ps2: %6s write arg for KBD_COMMAND SCANCODE (0xf0)): set to %d", s.name, val)
            case     :
                log.errorf("ps2: %6s write arf for UKNONWN KBD_COMMAND %02x: val %02x not supported", s.name, s.cmd, val)
            }
            return
        }

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
            //s.data = 0x00
            queue.push_back(&s.outbuf, 0x00)
            s.status = s.status | PS2_STAT_OBF
        case 0xaa: // test PS/2 controller
            //s.data = 0x55
            queue.push_back(&s.outbuf, 0x55)
            s.status = s.status | PS2_STAT_OBF
        case 0xab: // test first PS/2 port
            //s.data = 0x00
            s.status = s.status | PS2_STAT_OBF
            queue.push_back(&s.outbuf, 0x00)
        case 0xad: // disable first PS/2 port
            s.status = s.status | PS2_STAT_OBF
            s.first_enabled = false
        case 0xae: // enable first PS/2 port
            s.first_enabled = true
        case 0xed: // set LED status
            s.cmd = val
            s.cmd_write_mode = true
        case 0xf0: // get/set current scancode
            s.cmd = val
            s.cmd_write_mode = true
        case 0xf6: // set default parameters (do nothing now)
            s.status = s.status | PS2_STAT_OBF
			queue.push_back(&s.outbuf, PS2_RESP_ACK)
        //case 0xfe: // resend last byte
        //             - worth to implement (add last_byte and put it when read from queue)
        case 0xff: // reset
            s.status = s.status | PS2_STAT_OBF
			queue.push_back(&s.outbuf, PS2_RESP_ACK)
			queue.push_back(&s.outbuf, 0xAA)            // self-test passed
            log.debugf("ps2: %6s write    KBD_DATA: val %02x - RESET", s.name, val)
        case:
            log.warnf("ps2: %6s write KBD_COMMAND: val %02x - command UNKNOWN", s.name, val)
        }
   case:
        log.warnf("ps2: %6s Write addr %6x val %2x is not implemented", s.name, addr, val)
   }
        
    return
}

ps2_delete :: proc(d: ^PS2) {
    free(d)
}


/*
ps2_send_key :: proc(s: ^PS2, val: u8) -> (ok: bool = true) {
    if s.status & PS2_STAT_OBF == PS2_STAT_OBF {
        ok       = false
        log.warnf("ps2: %6s send_key %02x but buffer is full, delayed", s.name, val)
    } else {
        s.data   = val
        s.status = s.status | PS2_STAT_OBF
        if s.debug do log.debugf("ps2: %6s send_key %02x current status %02x", s.name, val, s.status)
    }

    s.pic->trigger(.KBD_PS2)
    return
}
*/

ps2_send_key :: proc(s: ^PS2, key: emu.KEY, state: emu.KEY_STATE) {
        log.debugf("------")
        log.debugf("ps2: %6s send_key %v current status %v", s.name, key, state)
        s.status = s.status | PS2_STAT_OBF

        codes   := scancode[s.scancode_set][key][state]
        trigger := false
        for c in codes {
            if c == 0  do break      // empty code or end of sequence
            if s.debug do log.debugf("ps2: %6s push code %02x in queue", s.name, c)
            trigger = true
            queue.push_back(&s.outbuf, c)
        }

        if trigger do s.pic->trigger(.KBD_PS2)
        return
}

ps2_kick_queue :: proc(s: ^PS2) {
        if queue.len(s.outbuf) == 0 {
            return
        }
        if s.debug do log.debugf("ps2: %6s kick_queue current len %d", s.name, queue.len(s.outbuf))
        s.pic->trigger(.KBD_PS2)
        return
}

