package platform

import "core:os"
import "core:strings"
import "core:fmt"
import "core:log"
import "core:slice"

import "lib:hex"
import "lib:emu"

import "emulator:bus"
import "emulator:cpu"


/*
It is computed by summing the decoded byte values and extracting the LSB of the
sum (i.e., the data checksum), and then calculating the two's complement of the
LSB (e.g., by inverting its bits and adding one).  
*/
@(private)
checksum :: proc(bytes: []u8) -> u8 {
    sum    := 0

	for b in bytes {
		sum += int(b)
	}

    cksum := u8(sum & 0xFF) 
    cksum  = ~cksum
    cksum += 1

    return u8(cksum)
}

@(private)
get_extended_linear_address :: proc(data: []u8) -> (addr: u32, ok: bool) {
    if data[0] != 2 {
        log.errorf("bad data length field in extended linear address (should be 0x02)")
        return 0, false
    }

    if ! slice.simple_equal(data[1:3], []u8{0, 0}) {
        log.errorf("bad address field in extended linear address (should be 0x00)")
        return 0, false
    }

    addr =   (u32(data[4]) << 24 ) | (u32(data[5]) << 16 )

    return addr, true
}


read_intel_hex :: proc(bus: ^bus.Bus, cpu: ^cpu.CPU, filepath: string) {
    record_address : u32 // address (offset) of particular record (line)
    record_len     : u32 // bytes in single record (line)
    byte_count     : u32 // bytes in particular block (sum of records)
    base_address   : u32 // set by special record type (linear, block)
    initial_address: u32 // initial addres of base+first record (for logging)
    start_address  : u32 // where should PC go if record 0x05 is found

    data           : []byte       // array of bytes, converted do u8
    content        : []byte       // hex file content (raw bytes)
    finished       : bool = false // set by record 01
    in_segment     : bool = false // there is a segment procesing?
    ok             : bool         // general success indicator

	defer delete(content, context.allocator)

	content, ok = os.read_entire_file(filepath, context.allocator)
	if !ok {
        log.errorf("could not read file %s", filepath)
		return
	}

	it := string(content)
	loop: for line in strings.split_lines_iterator(&it) {
        if line[0] != ':' {
        	continue
        }

        data, ok  = hex.decode(line[1:])
        defer delete(data, context.allocator)
        if ! ok {
            log.errorf("cannot hex decode '%s'", line[1:])
            break loop
        }

        if len(data) < 5 {
            log.errorf("decoded data len less than 5 for line '%s'", line)
            break loop
        }
        
        last := len(data) - 1
        if data[last] != checksum(data[:last]) {
            log.errorf("checksum mismatch for '%s'", line)
            break loop
        }

        switch data[3] {
            case 0x00:
                record_len     = u32(data[0])
                record_address = (u32(data[1]) << 8) | (u32(data[2]))

                // is there a new data block ahead?
                if initial_address + byte_count != base_address + record_address {
                    if in_segment {
                        log.infof("segment %08x bytes %d", initial_address, byte_count)
                    }

                    initial_address = base_address + record_address
                    byte_count      = 0
                }

                // just write to mem
                for val, index in data[4:4+record_len] {
                   // write base_address + record_address + index, b
                   // write initial_address + byte_count
                   bus->write(.bits_8, initial_address + byte_count + u32(index), u32(val))
                }
                byte_count   += record_len
                in_segment    = true
                
            case 0x01:
                finished = true
                if in_segment {
                    log.infof("segment %08x bytes %d", initial_address, byte_count)
                }
                break loop

            case 0x04: 
                base_address = get_extended_linear_address(data) or_break loop

            case 0x05:
                start_address =   u32(data[4]) << 24 \
                                | u32(data[5]) << 16 \
                                | u32(data[6]) <<  8 \
                                | u32(data[7])

                if in_segment {
                    log.infof("segment %08x bytes %d", initial_address, byte_count)
                    in_segment = false
                }
                log.infof("set PC to address %08x", start_address)
                cpu->setpc(start_address)

            case:
                log.errorf("hex read aborted, unknown line: %s", line)
                break loop
        }
	}
    if ! finished {
        log.error("File was not fully parsed!")
    }
    
}


/*
main :: proc() {
    logger_options := log.Options{.Terminal_Color, .Level};
    context.logger = log.create_console_logger(opt = logger_options)

    read_file_by_lines_in_whole("/home/aniou/c256/morfe/data/foenixmcp.hex")
    read_file_by_lines_in_whole("/home/aniou/c256/morfe/data/foenix-st_8x8.hex")

    log.destroy_console_logger(context.logger)
}
*/
