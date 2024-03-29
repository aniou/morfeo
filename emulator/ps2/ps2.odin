
package ps2

import "core:log"
import "emulator:pic"
import "lib:emu"

// https://wiki.osdev.org/%228042%22_PS/2_Controller

PS2_STAT_OBF    :: u8(0x01)
PS2_STAT_IBF    :: u8(0x02)
PS2_STAT_SYS    :: u8(0x04)
PS2_STAT_CMD    :: u8(0x08)
PS2_STAT_INH    :: u8(0x10)
PS2_STAT_TTO    :: u8(0x20)
PS2_STAT_RTO    :: u8(0x40)
PS2_STAT_PE     :: u8(0x80)

KBD_DATA        :: 0x00 // 0x60 for reading and writing
KBD_COMMAND     :: 0x04 // 0x64 for writing
KBD_STATUS      :: 0x04 // 0x64 for reading


PS2 :: struct {
    read:     proc(^PS2, emu.Request_Size, u32, u32) -> u32,
    write:    proc(^PS2, emu.Request_Size, u32, u32,    u32),
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

    first_enabled:  bool,
    second_enabled: bool,

    debug:          bool,   // temporary
}

ps2_make :: proc(name: string, pic: ^pic.PIC) -> ^PS2 {
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
    
    return s
}

ps2_send_key :: proc(s: ^PS2, val: u8) {
        log.debugf("ps2: %6s send_key %02x current status %02x", s.name, val, s.status)
        s.data = val
        s.status = s.status | PS2_STAT_OBF

        s.pic->trigger(.KBD_PS2)
        return
}

ps2_read :: proc(s: ^PS2, mode: emu.Request_Size, addr_orig, addr: u32) -> (val: u32) {
    switch mode {
        case .bits_8:  val = cast(u32) ps2_read8(s, addr)
        case .bits_16:       emu.unsupported_read_size(#procedure, s.name, s.id, mode, addr_orig)
        case .bits_32:       emu.unsupported_read_size(#procedure, s.name, s.id, mode, addr_orig)
    }
    return
}

ps2_write :: proc(s: ^PS2, mode: emu.Request_Size, addr_orig, addr, val: u32) {
    switch mode {
        case .bits_8:   ps2_write8(s, addr, u8(val))
        case .bits_16:  emu.unsupported_write_size(#procedure, s.name, s.id, mode, addr_orig, val)
        case .bits_32:  emu.unsupported_write_size(#procedure, s.name, s.id, mode, addr_orig, val)
    }
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
