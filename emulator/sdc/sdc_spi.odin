
package sdc

import "core:log"
import "core:os"

import "lib:emu"

MODE   :: emu.OpMode
REGION :: emu.Region

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

    attach:   proc(^SDC, int, string    ) -> bool ,

    spi_busy:       bool,       
    spi_clk_400Hz:  bool,
    sc_card_en:     bool,
}

make_sdc_spi :: proc(name:string, dcb: ^emu.DeviceConfig) -> (sdc: ^SDC) {
    sdc          = new(SDC)
    sdc.name     = name
    sdc.req      = dcb.req
    sdc.debug    = true

    sdc.delete   = delete_sdc_spi
    sdc.read     =   read_sdc_spi
    sdc.write    =  write_sdc_spi
    //s.attach   = attach_sdc_spi_card

    //s.card     = CARD{ attached = false }

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
        out |= 0x01 if sdc.sc_card_en     else 0x00
    case:
        emu.error_write(sdc.name, sdc.req, .NOT_IMPL, mode, addr,  out)
    }

    emu.debug_read(sdc.name, mode, sdc.req, addr, out)

    return
}

write_sdc_spi :: proc(sdc: ^SDC, mode: MODE, addr, val: u32) {
    if mode != .mode_8 {
        emu.error_read(sdc.name, sdc.req, .BAD_MODE, mode, addr)
        return
    }

    emu.debug_read(sdc.name, mode, sdc.req, addr, val)
    emu.error_read(sdc.name, sdc.req, .NOT_IMPL, mode, addr)
}

delete_sdc_spi :: proc(sdc: ^SDC) {

}

