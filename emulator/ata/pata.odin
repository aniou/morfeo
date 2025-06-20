
package ata

import "core:log"
import "core:os"

import "lib:emu"

STATE :: enum {
    IDE_IDLE,
    IDE_CMD,
    IDE_DATA_IN,
    IDE_DATA_OUT,
}

CMD_READ0 :: 0x20   // read with retries if fault comes
CMD_READ1 :: 0x21   // read without retries

ERROR :: enum {
    // controller errors (bits!)
    NONE                   = 0,
    ERR_NO_ADDR_MARK       = 1,
    ERR_NO_TRACK0          = 2,
    ERR_COMMAND_ABORTED    = 4,
    ERR_MEDIA_CHANGE_REQ   = 8,
    ERR_NO_ID_MARK_FOUND   = 16,
    ERR_MEDIA_CHANGED      = 32,
    ERR_UNCORRECTABLE_DATA = 64,
    ERR_BAD_BLOCK          = 128,
}

DEVH_HEAD   :: u8(15)
DEVH_DEV    :: u8(16)
DEVH_LBA    :: u8(64)

BIT0        :: u8(1)
BIT1        :: u8(2)
BIT2        :: u8(4)
BIT3        :: u8(8)
BIT4        :: u8(16)
BIT5        :: u8(32)
BIT6        :: u8(64)
BIT7        :: u8(128)

// controller status (bits)
ST_ERR      :: u8(1)
ST_IDX      :: u8(2)
ST_CORR     :: u8(4)
ST_DRQ      :: u8(8)
ST_DSC      :: u8(16)       // drive seek complete
ST_DF       :: u8(32)
ST_DRDY     :: u8(64)
ST_BSY      :: u8(128)

// addresses (address offset)
when emu.TARGET == "c256fmx" {
    REG_PATA_DATA       : u32 : 0x00  // data8
    REG_PATA_ERROR      : u32 : 0x01  // error on read, feature on write
    REG_PATA_SECT_CNT   : u32 : 0x02  // Sector Count Register (also used to pass parameter for timeout for IDLE Command)
    REG_PATA_SECT_SRT   : u32 : 0x03  // 06: LBA0: low
    REG_PATA_CLDR_LO    : u32 : 0x04  // 08: LBA1: med
    REG_PATA_CLDR_HI    : u32 : 0x05  // 0a: LBA2: hi
    REG_PATA_DEVH       : u32 : 0x06  // 0c: LBA3: top - bit 24 to 27 
    REG_PATA_CMD_STAT   : u32 : 0x07  // 0e: command or status (write or read)
    REG_PATA_DATA_LO    : u32 : 0x08  // data16 low  byte
    REG_PATA_DATA_HI    : u32 : 0x09  // data16 high byte
} else { 
    REG_PATA_DATA       : u32 : 0x00  // data8 and data16
    REG_PATA_DATA_LO    : u32 : 0x00  // data8 and data16
    REG_PATA_DATA_HI    : u32 : 0x01  // data8 and data16
    REG_PATA_ERROR      : u32 : 0x02  // error on read, feature on write
    REG_PATA_SECT_CNT   : u32 : 0x04
    REG_PATA_SECT_SRT   : u32 : 0x06  // 06: LBA0: low
    REG_PATA_CLDR_LO    : u32 : 0x08  // 08: LBA1: med
    REG_PATA_CLDR_HI    : u32 : 0x0a  // 0a: LBA2: hi
    REG_PATA_DEVH       : u32 : 0x0c  // 0c: LBA3: top - bit 24 to 27 
    REG_PATA_CMD_STAT   : u32 : 0x0e  // 0e: command or status (write or read)
}

// for debug purposes
when emu.TARGET == "c256fmx" {
    REG :: [?]string{
            "PATA_DATA8",
            "PATA_ERROR",
            "PATA_SECT_CNT",
            "PATA_SECT_SRT / LBA0",
            "PATA_CLDR_LO  / LBA1",
            "PATA_CLDR_HI  / LBA2",
            "PATA_DEVH     / LBA3",
            "PATA_CMD_STAT",
            "PATA_DATA16 lo",
            "PATA_DATA16 hi",
    }
} else {
    REG :: [?]string{
            "PATA_DATA lo",
            "PATA_DATA hi",
            "PATA_ERROR",
            "offset 0x03",
            "PATA_SECT_CNT",
            "offset 0x05",
            "PATA_SECT_SRT / LBA0",
            "offset 0x07",
            "PATA_CLDR_LO  / LBA1",
            "offset 0x09",
            "PATA_CLDR_HI  / LBA2",
            "offset 0x0b",
            "PATA_DEVH     / LBA3",
            "offset 0x0d",
            "PATA_CMD_STAT",
            "offset 0x0f",
    }
}

/*
Drive / Head Register 
Bit     Abbrev  Function
0 - 3           In CHS addressing, bits 0 to 3 of the head. 
                In LBA addressing, bits 24 to 27 of the block number.
4       DRV     Selects the drive number.
5       1       Always set.
6       LBA     Uses CHS addressing if clear or LBA addressing if set.
7       1       Always set.
*/


DRIVE :: struct {
    lba_mode:        bool,   // LBA or CHS (no implemented)
    lba0:            u8,     // SECTOR      or  0:7   of LBA
    lba1:            u8,     // CYLINDER lo or  8:15  of LBA
    lba2:            u8,     // CYLINDER hi or 16:23  of LBA
    lba3:            u8,     // 0:3 of HEAD or 24:27  of LBA
    sector_count:    u8,     // parameter for operations

    command:         u8, 
    status:          u8,
    err:             ERROR,
    state:           STATE,

    fd:              os.Handle,    // file descriptor for image
    offset:          u32,          // current file position
    data:            [512*256]u8,
    data_amount:     int,
    data_pointer:    int,
}

PATA :: struct {
    name:     string,
    id:       int,

    read:     proc(^PATA, emu.Request_Size, u32, u32) -> u32,
    write:    proc(^PATA, emu.Request_Size, u32, u32,    u32),
    read8:    proc(^PATA, u32) -> u8,
    write8:   proc(^PATA, u32,    u8),
    delete:   proc(^PATA            ),
    attach:   proc(^PATA, int, string    ) -> bool ,

    selected: int,    // selected drive (0, 1)
    drive:    [2]DRIVE,

}

pata_make :: proc(name:string) -> ^PATA {
    pata         := new(PATA)
    pata.name     = name
    pata.read     = pata_read
    pata.write    = pata_write
    pata.read8    = pata_read8
    pata.write8   = pata_write8
    pata.delete   = pata_delete
    pata.attach   = pata_attach_disk
    pata.drive[0] = DRIVE{ status = ST_DRDY }
    pata.drive[1] = DRIVE{ status = ST_DRDY }

    return pata
}

pata_read :: proc(d: ^PATA, mode: emu.Request_Size, addr_orig, addr: u32) -> (val: u32) {
    switch mode {
        case .bits_8:  
            val = cast(u32) pata_read8(d, addr)
        case .bits_16:      // kind of workaround for 0x400 (IDE DATA register)
            val = u32(pata_read8(d, addr  )) << 8 |
                  u32(pata_read8(d, addr+1))
        case .bits_32:       
            emu.unsupported_read_size(#procedure, d.name, d.id, mode, addr_orig)
    }
    return
}

pata_write :: proc(d: ^PATA, mode: emu.Request_Size, addr_orig, addr, val: u32) {
    switch mode {
        case .bits_8:   pata_write8(d, addr, u8(val))
        case .bits_16:  emu.unsupported_write_size(#procedure, d.name, d.id, mode, addr_orig, val)
        case .bits_32:  emu.unsupported_write_size(#procedure, d.name, d.id, mode, addr_orig, val)
    }
    return
}

// XXX - convert (p)ata to (d)evice in code

// there is only one place in FMX kernel, when read from IDE_DATA is mentioned and 
// is look like in following code, so I presume, that IDE_DATA iface isn't used at
// all on these platforms and is not implemented deliberately
//
// if ( TARGET_SYS == SYS_C256_FMX )
//                 setas
//                 LDA @l IDE_DATA                 ; Read and toss out one byte from the 8-bit interface
// .endif
// 


pata_read8 :: proc(p: ^PATA, addr: u32) -> u8 {
        switch addr {
        case REG_PATA_DATA_LO:
            val := pata_get_data_from_buffer(p)
            //s.debug(LOG_TRACE, "pata: %6s drive %d read lo16 0x%02x from buffer\n", s.name, s.selected, val)
            return val
        case REG_PATA_DATA_HI:
            val := pata_get_data_from_buffer(p)
            //s.debug(LOG_TRACE, "pata: %6s drive %d read hi16 0x%02x from buffer\n", s.name, s.selected, val)
            return val
        case REG_PATA_CMD_STAT: // 0x0e - check status when read
             reg := REG
             log.debugf("pata: %6s read  0x%02x from %13s", p.name, p.drive[p.selected].status, reg[addr])
             return p.drive[p.selected].status
        case:
            log.warnf("pata: %6s Read  addr %6x is not implemented, 0 returned", p.name, addr)
            return 0
        }
}

pata_write8 :: proc(p: ^PATA, addr: u32, val: u8) {
        reg := REG
        switch addr {
        case REG_PATA_CMD_STAT: // 0x0e - issue command when write

            drive         := &p.drive[p.selected]
            drive.status &~= (ST_ERR|ST_DRDY)       // clear ERR and READY
            drive.status  |=  ST_BSY
            drive.err      = .NONE
            drive.state    = .IDE_CMD
            drive.command  = val                // just for sake

            switch val {
            case 0x00: 
                log.debugf("pata: %6s write 0x%02x to   %-22s (NOP)", p.name, val, reg[addr])
                drive.status  &~=  ST_BSY
                drive.status   |=  ST_DRDY
            case CMD_READ0, CMD_READ1:  // 0x20, 0x21
                log.debugf("pata: %6s write 0x%02x to   %-22s (READ SECT)", p.name, val, reg[addr])
                pata_cmd_read_sectors(p)
            case:
                log.debugf("pata: %6s write 0x%02x to   %-22s (unknown)", p.name, val, reg[addr])
            }

        case REG_PATA_SECT_CNT:  // 0x04
            log.debugf("pata: %6s write 0x%02x to   %-22s", p.name, val, reg[addr])
            p.drive[p.selected].sector_count = val

        case REG_PATA_SECT_SRT:  // 0x06
            log.debugf("pata: %6s write 0x%02x to   %-22s", p.name, val, reg[addr])
            p.drive[p.selected].lba0         = val

        case REG_PATA_CLDR_LO:   // 0x08
            log.debugf("pata: %6s write 0x%02x to   %-22s", p.name, val, reg[addr])
            p.drive[p.selected].lba1         = val

        case REG_PATA_CLDR_HI:   // 0x0a
            log.debugf("pata: %6s write 0x%02x to   %-22s", p.name, val, reg[addr])
            p.drive[p.selected].lba2         = val

        case REG_PATA_DEVH: // 0x0c
            log.debugf("pata: %6s write 0x%02x to   %-22s", p.name, val, reg[addr])

            if (val & DEVH_DEV) > 0 {
                p.selected = 1
            } else {
                p.selected = 0
            }
            p.drive[p.selected].lba_mode = (val & DEVH_LBA) > 0
            p.drive[p.selected].lba3     =  val & DEVH_HEAD // bits 0:3


            log.debugf("pata: %6s mode drive %d LBA %t lba3 %d", 
                        p.name, p.selected, p.drive[p.selected].lba_mode, p.drive[p.selected].lba3)

        case:
            log.warnf("pata: %6s Write addr %6x val %2x is not implemented", p.name, addr, val)
        }
        return
}

pata_attach_disk :: proc(p: ^PATA, number: int, path: string) -> bool {
    f, err := os.open(path)
    if err != 0 {
        log.errorf("%s open %s failed, error %d", p.name, path, err)
        return false
    }
    log.debugf("%s succesfully atached %s as disk %d", p.name, path, number)

    p.drive[number].fd = f
    return true
}

pata_delete :: proc(p: ^PATA) {
    os.close(p.drive[0].fd)
    os.close(p.drive[1].fd)
    free(p)
    return
}

pata_calculate_block :: proc(p: ^PATA) -> (i64, bool) {
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

pata_cmd_read_sectors :: proc(p: ^PATA) {
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

    _, err := os.seek(drive.fd, offset * 512, 0)     // XXX - block size always as 512?
    if err != 0 {
        log.errorf("%s drive %d seek error %s", p.name, p.selected, err )
        drive.status  |= ST_ERR
        drive.status &~= ST_DSC
        drive.err     |= .ERR_NO_ID_MARK_FOUND

        drive.status &~= (ST_BSY|ST_DRQ)
        drive.status  |= ST_DRDY
        drive.state    = .IDE_IDLE
        return
    }

    drive.status  |= (ST_DRQ | ST_DSC | ST_DRDY)    // FoenixMCP required DATA_READY
    drive.status &~= ST_BSY

    data_to_read  := int(drive.sector_count) * 512
    if data_to_read == 0 {              // 0 means '256'
        data_to_read = 256 * 512    
    }
    _, err = os.read(drive.fd, drive.data[0 : data_to_read])
    if err != 0 {
        log.errorf("pata: %s drive %d error %s", p.name, p.selected, err )
        drive.status |= ST_ERR
        drive.err     = .ERR_UNCORRECTABLE_DATA
        return
    }

    // there are data in buffer!
    log.debugf("pata: %6s drive %d read %d bytes from offset %d", p.name, p.selected, data_to_read, offset )
    //fmt.printf("pata: >>> %v\n", drive.data[0 : data_to_read])
    drive.data_amount   = data_to_read
    drive.data_pointer  = 0
    drive.status      &~= ST_BSY
    drive.status       |= ST_DRQ
    drive.state         = .IDE_DATA_IN
    return
}


pata_get_data_from_buffer :: proc(p: ^PATA) -> (retval: u8) {

    drive := &p.drive[p.selected]

    // XXX - any error?
    if drive.state != .IDE_DATA_IN {
        log.debugf("pata: %s drive %d read from empty buffer", p.name, p.selected )
        return 0
    }
    
    retval = drive.data[drive.data_pointer]
    //s.debug(LOG_ERROR, "pata: %6s drive %d pointer %d value %d\n", s.name, s.selected, drive.data_pointer, retval )
    drive.data_pointer += 1
    if drive.data_pointer >= drive.data_amount {
        drive.status &~= (ST_BSY|ST_DRQ)
        drive.status  |= ST_DRDY
        drive.state    = .IDE_IDLE
    }
    return retval
}





/*
func (s *PATA) Read(fn byte, addr uint32) (byte, error) {


        switch addr {
        case REG_PATA_DATA:
        val := s.get_data_from_buffer()
                //s.debug(LOG_TRACE, "pata: %6s drive %d read lo16 0x%02x from buffer\n", s.name, s.selected, val)
        return val, nil
        case REG_PATA_DATA+1:
        val := s.get_data_from_buffer()
                //s.debug(LOG_TRACE, "pata: %6s drive %d read hi16 0x%02x from buffer\n", s.name, s.selected, val)
        return val, nil
        case REG_PATA_CMD_STAT: // 0x0e - check status when read
                s.debug(LOG_TRACE, "pata: %6s read  0x%02x from %13s\n", s.name, s.drive[s.selected].status, REG[addr])
                return s.drive[s.selected].status, nil
        default:
                return 0, fmt.Errorf("pata: %6s Read  addr %6x is not implemented, 0 returned", s.name, addr)
        }
}

func (s *PATA) Write(fn byte, addr uint32, val byte) error {

        switch addr {
        case REG_PATA_CMD_STAT: // 0x0e - issue command when write

            drive         := &s.drive[s.selected]
        drive.status &^= (ST_ERR|ST_DRDY)       // clear ERR and READY
        drive.status  |=  ST_BSY
                drive.err      = 0
                drive.state    = IDE_CMD
        drive.command  = val                // just for sake

                switch val {
                case 0x00: 
                        s.debug(LOG_TRACE, "pata: %6s write 0x%02x to   %-22s (NOP)\n", s.name, val, REG[addr])
            drive.status  &^=  ST_BSY
            drive.status   |=  ST_DRDY
                case CMD_READ0, CMD_READ1:  // 0x20, 0x21
                        s.debug(LOG_TRACE, "pata: %6s write 0x%02x to   %-22s (READ SECT)\n", s.name, val, REG[addr])
            s.cmd_read_sectors()
                default:
                        s.debug(LOG_ERROR, "pata: %6s write 0x%02x to   %-22s (unknown)\n", s.name, val, REG[addr])
                }

        case REG_PATA_SECT_CNT:  // 0x04
                s.debug(LOG_TRACE, "pata: %6s write 0x%02x to   %-22s\n", s.name, val, REG[addr])
                s.drive[s.selected].sector_count = val

        case REG_PATA_SECT_SRT:  // 0x06
                s.debug(LOG_TRACE, "pata: %6s write 0x%02x to   %-22s\n", s.name, val, REG[addr])
                s.drive[s.selected].lba0         = val

        case REG_PATA_CLDR_LO:   // 0x08
                s.debug(LOG_TRACE, "pata: %6s write 0x%02x to   %-22s\n", s.name, val, REG[addr])
                s.drive[s.selected].lba1         = val

        case REG_PATA_CLDR_HI:   // 0x0a
                s.debug(LOG_TRACE, "pata: %6s write 0x%02x to   %-22s\n", s.name, val, REG[addr])
                s.drive[s.selected].lba2         = val

        case REG_PATA_DEVH: // 0x0c
                s.debug(LOG_TRACE, "pata: %6s write 0x%02x to   %-22s\n", s.name, val, REG[addr])

                if (val & DEVH_DEV) > 0 {
                        s.selected = 1
                } else {
                        s.selected = 0
                }
                s.drive[s.selected].lba_mode = (val & DEVH_LBA) > 0
                s.drive[s.selected].lba3     =  val & DEVH_HEAD // bits 0:3


                s.debug(LOG_TRACE, "pata: %6s mode drive %d LBA %t lba3 %d\n", 
                        s.name, s.selected, s.drive[s.selected].lba_mode, s.drive[s.selected].lba3)

        default:
                return fmt.Errorf("pata: %6s Write addr %6x val %2x is not implemented", s.name, addr, val)
        }
        return nil
}
*/
