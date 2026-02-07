package sdc

// NOT FINISHED YET implementation of SDC interface embedded 
// into A2560* machines

// https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ata/ns-ata-_identify_device_data
// http://wiki.osdev.org/PCI_IDE_Controller
//
// T13/2161-D Revision 5 
// 7.12.7

/*

import "core:log"
import "core:os"

import "lib:emu"

MODE   :: emu.OpMode
REGION :: emu.Region

Register_SDC :: enum u32 {
    SDC_VERSION_REG         = 0x00,
    SDC_CONTROL_REG         = 0x01,
    SDC_TRANS_TYPE_REG      = 0x02,
    SDC_TRANS_CONTROL_REG   = 0x03,
    SDC_TRANS_STATUS_REG    = 0x04,
    SDC_TRANS_ERROR_REG     = 0x05,
    SDC_DIRECT_ACCESS_REG   = 0x06,
    SDC_SD_ADDR_7_0_REG     = 0x07,
    SDC_SD_ADDR_15_8_REG    = 0x08,
    SDC_SD_ADDR_23_16_REG   = 0x09,
    SDC_SD_ADDR_31_24_REG   = 0x0A,
    SDC_SPI_CLK_DEL_REG     = 0x0B,
    SDC_RX_FIFO_DATA_REG    = 0x10,
    SDC_RX_FIFO_DATA_CNT_HI = 0x12,
    SDC_RX_FIFO_DATA_CNT_LO = 0x13,
    SDC_RX_FIFO_CTRL_REG    = 0x14,
    SDC_TX_FIFO_DATA_REG    = 0x20,
    SDC_TX_FIFO_CTRL_REG    = 0x24,
}

CARD :: struct {
    lba0:           u8,     //  0:7   of LBA
    lba1:           u8,     //  8:15  of LBA
    lba2:           u8,     // 16:23  of LBA
    lba3:           u8,     // 24:31  of LBA


    command:        u8, 
    status:         u8,
    err:            ERROR,
    state:          STATE,

    attached:       bool,         // is there disk or not?
    fd:             os.Handle,    // file descriptor for image
    offset:         u32,          // current file position
    data:           [512*256]u8,
    ident:          [256]u16,     // identification space
    data_amount:    int,
    data_pointer:   int,
}

SDC_Transfer_Type :: enum {
    DIRECT_ACCESS = 0x00,
    INIT_SD       = 0x01,
    READ_BLOCK    = 0x02,
    WRITE_BLOCK   = 0x03,
}

SDC :: struct {
    name:     string,
    id:       int,

    read:     proc(^SDC, MODE, u32, u32) -> u32,
    write:    proc(^SDC, MODE, u32, u32,    u32),
    delete:   proc(^SDC            ),
    attach:   proc(^SDC, int, string    ) -> bool ,

    lba0:            u8,     //  0:7   of LBA
    lba1:            u8,     //  8:15  of LBA
    lba2:            u8,     // 16:23  of LBA
    lba3:            u8,     // 24:31  of LBA

    write_protect   bool,   
    transfer_type   SDC_Transfer_Type,
    transfer_ctrl   u32,

    debug:    bool, 
}

sdc_make :: proc(name:string) -> (s: ^SDC) {
    s         := new(SDC)
    s.name     = name
    s.read     = sdc_read
    s.write    = sdc_write
    s.delete   = sdc_delete
    s.attach   = sdc_attach_card
    s.card     = CARD{ attached = false }
    s.debug    = false

    return pata
}

// A2560X_GABE_SDC_PRESENT ::  0x0100      /* Is an SD card present?          --- 0:Yes, 1:No */
// A2560X_GABE_SDC_WPROT   ::  0x0200      /* Is the SD card write protected? --- 0:Yes, 1:No */
sdc_card_status :: proc(d: ^SDC, mode: MODE, addr, ra: u32) -> (val: u32) {
    TARGET == "a2560x" {
        if mode != .mode_16be {
            emu.error_read(d.name, d.req, .BAD_MODE, mode, addr)
            return
        }

        if !s.card.write_protect do val |= 0x0200       // yes, reverse logic here
        if !s.card.attached      do val |= 0x0100       // yes, reverse logic here
        return 
        
    } else {
        case: log.warnf("sdc: %6s read addr %08x (status) for %s not implemented, 0 returned", p.name, busaddr, TARGET)
    }
}

sdc_read :: proc(d: ^SDC, mode: MODE, addr, ra: u32, region: REGION = .MAIN) -> (val: u32) {
    if region == .STATUS {
        return sdc_card_status(d, mode, base, busaddr)
    }

    if mode != .mode_8 {
        emu.error_read(d.name, d.req, .BAD_MODE, mode, addr)
        return
    }

    addr := busaddr - base
    switch Register_SDC(addr) {
    case SDC_VERSION_REG        : val = 0x12                  // dunno, that returns my a2560x      
    case SDC_CONTROL_REG        : val = 0x00
    case SDC_TRANS_TYPE_REG     : val = u32(d.transfer_type)
    case SDC_TRANS_CONTROL_REG  : val - 0x00
    case SDC_TRANS_STATUS_REG   : val = d.status_register
    case SDC_TRANS_ERROR_REG    : val = d.error_register
    case SDC_DIRECT_ACCESS_REG  : log.warnf("sdc: %6s SDC_DIRECT_ACCESS_REG not implemented, 0 returned")
    case SDC_SD_ADDR_7_0_REG    : val = d.lba0
    case SDC_SD_ADDR_15_8_REG   : val = d.lba1
    case SDC_SD_ADDR_23_16_REG  : val = d.lba2
    case SDC_SD_ADDR_31_24_REG  : val = d.lba3
    case SDC_SPI_CLK_DEL_REG    : log.warnf("sdc: %6s SDC_SPI_CLK_DEL_REG not implemented, 0 returned")
    case SDC_RX_FIFO_DATA_REG   : val = sdc_get_data_from_buffer(d)
    case SDC_RX_FIFO_DATA_CNT_HI: val = (d.data_len >> 8) & 0xFF
    case SDC_RX_FIFO_DATA_CNT_LO: val = (d.data_len     ) & 0xFF
    case SDC_RX_FIFO_CTRL_REG   : val = 0
    case SDC_TX_FIFO_DATA_REG   : val = 0
    case SDC_TX_FIFO_CTRL_REG   : val = 0
    }
    return
}

sdc_write :: proc(d: ^SDC, mode: MODE, addr, ra, val: u32, region: REGION = .MAIN) {
    if region == .STATUS {
        return
    }

    if mode != .mode_8 {
        emu.error_read(d.name, d.req, .BAD_MODE, mode, addr)
        return
    }

    addr := busaddr - base
    switch Register_SDC(addr) {
    case SDC_VERSION_REG        :       
    case SDC_CONTROL_REG        :
    case SDC_TRANS_TYPE_REG     :
    case SDC_TRANS_CONTROL_REG  : if val & 0x01 == 0x01 do sdc_start_transfer(d)
    case SDC_TRANS_STATUS_REG   :
    case SDC_TRANS_ERROR_REG    :
    case SDC_DIRECT_ACCESS_REG  :
    case SDC_SD_ADDR_7_0_REG    :
    case SDC_SD_ADDR_15_8_REG   :
    case SDC_SD_ADDR_23_16_REG  :
    case SDC_SD_ADDR_31_24_REG  :
    case SDC_SPI_CLK_DEL_REG    :
    case SDC_RX_FIFO_DATA_REG   :
    case SDC_RX_FIFO_DATA_CNT_HI:
    case SDC_RX_FIFO_DATA_CNT_LO:
    case SDC_RX_FIFO_CTRL_REG   :
    case SDC_TX_FIFO_DATA_REG   :
    case SDC_TX_FIFO_CTRL_REG   :
    }
    return
}

/*
pata_read8 :: proc(p: ^SDC, addr: u32) -> (val: u8) {
    reg := REG_DESC

    switch addr {
    case REG_SDC_DATA_LO:  val = pata_get_data_from_buffer(p)
    case REG_SDC_DATA_HI:  val = pata_get_data_from_buffer(p)
    case REG_SDC_ERROR:    val = u8(p.drive[p.selected].err)
    case REG_SDC_SECT_SRT: val = p.drive[p.selected].lba0
    case REG_SDC_CMD_STAT: val = p.drive[p.selected].status
    case: log.warnf("pata: %6s drive %d Read  addr %6x is not implemented, 0 returned", p.name, p.selected, addr)
    }
    if p.debug do log.debugf("pata: %6s drive %d read  0x%02x from %02x %13s", p.name, p.selected, val, addr, reg[addr])
    return
}

pata_write8 :: proc(p: ^SDC, addr: u32, val: u8) {
    reg := REG_DESC

    switch addr {
    case REG_SDC_CMD_STAT: // 0x0e - issue command when write

        drive         := &p.drive[p.selected]
        drive.status &~= (ST_ERR|ST_DRDY)       // clear ERR and READY
        drive.status  |=  ST_BSY
        drive.err      = .NONE
        drive.state    = .IDE_CMD
        drive.command  = val                // just for sake

        switch val {
        case 0x00: 
            if p.debug do log.debugf("pata: %6s write 0x%02x to   %02x %-22s (NOP)", p.name, val, addr, reg[addr])
            drive.status  &~=  ST_BSY
            drive.status   |=  ST_DRDY
        case CMD_READ_PIO, CMD_READ_PIO_NR:    // 0x20, 0x21
            if p.debug do log.debugf("pata: %6s write 0x%02x to   %02x %-22s (READ SECT)", p.name, val, addr, reg[addr])
            pata_cmd_read_sectors(p)
        case CMD_WRITE_PIO, CMD_WRITE_PIO_NR:  // 0x30, 0x31
            if p.debug do log.debugf("pata: %6s write 0x%02x to   %02x %-22s (WRITE SECT)", p.name, val, addr, reg[addr])
            pata_cmd_write_sectors(p)
        case CMD_IDENTIFY:                     // 0xEC
            if p.debug do log.debugf("pata: %6s write 0x%02x to   %02x %-22s (IDENTIFY)", p.name, val, addr, reg[addr])
            for d,i in drive.ident {
                drive.data[i*2  ] = u8(d >>    8)
                drive.data[i*2+1] = u8(d  & 0xFF)
            }
            drive.data_amount   = 512
            drive.data_pointer  = 0
            drive.status      &~= ST_BSY
            drive.status       |= ST_DRQ
            drive.state         = .IDE_DATA_IN
        case:
            log.warnf("pata: %6s write 0x%02x to   %02x %-22s (unknown)", p.name, val, addr, reg[addr])
        }

    case REG_SDC_DATA_LO:
        pata_put_data_into_buffer(p, val)
        if p.debug do log.debugf("pata: %6s drive %d write lo16 0x%02x to buffer", p.name, p.selected, val)

    case REG_SDC_DATA_HI:
        pata_put_data_into_buffer(p, val)
        if p.debug do log.debugf("pata: %6s drive %d write hi16 0x%02x to buffer", p.name, p.selected, val)

    case REG_SDC_SECT_CNT:  // 0x04
        if p.debug do log.debugf("pata: %6s drive %d write 0x%02x to   %02x %-22s", p.name, p.selected, val, addr, reg[addr])
        p.drive[p.selected].sector_count = val

    case REG_SDC_SECT_SRT:  // 0x06
        if p.debug do log.debugf("pata: %6s drive %d write 0x%02x to   %02x %-22s", p.name, p.selected, val, addr, reg[addr])
        p.drive[p.selected].lba0         = val

    case REG_SDC_CLDR_LO:   // 0x08
        if p.debug do log.debugf("pata: %6s drive %d write 0x%02x to   %02x %-22s", p.name, p.selected, val, addr, reg[addr])
        p.drive[p.selected].lba1         = val
    case REG_SDC_CLDR_HI:   // 0x0a
        if p.debug do log.debugf("pata: %6s drive %d write 0x%02x to   %02x %-22s", p.name, p.selected, val, addr, reg[addr])
        p.drive[p.selected].lba2         = val

    case REG_SDC_DEVH: // 0x0c
        if p.debug do log.debugf("pata: %6s drive %d write 0x%02x to   %02x %-22s", p.name, p.selected, val, addr, reg[addr])

        if (val & DEVH_DEV) > 0 {
            p.selected = 1
        } else {
            p.selected = 0
        }
        p.drive[p.selected].lba_mode = (val & DEVH_LBA) > 0
        p.drive[p.selected].lba3     =  val & DEVH_HEAD // bits 0:3


        if p.debug do log.debugf("pata: %6s mode drive %d LBA %t lba3 %d", 
                    p.name, p.selected, p.drive[p.selected].lba_mode, p.drive[p.selected].lba3)

    case:
        log.warnf("pata: %6s drive %d Write addr %6x val %2x is not implemented", p.name, p.selected, addr, val)
    }
    return
}

pata_attach_disk :: proc(p: ^SDC, number: int, path: string) -> bool {
    s, err1 := os.stat(path)
    if err1 != 0 {
        log.errorf("%s stat %s failed, error %d", p.name, path, err1)
        return false
    }

    f, err2 := os.open(path, flags = os.O_RDWR)
    if err2 != 0 {
        log.errorf("%s open %s failed, error %d", p.name, path, err2)
        return false
    }
    log.infof("%s succesfully atached %s as disk %d", p.name, path, number)

    p.drive[number].fd       = f
    p.drive[number].attached = true
    pata_make_identity(&p.drive[number].ident, s.size)
    return true
}

pata_delete :: proc(p: ^SDC) {
    if p.drive[0].attached {
        os.flush(p.drive[0].fd)
        os.close(p.drive[0].fd)
    }

    if p.drive[1].attached {
        os.flush(p.drive[1].fd)
        os.close(p.drive[1].fd)
    }

    free(p)
    return
}

pata_calculate_block :: proc(p: ^SDC) -> (i64, bool) {
    block_number: i64

    drive := p.drive[p.selected]
    if !drive.lba_mode {
        log.errorf("%s CHS not supported yet for drive %d", p.name, p.selected)
        return 0, false
    }

    block_number = i64(drive.lba3) << 24 |
                   i64(drive.lba2) << 16 |
                   i64(drive.lba1) <<  8 |
                   i64(drive.lba0)

    return block_number, true
}

pata_cmd_read_sectors :: proc(p: ^SDC) {
    drive      := &p.drive[p.selected]

    offset, ok := pata_calculate_block(p)
    if !ok {
        drive.status  |= ST_ERR
        drive.status &~= ST_DSC
        drive.err     |= .ERR_NO_ID_MARK_FOUND

        drive.status &~= (ST_BSY|ST_DRQ)
        drive.status  |= ST_DRDY
        drive.state    = .IDE_IDLE

    }

    drive.status  |= ST_DRQ
    _, err := os.seek(drive.fd, offset * 512, 0)     // XXX - block size always as 512?
    if err != 0 {
        log.errorf("%s drive %d read seek error %s", p.name, p.selected, err )
        drive.status  |= ST_ERR
        drive.status &~= ST_DSC
        drive.err     |= .ERR_NO_ID_MARK_FOUND

        drive.status &~= (ST_BSY|ST_DRQ)
        drive.status  |= ST_DRDY
        drive.state    = .IDE_IDLE
        return
    }

    drive.status  |= (ST_DSC | ST_DRDY)
    drive.status &~= ST_BSY

    data_to_read  := int(drive.sector_count) * 512
    if data_to_read == 0 {              // 0 means '256'
        data_to_read = 256 * 512    
    }
    _, err = os.read(drive.fd, drive.data[0 : data_to_read])
    if err != 0 {
        log.errorf("pata: %s drive %d read error %s", p.name, p.selected, err )
        drive.status |= ST_ERR
        drive.err     = .ERR_UNCORRECTABLE_DATA
        return
    }

    // there are data in buffer!
    if p.debug do log.debugf("pata: %6s drive %d read %d bytes from offset %d", p.name, p.selected, data_to_read, offset )
    //fmt.printf("pata: >>> %v\n", drive.data[0 : data_to_read])
    drive.data_amount   = data_to_read
    drive.data_pointer  = 0
    drive.status      &~= ST_BSY
    drive.status       |= ST_DRQ
    drive.state         = .IDE_DATA_IN
    return
}

// that routine does not write sectors itself, but
// prepare envinronment for 'write state', when user
// is able to write amount of data to buffer

// XXX - optimize pata_calculate/seek sequence of errors
pata_cmd_write_sectors :: proc(p: ^SDC) {
    drive      := &p.drive[p.selected]

    offset, ok := pata_calculate_block(p)
    if !ok {
        drive.status  |= ST_ERR
        drive.status &~= ST_DSC
        drive.err     |= .ERR_NO_ID_MARK_FOUND

        drive.status &~= (ST_BSY|ST_DRQ)
        drive.status  |= ST_DRDY
        drive.state    = .IDE_IDLE

    }

    drive.status  |= ST_DRQ
    _, err := os.seek(drive.fd, offset * 512, 0)     // XXX - block size always as 512?
    log.debugf("%s drive %d write seek to position %d", p.name, p.selected, offset * 512)
    if err != 0 {
        log.errorf("%s drive %d write seek error %s", p.name, p.selected, err )
        drive.status  |= ST_ERR
        drive.status &~= ST_DSC
        drive.err     |= .ERR_NO_ID_MARK_FOUND

        drive.status &~= (ST_BSY|ST_DRQ)
        drive.status  |= ST_DRDY
        drive.state    = .IDE_IDLE
        return
    }

    data_to_write  := int(drive.sector_count) * 512
    if data_to_write == 0 {              // 0 means '256'
        data_to_write = 256 * 512    
    }

    if p.debug do log.debugf("pata: %6s drive %d prepare to write %d bytes at offset %d", p.name, p.selected, data_to_write, offset )
    //fmt.printf("pata: >>> %v\n", drive.data[0 : data_to_read])
    drive.data_amount   = data_to_write
    drive.data_pointer  = 0
    drive.status      &~= ST_BSY
    drive.status       |= ST_DRQ | ST_DSC | ST_DRDY
    drive.state         = .IDE_DATA_OUT
    return
}

pata_put_data_into_buffer :: proc(p: ^SDC, val: u8) {
    drive := &p.drive[p.selected]

    if drive.state != .IDE_DATA_OUT {
        if p.debug do log.warnf("pata: %s drive %d write when state %v", p.name, p.selected, drive.state )
        return
    }
    
    drive.data[drive.data_pointer] = val
    log.debugf("pata: %6s drive %d write pointer %d value %d", p.name, p.selected, drive.data_pointer, val )
    drive.data_pointer += 1
    if drive.data_pointer >= drive.data_amount {
        if err := pata_write_sectors_to_disk(p); err {
            return
        }

        drive.status &~= (ST_BSY|ST_DRQ)
        drive.status  |= ST_DRDY
        drive.state    = .IDE_IDLE
    }
    return
}

pata_write_sectors_to_disk :: proc(p: ^SDC) -> (error: bool = false) {
    drive := &p.drive[p.selected]
    _, err := os.write(drive.fd, drive.data[0 : drive.data_amount])
    if err != 0 {
        log.errorf("pata: %s drive %d write error %s", p.name, p.selected, err )
        drive.status |= ST_ERR
        drive.err     = .ERR_UNCORRECTABLE_DATA
        return true
    }
    return
}

pata_get_data_from_buffer :: proc(p: ^SDC) -> (retval: u8) {

    drive := &p.drive[p.selected]

    if drive.state != .IDE_DATA_IN {
        if p.debug do log.warnf("pata: %s drive %d read when state %v", p.name, p.selected, drive.state )
        return 
    }
    
    retval = drive.data[drive.data_pointer]
    //log.debugf("pata: %6s drive %d pointer %d value %d", p.name, p.selected, drive.data_pointer, retval )
    drive.data_pointer += 1
    if drive.data_pointer >= drive.data_amount {
        drive.status &~= (ST_BSY|ST_DRQ)
        drive.status  |= ST_DRDY
        drive.state    = .IDE_IDLE
    }
    return retval
}

*/
*/
