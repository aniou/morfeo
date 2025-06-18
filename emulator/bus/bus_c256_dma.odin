package bus

import "core:log"

import "emulator:pic"

import "lib:emu"

/*
    A bus-level looks like a good place for DMA-like routines: they have
    a direct access to ram->data and gpu->vram areas without introducing
    additional abstraction layers.

    A steps for running DMA transfer:

    Enable and configure the VDMA but do not trigger it.
    Enable and configure the SDMA but do not trigger it.
    Trigger the VDMA.
    Trigger the SDMA.
    Execute several NOP instructions to wait for the SDMA controller to halt the CPU.
    Turn off the SDMA controller
    Wait for the VDMA controller to finish.
    Turn off the VDMA controller

    https://wiki.c256foenix.com/index.php?title=System_and_Video_RAM_DMA
*/

// ----------------------------------------------------------------------------------------------------------
VDMA_CONTROL_REG  :: 0xAF_0400
VDMA_STATUS_REG   :: 0xAF_0401  // On read, this register shows the status of the VDMA
VDMA_BYTE_2_WRITE :: 0xAF_0401  // On write, accepts the byte to use in the fill function. 
VDMA_SRC_ADDY_L   :: 0xAF_0402  // 24-bit address of the source block (relative to start of video RAM) 
VDMA_SRC_ADDY_M   :: 0xAF_0403  
VDMA_SRC_ADDY_H   :: 0xAF_0404
VDMA_DST_ADDY_L   :: 0xAF_0405  // 24-bit address of the destination block (relative to start of video RAM) 
VDMA_DST_ADDY_M   :: 0xAF_0406
VDMA_DST_ADDY_H   :: 0xAF_0407

//a for 1-D transfer - overlap with 2D, see case in c256_dma_write
//VDMA_SIZE_L       :: 0xAF_0408  // For 1-D DMA, 24-bit size of transfer in bytes. 
//VDMA_SIZE_M       :: 0xAF_0409
//VDMA_SIZE_H       :: 0xAF_040A
//VDMA_IGNORED      :: 0xAF_040B

// for 2-D transfer
VDMA_X_SIZE_L     :: 0xAF_0408  // For 2-D, 16-bit width of block
VDMA_X_SIZE_H     :: 0xAF_0409
VDMA_Y_SIZE_L     :: 0xAF_040A  // For 2-D, 16-bit height of block
VDMA_Y_SIZE_H     :: 0xAF_040B

VDMA_SRC_STRIDE_L :: 0xAF_040C  // Number of bytes per row in a 2-D source block (16-bits)
VDMA_SRC_STRIDE_H :: 0xAF_040D
VDMA_DST_STRIDE_L :: 0xAF_040E  // Number of bytes per row in a 2-D destination block (16-bits)
VDMA_DST_STRIDE_H :: 0xAF_040F

// ----------------------------------------------------------------------------------------------------------
SDMA_CTRL_REG0    :: 0xAF_0420  // 
SDMA_CTRL_REG1    :: 0xAF_0421  // not used
SDMA_SRC_ADDY_L   :: 0xAF_0422  // 24-bit address of the source (if system RAM is the destination)
SDMA_SRC_ADDY_M   :: 0xAF_0423
SDMA_SRC_ADDY_H   :: 0xAF_0424
SDMA_DST_ADDY_L   :: 0xAF_0425  // 24-bit address of the destination (if system RAM is the destination)
SDMA_DST_ADDY_M   :: 0xAF_0426
SDMA_DST_ADDY_H   :: 0xAF_0427

//a for 1-D transfer - overlap with 2D, see case in c256_dma_write
//SDMA_SIZE_L       :: 0xAF_0428  // 24-bit the size of the transfer in bytes if 1D transfer
//SDMA_SIZE_M       :: 0xAF_0429
//SDMA_SIZE_H       :: 0xAF_042A

// for 2-D transfer
SDMA_X_SIZE_L     :: 0xAF_0428  // 16-bit width of the block for 2D transfer
SDMA_X_SIZE_H     :: 0xAF_0429
SDMA_Y_SIZE_L     :: 0xAF_042A  // 16-bit height of the block for 2D transfert
SDMA_Y_SIZE_H     :: 0xAF_042B
SDMA_SRC_STRIDE_L :: 0xAF_042C  // Number of bytes per row in a 2-D source block (16-bits)
SDMA_SRC_STRIDE_H :: 0xAF_042D
SDMA_DST_STRIDE_L :: 0xAF_042E  // Number of bytes per row in a 2-D destination block (16-bits)
SDMA_DST_STRIDE_H :: 0xAF_042F

SDMA_STATUS_REG   :: 0xAF_0430  // on read  - status of SDMA
SDMA_BYTE_2_WRITE :: 0xAF_0430  // on write - byte to fill memory

DMA :: struct {
    ctrl_enable:     bool, // no comment
    ctrl_2d:         bool, // 0:        1d, 1: 2d
    ctrl_trf_fill:   bool, // 0:  src->dst, 1: fill with *DMA_BYTE_2_WRITE
    ctrl_int_enable: bool, //               1: generate irq after transfer
    ctrl_sysram_src: bool, //               1: source in system ram
    ctrl_sysram_dst: bool, //               1: destination in system ram
    ctrl_start:      bool, // start process, clear before new one
    ctrl_status:      u32, // internal status value

    byte_2_write:     u32, // byte to use with fill function
    src_addy:         u32, // 24-bit addr of source block in vram
    dst_addy:         u32, // 24-bit addr of destination block in vram
    size:             u32, // 24-bit of transfer size              for 1d DMA
    x_size:           u32, // 16-bit of width of block             for 2d DMA
    y_size:           u32, // 16-bit of height of block            for 2d DMA
    src_stride:       u32, // 16-bit bytes per row in source block for 2d DMA
    dst_stride:       u32, // 16-bit bytes per row in dest.  block for 2d DMA

    debug:           bool, // enable/disable debug
}

DMATYPE :: enum {
    SRAM,
    VRAM,
}

DMAOBJ :: struct {
    kind:   DMATYPE,

    addr:    u32,
    stride:  u32,
    x_size:  u32,
    y_size:  u32,
    index:   u32,
    source:  bool,
    name:    string,
    val:     u32,
    count:   u32,
    stop:    bool,
    status:  u32,
}


assign_byte1  :: #force_inline proc(dst, arg: u32) -> (val: u32) {
    val  = dst & 0xFFFF_FF00
    val |= arg 
    return
}

assign_byte2  :: #force_inline proc(dst, arg: u32) -> (val: u32) {
    val  = dst  & 0xFFFF_00FF
    val |= arg << 8
    return
}

assign_byte3  :: #force_inline proc(dst, arg: u32) -> (val: u32) {
    val  = dst  & 0xFF00_FFFF
    val |= arg << 16
    return
}

assign_byte4  :: #force_inline proc(dst, arg: u32) -> (val: u32) {
    val  = dst  & 0x00FF_FFFF
    val |= arg << 24
    return
}

// TODO - better name
@private
c256_dma_read8 :: #force_inline proc(bus: ^Bus, kind: DMATYPE, addr: u32) -> (val: u32) {
    switch kind {
    case .SRAM:    val = bus.ram0->read(.bits_8, addr)
    case .VRAM:    val = bus.gpu0->read(.bits_8, addr, addr, .VRAM0)
    }
    return
}

@private
c256_dma_write8 :: #force_inline proc(bus: ^Bus, kind: DMATYPE, addr, val: u32)        {
    switch kind {
    case .SRAM:    //log.debugf("c256_dma_write8: SRAM %04X VAL %02X", addr, val)
                   bus.ram0->write(.bits_8, addr, val)
    case .VRAM:    //log.debugf("c256_dma_write8: VRAM %04X VAL %02X (%v)", addr, val, bus.gpu0.write)
                   bus.gpu0->write(.bits_8, addr, addr, val, .VRAM0)
    }
    return
}


c256_dma_operation :: proc(bus: ^Bus, obj: ^DMAOBJ) {
    using obj

    if addr + index > 0xFF_FFFF {           // XXX compile-time max RAM/VRAM size?
        stop     = true
        status  |= 0x04  if source else 0x02
        return
    }

    if source {
        val = c256_dma_read8(bus, kind, addr+index)
    } else {
        c256_dma_write8(bus, kind, addr+index, val)
    }

    count += 1
    index += 1
    if index >= x_size {
        addr   += stride
        index   = 0
        y_size -= 1
        stop    = y_size == 0 
    }

    return
}

// 1. 2D transfer
//      x_size = x_size
//      y_size = y_size
//      stride = stride
//      addr   = addr
//
// 2. 1D transfer
//      x_size = size
//      y_size = 1
//      stride = 0
//      addr   = 0
      
//  for copy operation: dst.val = src.val   in     loop
//  for fill operation: dst.val = constant  before loop

c256_dma_set_objects :: proc(dma: ^DMA) -> (src, dst: DMAOBJ) {
    src = DMAOBJ{stop = false, source = true }
    dst = DMAOBJ{stop = false, source = false}

    src.kind = .SRAM if dma.ctrl_sysram_src else .VRAM
    dst.kind = .SRAM if dma.ctrl_sysram_dst else .VRAM

    if dma.ctrl_2d {
        src.x_size  = dma.x_size
        src.y_size  = dma.y_size
        src.stride  = dma.src_stride
        src.addr    = dma.src_addy

        dst.x_size  = dma.x_size
        dst.y_size  = dma.y_size
        dst.stride  = dma.dst_stride
        dst.addr    = dma.dst_addy
    } else {
        src.x_size  = dma.size
        src.y_size  = 1
        src.stride  = 0
        src.addr    = dma.src_addy

        dst.x_size  = dma.size
        dst.y_size  = 1
        dst.stride  = 0
        dst.addr    = dma.dst_addy
    }

    return
}

// XXX - no support for SIZE error in c256_*dma_transfer routines
//
// First, although VDMA will not stop the processor, SDMA will. You therefore
// cannot trigger the VDMA after the SDMA has been triggered, because you will
// not be able to trigger the VDMA before the SDMA block stops the CPU.
//
// so - vdma<>sdma transfer is handled only in c256_sdma_transfer because it 
// is simpler - c256_vdma_transfer does nothing with that

c256_sdma_transfer :: proc(mainbus: ^Bus) {
    bus        := &mainbus.model.(BUS_C256)

    // FILL ---------------------------------------------------------------
    if bus.sdma.ctrl_trf_fill {
        src,dst := c256_dma_set_objects(&bus.sdma)
        dst.val  = bus.sdma.byte_2_write

        for dst.stop == false {
            c256_dma_operation(mainbus, &dst) 
        }
        if bus.sdma.debug {
            log.debugf("%s DMA fill finished after %d bytes status %02x", #procedure, dst.count, dst.status)
        }
        return
    }

    // SRAM to SRAM -------------------------------------------------------
    if  bus.sdma.ctrl_sysram_src &&  bus.sdma.ctrl_sysram_dst {
        src, dst  := c256_dma_set_objects(&bus.sdma)

        for (src.stop || dst.stop) == false {
            c256_dma_operation(mainbus, &src) 
            dst.val = src.val
            c256_dma_operation(mainbus, &dst) 
        }

        if src.stop != dst.stop {
            log.errorf("%s invalid DMA, stop desync: src %v dst %v", #procedure, dst.stop, src.stop)
        }

        if bus.sdma.debug {
            log.debugf("%s DMA SRAM->SRAM finished after %d bytes status %02x", #procedure, dst.count, dst.status)
        }
        return
    }

    // SRAM to VRAM initiated by SDMA -------------------------------------
    // VRAM to SRAM initiated by SDMA too --------------------------------
    if !bus.vdma.ctrl_start {
        log.errorf("%s initiated V<->S but VDMA.ctrl_start is false", #procedure)
        return
    }

    if bus.sdma.ctrl_sysram_src != bus.vdma.ctrl_sysram_src {
        log.errorf("%s incosistent SDMA/VDMA sysram_src: %v %v",
                   #procedure, bus.sdma.ctrl_sysram_src, bus.vdma.ctrl_sysram_src)
        return
    }

    if bus.sdma.ctrl_sysram_dst != bus.vdma.ctrl_sysram_dst {
        log.errorf("%s incosistent SDMA/VDMA ctrl_sysram_dst: %v %v",
                   #procedure, bus.sdma.ctrl_sysram_dst, bus.vdma.ctrl_sysram_dst)
        return
    }

    // at this moment sdma/vdma sources/dest are the same
    src: DMAOBJ
    dst: DMAOBJ
    if bus.sdma.ctrl_sysram_src {
        src,_   = c256_dma_set_objects(&bus.sdma)
    } else {
        src,_   = c256_dma_set_objects(&bus.vdma)
    }

    if bus.sdma.ctrl_sysram_dst {
        _,dst   = c256_dma_set_objects(&bus.sdma)
    } else {
        _,dst   = c256_dma_set_objects(&bus.vdma)
    }

    //src,dst   := c256_dma_set_objects(&bus.sdma)
    for (src.stop || dst.stop) == false {
        c256_dma_operation(mainbus, &src) 
        dst.val = src.val
        c256_dma_operation(mainbus, &dst) 
        //log.debugf("DMA %v to %v SRC %08x %08x DST %08x %08x VAL %02x",
        //           src.kind, dst.kind,
        //           src.addr, src.index,
        //           dst.addr, dst.index,
        //           src.val
        //)
    }

    if src.stop != dst.stop {
        bus.sdma.ctrl_status |= src.status   // TIMEOUT and SIZE errors not covered
        bus.sdma.ctrl_status |= dst.status
        log.errorf("%s invalid DMA, stop desync: src %v dst %v", #procedure, dst.stop, src.stop)
    }

    //delete(src)
    //delete(dst)
    log.debugf("%s DMA copy finished after %d bytes status %02x", #procedure, dst.count, dst.status)
    return
}





// no support for "SIZE" error
c256_vdma_transfer :: proc(mainbus: ^Bus) {
    bus        := &mainbus.model.(BUS_C256)

    // FILL ---------------------------------------------------------------
    if bus.vdma.ctrl_trf_fill {
        src,dst := c256_dma_set_objects(&bus.vdma)
        dst.val  = bus.vdma.byte_2_write

        for dst.stop == false {
            c256_dma_operation(mainbus, &dst) 
        }
        if bus.vdma.debug {
            log.debugf("%s DMA fill finished after %d bytes status %02x", #procedure, dst.count, dst.status)
        }
        return
    }

    // VRAM to VRAM -------------------------------------------------------
    if !bus.vdma.ctrl_sysram_src && !bus.vdma.ctrl_sysram_dst {
        src, dst  := c256_dma_set_objects(&bus.vdma)

        for (src.stop || dst.stop) == false {
            c256_dma_operation(mainbus, &src) 
            dst.val = src.val
            c256_dma_operation(mainbus, &dst) 
        }

        if src.stop != dst.stop {
            bus.vdma.ctrl_status |= src.status // TIMEOUT and SIZE errors not covered
            bus.vdma.ctrl_status |= dst.status
            log.errorf("%s invalid DMA, stop desync: src %v dst %v", #procedure, dst.stop, src.stop)
        }

        if bus.vdma.debug {
            log.debugf("%s DMA VRAM->VRAM finished after %d bytes status %02x", #procedure, dst.count, dst.status)
        }
        return
    }

    // SRAM to VRAM is initiated by SDMA -----------------------------------
    // VRAM to SRAM is initiated by SDMA too -------------------------------

}

c256_dma_read :: proc(mainbus: ^Bus, size: emu.Request_Size, addr: u32) -> (val: u32) {
    bus        := &mainbus.model.(BUS_C256)

    switch addr {
    case VDMA_CONTROL_REG :
        val |= 0x01 if bus.vdma.ctrl_enable     else 0
        val |= 0x02 if bus.vdma.ctrl_2d         else 0
        val |= 0x04 if bus.vdma.ctrl_trf_fill   else 0
        val |= 0x08 if bus.vdma.ctrl_int_enable else 0
        val |= 0x10 if bus.vdma.ctrl_sysram_src else 0
        val |= 0x20 if bus.vdma.ctrl_sysram_dst else 0

        val |= 0x80 if bus.vdma.ctrl_start      else 0


    case VDMA_STATUS_REG  : val = bus.vdma.ctrl_status

    case VDMA_SRC_ADDY_L  : val = emu.get_byte1(bus.vdma.src_addy)
    case VDMA_SRC_ADDY_M  : val = emu.get_byte2(bus.vdma.src_addy)   
    case VDMA_SRC_ADDY_H  : val = emu.get_byte3(bus.vdma.src_addy)   

    case VDMA_DST_ADDY_L  : val = emu.get_byte1(bus.vdma.dst_addy)   
    case VDMA_DST_ADDY_M  : val = emu.get_byte2(bus.vdma.dst_addy)   
    case VDMA_DST_ADDY_H  : val = emu.get_byte3(bus.vdma.dst_addy)   

    case VDMA_X_SIZE_L    : val = bus.vdma.x_size   if bus.vdma.ctrl_2d else bus.vdma.size    // XXX change to shared mem addr
    case VDMA_X_SIZE_H    : val = bus.vdma.x_size   if bus.vdma.ctrl_2d else bus.vdma.size       
    case VDMA_Y_SIZE_L    : val = bus.vdma.y_size   if bus.vdma.ctrl_2d else bus.vdma.size       
    case VDMA_Y_SIZE_H    : val = bus.vdma.y_size   if bus.vdma.ctrl_2d else 0

    case VDMA_SRC_STRIDE_L: val = emu.get_byte1(bus.vdma.src_stride)
    case VDMA_SRC_STRIDE_H: val = emu.get_byte2(bus.vdma.src_stride) 

    case VDMA_DST_STRIDE_L: val = emu.get_byte1(bus.vdma.dst_stride) 
    case VDMA_DST_STRIDE_H: val = emu.get_byte2(bus.vdma.dst_stride) 

    // ---------------------------------------------------------------------------------
    case SDMA_CTRL_REG0   :
        val |= 0x01 if bus.sdma.ctrl_enable     else 0
        val |= 0x02 if bus.sdma.ctrl_2d         else 0
        val |= 0x04 if bus.sdma.ctrl_trf_fill   else 0
        val |= 0x08 if bus.sdma.ctrl_int_enable else 0
        val |= 0x10 if bus.sdma.ctrl_sysram_src else 0
        val |= 0x20 if bus.sdma.ctrl_sysram_dst else 0

        val |= 0x80 if bus.sdma.ctrl_start      else 0


    case SDMA_STATUS_REG  : val = bus.sdma.ctrl_status

    case SDMA_SRC_ADDY_L  : val = bus.sdma.src_addy   
    case SDMA_SRC_ADDY_M  : val = bus.sdma.src_addy   
    case SDMA_SRC_ADDY_H  : val = bus.sdma.src_addy   

    case SDMA_DST_ADDY_L  : val = bus.sdma.dst_addy   
    case SDMA_DST_ADDY_M  : val = bus.sdma.dst_addy   
    case SDMA_DST_ADDY_H  : val = bus.sdma.dst_addy   

    case SDMA_X_SIZE_L    : val = bus.sdma.x_size   if bus.sdma.ctrl_2d else bus.sdma.size    // XXX change to shared mem addr
    case SDMA_X_SIZE_H    : val = bus.sdma.x_size   if bus.sdma.ctrl_2d else bus.sdma.size       
    case SDMA_Y_SIZE_L    : val = bus.sdma.y_size   if bus.sdma.ctrl_2d else bus.sdma.size       
    case SDMA_Y_SIZE_H    : val = bus.sdma.y_size   if bus.sdma.ctrl_2d else 0

    case SDMA_SRC_STRIDE_L: val = bus.sdma.src_stride 
    case SDMA_SRC_STRIDE_H: val = bus.sdma.src_stride 

    case SDMA_DST_STRIDE_L: val = bus.sdma.dst_stride 
    case SDMA_DST_STRIDE_H: val = bus.sdma.dst_stride 
    }

    return
}

c256_dma_write :: proc(mainbus: ^Bus, size: emu.Request_Size, addr, val: u32) {
    bus        := &mainbus.model.(BUS_C256)

    log.debugf("%s DMA write value %02x to addr %08x", #procedure, addr, val)
    switch addr {
    case VDMA_CONTROL_REG :
        bus.vdma.ctrl_enable     = val & 0x01 != 0
        bus.vdma.ctrl_2d         = val & 0x02 != 0
        bus.vdma.ctrl_trf_fill   = val & 0x04 != 0
        bus.vdma.ctrl_int_enable = val & 0x08 != 0
        bus.vdma.ctrl_sysram_src = val & 0x10 != 0
        bus.vdma.ctrl_sysram_dst = val & 0x20 != 0
        cmd_ctrl_start          := val & 0x80 != 0

        // disabling bus.vdma.== stopping vdma? dunno
        if !bus.vdma.ctrl_enable {
            bus.vdma.ctrl_start = false
            return
        }

        // initiate transfer only if change is 0 -> 1
        if !bus.vdma.ctrl_start & cmd_ctrl_start  {
            bus.vdma.ctrl_start = true
            c256_vdma_transfer(mainbus)
            mainbus.pic->trigger(.RESERVED_6)   // may generate spurious irqs
        } else {
            bus.vdma.ctrl_start = false
        }

    case VDMA_STATUS_REG  : bus.vdma.byte_2_write = val        // AKA: VDMA_BYTE_2_WRITE

    case VDMA_SRC_ADDY_L  : bus.vdma.src_addy   = assign_byte1(bus.vdma.src_addy,   val)
    case VDMA_SRC_ADDY_M  : bus.vdma.src_addy   = assign_byte2(bus.vdma.src_addy,   val)
    case VDMA_SRC_ADDY_H  : bus.vdma.src_addy   = assign_byte3(bus.vdma.src_addy,   val)

    case VDMA_DST_ADDY_L  : bus.vdma.dst_addy   = assign_byte1(bus.vdma.dst_addy,   val)
    case VDMA_DST_ADDY_M  : bus.vdma.dst_addy   = assign_byte2(bus.vdma.dst_addy,   val)
    case VDMA_DST_ADDY_H  : bus.vdma.dst_addy   = assign_byte3(bus.vdma.dst_addy,   val)

    case VDMA_X_SIZE_L    : bus.vdma.x_size     = assign_byte1(bus.vdma.x_size,     val)  // 2D VDMA_X_SIZE_L
                            bus.vdma.size       = assign_byte1(bus.vdma.size,       val)  // 1D VDMA_SIZE_L

    case VDMA_X_SIZE_H    : bus.vdma.x_size     = assign_byte2(bus.vdma.x_size,     val)  // 2D VDMA_X_SIZE_H
                            bus.vdma.size       = assign_byte2(bus.vdma.size,       val)  // 1D VDMA_SIZE_M

    case VDMA_Y_SIZE_L    : bus.vdma.y_size     = assign_byte1(bus.vdma.y_size,     val)  // 2D VDMA_Y_SIZE_L
                            bus.vdma.size       = assign_byte3(bus.vdma.size,       val)  // 1D VDMA_SIZE_H 

    case VDMA_Y_SIZE_H    : bus.vdma.y_size     = assign_byte2(bus.vdma.y_size,     val)

    case VDMA_SRC_STRIDE_L: bus.vdma.src_stride = assign_byte1(bus.vdma.src_stride, val)
    case VDMA_SRC_STRIDE_H: bus.vdma.src_stride = assign_byte2(bus.vdma.src_stride, val)

    case VDMA_DST_STRIDE_L: bus.vdma.dst_stride = assign_byte1(bus.vdma.dst_stride, val)
    case VDMA_DST_STRIDE_H: bus.vdma.dst_stride = assign_byte2(bus.vdma.dst_stride, val)

    // ---------------------------------------------------------------------------------
    case SDMA_CTRL_REG0   :
        bus.sdma.ctrl_enable     = val & 0x01 != 0
        bus.sdma.ctrl_2d         = val & 0x02 != 0
        bus.sdma.ctrl_trf_fill   = val & 0x04 != 0
        bus.sdma.ctrl_int_enable = val & 0x08 != 0
        bus.sdma.ctrl_sysram_src = val & 0x10 != 0
        bus.sdma.ctrl_sysram_dst = val & 0x20 != 0

        cmd_ctrl_start      := val & 0x80 != 0

        // disabling bus.sdma.== stopping sdma? dunno
        if !bus.sdma.ctrl_enable {
            bus.sdma.ctrl_start = false
            return
        }

        // initiate transfer only if change is 0 -> 1
        if !bus.sdma.ctrl_start & cmd_ctrl_start  {
            bus.sdma.ctrl_start = true
            c256_sdma_transfer(mainbus)
            mainbus.pic->trigger(.RESERVED_5)   // may generate spurious irqs
        } else {
            bus.sdma.ctrl_start = false
        }

    case SDMA_STATUS_REG  : bus.sdma.byte_2_write = val        // AKA: SDMA_BYTE_2_WRITE

    case SDMA_SRC_ADDY_L  : bus.sdma.src_addy   = assign_byte1(bus.sdma.src_addy,   val)
    case SDMA_SRC_ADDY_M  : bus.sdma.src_addy   = assign_byte2(bus.sdma.src_addy,   val)
    case SDMA_SRC_ADDY_H  : bus.sdma.src_addy   = assign_byte3(bus.sdma.src_addy,   val)

    case SDMA_DST_ADDY_L  : bus.sdma.dst_addy   = assign_byte1(bus.sdma.dst_addy,   val)
    case SDMA_DST_ADDY_M  : bus.sdma.dst_addy   = assign_byte2(bus.sdma.dst_addy,   val)
    case SDMA_DST_ADDY_H  : bus.sdma.dst_addy   = assign_byte3(bus.sdma.dst_addy,   val)

    case SDMA_X_SIZE_L    : bus.sdma.x_size     = assign_byte1(bus.sdma.x_size,     val)  // 2D SDMA_X_SIZE_L
                            bus.sdma.size       = assign_byte1(bus.sdma.size,       val)  // 1D SDMA_SIZE_L

    case SDMA_X_SIZE_H    : bus.sdma.x_size     = assign_byte2(bus.sdma.x_size,     val)  // 2D SDMA_X_SIZE_H
                            bus.sdma.size       = assign_byte2(bus.sdma.size,       val)  // 1D SDMA_SIZE_M

    case SDMA_Y_SIZE_L    : bus.sdma.y_size     = assign_byte1(bus.sdma.y_size,     val)  // 2D SDMA_Y_SIZE_L
                            bus.sdma.size       = assign_byte3(bus.sdma.size,       val)  // 1D SDMA_SIZE_H 

    case SDMA_Y_SIZE_H    : bus.sdma.y_size     = assign_byte2(bus.sdma.y_size,     val)

    case SDMA_SRC_STRIDE_L: bus.sdma.src_stride = assign_byte1(bus.sdma.src_stride, val)
    case SDMA_SRC_STRIDE_H: bus.sdma.src_stride = assign_byte2(bus.sdma.src_stride, val)

    case SDMA_DST_STRIDE_L: bus.sdma.dst_stride = assign_byte1(bus.sdma.dst_stride, val)
    case SDMA_DST_STRIDE_H: bus.sdma.dst_stride = assign_byte2(bus.sdma.dst_stride, val)

    }
}


