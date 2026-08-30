
package sdc

import "core:container/queue"
import "core:log"
import "core:os"

import "lib:emu"

MODE   :: emu.OpMode
REGION :: emu.Region

// NOTE: The system control registers have two bits relevant to the SD card
// interface: SD_WP, which indicates the write-protect status of the card, and
// SD_CD which indicates if a card is de- tected in the slot. See table 17.1 for
// details.
// [256jr manual]

Register_SDC :: enum u32 {
    SDC_SPI_CTRL            = 0x00,
    SDC_SPI_DATA            = 0x01,
}

CARD :: struct {
}

SDC_SPI_State :: enum {
    INACTIVE,              // inactive
    IDLE,                  // next 3: card identification mode
    READY,
    IDENTIFICATION,
    STANDBY,               // next 6: data transfer mode
    TRANSFER,
    SENDING,
    RECEIVE,
    PROGRAMMING,
    DISCONNECT
}

SDC :: struct {
    name:     string,
    id:       int,
    debug:    bool, 
    req:     ^emu.BusRequest,

    delete:   proc(^SDC                   ),
    read:     proc(^SDC, MODE, u32) -> u32,
    write:    proc(^SDC, MODE, u32,    u32),

    attach:   proc(^SDC, string    ) -> bool ,

    spi_busy:       bool,       
    spi_clk_400Hz:  bool,
    sd_card_en:     bool,       // XXX honor it

    cmdbuf:         queue.Queue(u32),   // command buffer
    outbuf:         queue.Queue(u32),   // queue of output buffer
    out:            u32,                // output value, put on out port
    state:          SDC_SPI_State,

    card_present:   bool,         // is there disk or not?
    card_fd:        ^os.File,     // file descriptor for image

}

make_sdc_spi :: proc(name:string, dcb: ^emu.DeviceConfig) -> (sdc: ^SDC) {
    sdc          = new(SDC)
    sdc.name     = name
    sdc.req      = dcb.req
    sdc.debug    = false

    sdc.delete   = delete_sdc_spi
    sdc.read     =   read_sdc_spi
    sdc.write    =  write_sdc_spi
    sdc.attach   = attach_sdc_spi_card

    sdc.state    = .IDLE

    queue.init(&sdc.outbuf)
    queue.init(&sdc.cmdbuf, capacity = 6)

	// just for test
	attach_sdc_spi_card(sdc, "data/test-f256.img")

    return
}


read_sdc_spi :: proc(sdc: ^SDC, mode: MODE, addr: u32) -> (out: u32) {
    if mode != .mode_8 {
        emu.error_read(sdc.name, sdc.req, .BAD_MODE, mode, addr)
        return
    }

    switch addr {
    case 0:
        out |= 0x80 if sdc.spi_busy       else 0x00
        out |= 0x02 if sdc.spi_clk_400Hz  else 0x00
        out |= 0x01 if sdc.sd_card_en     else 0x00
    case 1:
        out  = sdc.out
    case:
        emu.error_read(sdc.name, sdc.req, .NOT_IMPL, mode, addr)
        return
    }

    if sdc.debug do emu.debug_read(sdc.name, mode, sdc.req, addr, out)

    return
}

write_sdc_spi :: proc(sdc: ^SDC, mode: MODE, addr, val: u32) {
    if mode != .mode_8 {
        emu.error_write(sdc.name, sdc.req, .BAD_MODE, mode, addr, val)
        return
    }

    if sdc.debug do emu.debug_write(sdc.name, mode, sdc.req, addr, val)
    switch addr {
    case 0:
        // sdc.spi_busy is read-only
        sdc.spi_clk_400Hz = (val & 0x02) != 0
        sdc.sd_card_en    = (val & 0x01) != 0
    case 1:
        switch val {
        case 0xFF: 
            if  queue.len(sdc.outbuf) == 0 {                                                                                         
                sdc.out = 0xFF
            } else {
				if sdc.debug do log.debugf("%s queue len %d", sdc.name, queue.len(sdc.outbuf))
                sdc.out = queue.pop_front(&sdc.outbuf)
            }
        case: 
            queue.push_back(&sdc.cmdbuf, val)
            if queue.len(sdc.cmdbuf) == 6 {     // why not 6?
                if sdc.debug do log.debugf("%s got all 6 bytes of command (%v), processing", sdc.name, sdc.cmdbuf)
                do_cmd_sdc_spi(sdc)
            }
        }
    case:
        emu.error_write(sdc.name, sdc.req, .NOT_IMPL, mode, addr, val)
        return
    }

}

delete_sdc_spi :: proc(sdc: ^SDC) {
	os.close(sdc.card_fd)

}

read_sector_sdc_spi :: proc(sdc: ^SDC, sector: u32) {
	data   :  [512]u8
	offset := i64(sector * 512)
	

    _, err := os.seek(sdc.card_fd, offset, .Start)     // XXX - block size always as 512?
    if err != nil {
        log.errorf("%s sdcread seek error position %d %s", sdc.name, offset, err )
        queue.push_back(&sdc.outbuf, 0x40) // parameter error
        sdc.state = .TRANSFER
		return
	}

	_, err = os.read(sdc.card_fd, data[0 : 512])
    if err != nil {
        log.errorf("%s drive read error %s", sdc.name, err )
        queue.push_back(&sdc.outbuf, 0xFF) 
        sdc.state = .TRANSFER
		return
    }

	log.debugf("%s read %v", sdc.name, data)

    queue.push_back(&sdc.outbuf, 0x00) 
    queue.push_back(&sdc.outbuf, 0xFE) 
	for val in data {
    	queue.push_back(&sdc.outbuf, u32(val)) 
	}
    queue.push_back(&sdc.outbuf, 0x00) // no CRC atm
    queue.push_back(&sdc.outbuf, 0x00) // no CRC atm

	return
}

attach_sdc_spi_card :: proc(sdc: ^SDC, path: string) -> bool {
    s, err1 := os.stat(path, context.allocator)
    if err1 != nil {
        log.errorf("%s stat %s failed, error %d", sdc.name, path, err1)
        return false
    }

    f, err2 := os.open(path, flags = os.O_RDWR)
    if err2 != nil {
        log.errorf("%s open %s failed, error %d", sdc.name, path, err2)
        return false
    }
    log.infof("%s succesfully atached %s", sdc.name, path)

    sdc.card_fd      = f
    sdc.card_present = true
    return true
}



// see chapter 7.3.1.3 "Detailed Command Description"
// page 322 (296)
//
do_cmd_sdc_spi :: proc(sdc: ^SDC) {
    cmd :=  queue.get(&sdc.cmdbuf, 0) 
    switch cmd {
    case 00|0x40: // GO IDLE - R1 response
        if sdc.debug do log.debugf("%s got CMD0, going to IDLE", sdc.name)
        queue.push_back(&sdc.outbuf, 0x01)  // "in idle state"
        queue.clear(&sdc.cmdbuf)
        sdc.state = .IDLE
    case 08|0x40: // see 4.9.6 R7 response 145 (119)
        // In the response, the card echoes back both the voltage range
        // and check pattern set in the argument. XXX: different definition on 330 and 145
        if sdc.debug do log.debugf("%s got CMD8", sdc.name)
        pattern := queue.get(&sdc.cmdbuf, 4)
        queue.push_back(&sdc.outbuf, 0x01)  // "in idle state"
        queue.push_back(&sdc.outbuf, 0x00)
        queue.push_back(&sdc.outbuf, 0x00)
        queue.push_back(&sdc.outbuf, 0x01)
        queue.push_back(&sdc.outbuf, pattern) 
        queue.clear(&sdc.cmdbuf)
        sdc.state = .IDLE
	case 17|0x40: // READ_SINGLE_BLOCK - in case of SDHC, SDXC, SDUC - always 512 bytes
		sector := queue.get(&sdc.cmdbuf, 4)			// it is a 32big endian value
	    sector |= queue.get(&sdc.cmdbuf, 3) << 8
	    sector |= queue.get(&sdc.cmdbuf, 2) << 16
	    sector |= queue.get(&sdc.cmdbuf, 1) << 24
        if sdc.debug do log.debugf("%s got CMD17, sector %d position 0x%8x", sdc.name, sector, sector*512)
		read_sector_sdc_spi(sdc, sector)	// <- error responses here
        queue.clear(&sdc.cmdbuf)
    case 41|0x40: // SEND_OP_COND - R1 response 
        // XXX: depending on card type there should be OK or illegal (0xFF and state inactive)
        //      response. At this moment we support only one kind of SD card
        // in arguments, see 4.2.3 Card Initialization and Identification Process
        //  The HCS (Host Capacity Support) bit set to 1 indicates that the host supports
        //  SDHC or SDXC Card. The HCS (Host Capacity Support) bit set to 0 indicates that the host supports
        //  neither SDHC nor SDXC Card
        if sdc.debug do log.debugf("%s got CMD41 going READY", sdc.name)
        queue.push_back(&sdc.outbuf, 0x00)  // "leaving idle state"
        queue.clear(&sdc.cmdbuf)
        sdc.state = .READY
    case 55|0x40: // APP_CMD - R1 response
        if sdc.debug do log.debugf("%s got CMD55", sdc.name)
        queue.push_back(&sdc.outbuf, 0x01)  // "in idle state"
        queue.clear(&sdc.cmdbuf)
        //sdc.state = .IDLE - no data transition (see page 76 / 50)
    case 58|0x40: // READ_OCR - R3 response
        if sdc.debug do log.debugf("%s got CMD58, going SENDING", sdc.name)
        queue.push_back(&sdc.outbuf, 0x00)
        queue.push_back(&sdc.outbuf, 0x80|0x40) // Busy Status: 1 - init complete
                                                // 0x40: SDHC or SDXC type (SDCS - 0)
        queue.push_back(&sdc.outbuf, 0x00)
        queue.push_back(&sdc.outbuf, 0x00)
        queue.push_back(&sdc.outbuf, 0x00)
        queue.clear(&sdc.cmdbuf)
        sdc.state = .SENDING
    case: 
        log.errorf("%s command %d (val 0x%x) (%v) not implemented yet", sdc.name, cmd&0xBF, cmd,  sdc.cmdbuf)
    }
}
