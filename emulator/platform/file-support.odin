
package platform

import "core:encoding/hex"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"

import "emulator:cpu"
import "emulator:bus"

// Computes Motorola S-Record checksum by summing the decoded byte values,
// extracting the LSB of the sum, and calculating the ONES' complement of 
// the LSB

// Warning: Intel HEX records checksum uses the same method, but finally it
// relies on TWOS' complement.
srec_checksum :: proc(bytes: []u32) -> u32 {
    sum : u32 = 0

    for b in bytes {
    	sum += b
    }

    cksum := sum  & 0xFF
    cksum  = 0xFF - cksum
    cksum &= 0xFF

    return cksum
}

// Computes Intel HEX line checksum by summing the decoded byte values,
// extracting the LSB of the sum, and calculating the TWOS' complement 
// of the LSB
//
// Warning: Motorola S-REC checksum uses the same method, but finally it
// relies on ONES' complement. It is a subtle diference, beware!
intel_hex_checksum :: proc(bytes: []u32) -> u32 {
    sum : u32 = 0

	for b in bytes {
		sum += b
	}

    cksum := sum & 0xFF
    cksum  = ~cksum
    cksum += 1
    cksum &= 0xFF

    return cksum
}

// copy from core:decorer/hex and modified to u32
hex_decode :: proc(src: string) -> (dst: []u32, ok: bool) #no_bounds_check {
	if len(src) % 2 == 1 {
    	return
    }

	dst = make([]u32, len(src) / 2)
	for i, j := 0, 1; j < len(src); j += 2 {
		p := src[j-1]
		q := src[j  ]

		a := hex_digit(p) or_return
		b := hex_digit(q) or_return

		dst[i] = (a << 4) | b
		i += 1
	}

	return dst, true
}

// copied from core:decorer/hex without modification
hex_digit :: proc(char: byte) -> (u32, bool) {
        switch char {
        case '0' ..= '9': return u32(char - '0'     ), true
        case 'a' ..= 'f': return u32(char - 'a' + 10), true
        case 'A' ..= 'F': return u32(char - 'A' + 10), true
        case:             return 0, false
        }
}


// S 	Type 	Byte Count 	Address 	Data 	Checksum
// 1       1             2      4-8        *           2   characters
//
// byte count = address + data + checksum in bytes (2char pairs), not less than 3
//
read_srec :: proc(p: ^Platform, filepath: string) -> (ok: bool) {
    address        : u32    // actual adress, read from s-record
    count          : u32    // number of S1/S2/S3 records
    data           : []u32  // s-record in the form of integer values
    content        : []byte // content of file to parse
    finished       : bool = false // set by record 01

    defer delete(content, context.allocator)

    content, ok = os.read_entire_file(filepath, context.allocator)
    if ! ok {
        log.errorf("could not read file %s", filepath)
        return
    }
    it := string(content)
    loop: for line in strings.split_lines_iterator(&it) {
        finished = false

        if line[0] != 'S' {
            log.errorf("not a srec line '%s'", line)
            ok = false
            break loop
        }

        // every line starts with code S0 - S9, and single 0-9 
        // is problematic for decode: so we need to prepend "0"
		tmpstr   := strings.concatenate({"0", line[1:]})
        data, ok  = hex_decode(tmpstr)
        delete(tmpstr)
        defer delete(data, context.allocator)
        if ! ok {
            log.errorf("cannot hex decode '%s'", line)
            break loop
        }

        if len(data) < 4 {
            log.errorf("decoded data len less than 4 bytes for line '%s'", line)
            ok = false
            break loop
        }

        type := data[0]
        if type > 9 {
            log.errorf("decoded data type (%d) is not in 0..=9 for line '%s'", type, line)
            ok = false
            break loop
        }

        if int(data[1]) != len(data[2:]) {
            log.errorf("data length: %d does not match record length: %d line '%s'", data[1], len(data[2:]), line)
            ok = false
            break loop
    
        }

        last := len(data) - 1
        if data[last] != srec_checksum(data[1:last]) {
            log.errorf("checksum mismatch for '%s'", line)
            ok = false
            break loop
        }

        switch data[0] {
        case 0x00:
            msg := make([dynamic]u8, 0)
            for b in data[4:last] do append(&msg, u8(b))
            log.infof("field S0: %s", msg)
            delete(msg)
        case 0x01:
            address  = data[2] << 8  | data[3]
            count   += 1
            for val, index in data[4:last] {
                p.bus->write(.bits_8, address + u32(index), val)
            }
        case 0x02:
            address  = data[2] << 16 | data[3] << 8  | data[4]
            count   += 1
            for val, index in data[4:last] {
                p.bus->write(.bits_8, address + u32(index), val)
            }
        case 0x03:
            address  = data[2] << 24 | data[3] << 16 | data[4] << 8 | data[5]
            count   += 1
            for val, index in data[4:last] {
                p.bus->write(.bits_8, address + u32(index), val)
            }
        case 0x04:
            log.warnf("record type S4 is not supported, line '%s'", line)
        case 0x05:
            finished = true
            val := data[2] <<  8  | data[3]
            log.warnf("record type S5 is not enforced, expected %d has %d", val, count)
        case 0x06:
            finished = true
            val := data[2] << 16  | data[3] << 8 | data[4]
            log.warnf("record type S6 is not enforced, expected %d has %d", val, count)
        case 0x07:
            finished = true
            address  = data[2] << 24 | data[3] << 16 | data[4] << 8 | data[5]
            log.warnf("record type S7 setpc to %08x", address)
            p.cpu->setpc(address)
        case 0x08:
            finished = true
            address  = data[2] << 16 | data[3] << 8  | data[4]
            log.warnf("record type S8 setpc to %08x", address)
            p.cpu->setpc(address)
        case 0x09:
            finished = true
            address  = data[2] <<  8 | data[3]
            log.warnf("record type S9 setpc to %08x", address)
            p.cpu->setpc(address)
        case:
            log.errorf("hex read aborted, unknown line: %s", line)
            ok = false
            break loop
        }

    } // end loop

    if ! finished {
        log.error("File was not fully parsed!")
        ok = false
    }

    return
}


get_extended_linear_address :: proc(data: []u32) -> (addr: u32, ok: bool) {
    if data[0] != 2 {
        log.errorf("bad data length field in extended linear address (should be 0x02)")
        return 0, false
    }

    if ! slice.simple_equal(data[1:3], []u32{0, 0}) {
        log.errorf("bad address field in extended linear address (should be 0x00)")
        return 0, false
    }

    addr =   data[4] << 24 | data[5] << 16 

    return addr, true
}

// move_segment - a base value used to mimic FoenixIDE behaviour, when
// a hex file with data segments located at $18:0000 or $38:0000 are
// mirrored to bank $00
read_intel_hex :: proc(p: ^Platform, filepath: string, move_segment: u32 = 0) -> (ok: bool) {
    record_address : u32 // address (offset) of particular record (line)
    record_len     : u32 // bytes in single record (line)
    byte_count     : u32 // bytes in particular block (sum of records)
    base_address   : u32 // set by special record type (linear, block)
    initial_address: u32 // initial addres of base+first record (for logging)
    start_address  : u32 // where should PC go if record 0x05 is found

    data           : []u32        // array of bytes, converted do u8
    content        : []byte       // hex file content (raw bytes)
    finished       : bool = false // set by record 01
    in_segment     : bool = false // there is a segment procesing?
    mirrored       : bool = false // is segment re-routed from $18: or $38: to $00:

	defer delete(content, context.allocator)

	content, ok = os.read_entire_file(filepath, context.allocator)
	if !ok {
        log.errorf("could not read file %s", filepath)
		return
	}

	it := string(content)
	loop: for line in strings.split_lines_iterator(&it) {
        finished = false
        if line[0] != ':' {
        	continue
        }

        data, ok  = hex_decode(line[1:])
        defer delete(data, context.allocator)
        if ! ok {
            log.errorf("cannot hex decode '%s'", line[1:])
            break loop
        }

        if len(data) < 5 {
            log.errorf("decoded data len less than 5 for line '%s'", line)
            ok = false
            break loop
        }
        
        last := len(data) - 1
        if data[last] != intel_hex_checksum(data[:last]) {
            log.errorf("checksum mismatch for '%s'", line)
            ok = false
            break loop
        }

        switch data[3] {
            case 0x00:
                record_len     = data[0]
                record_address = data[1] << 8 | data[2]

                // is there a new data block ahead?
                if initial_address + byte_count != base_address + record_address {
                    if in_segment {
                        if mirrored {
                            log.infof("code 00 segment %08x bytes %d mirrored to %08x", 
                                       initial_address, byte_count, initial_address - move_segment)
                        } else {
                            log.infof("code 00 segment %08x bytes %d", initial_address, byte_count)
                        }
                    }

                    initial_address = base_address + record_address
                    byte_count      = 0
                    mirrored        = (initial_address >= move_segment) && (initial_address <= move_segment + 0xffff)
                }

                // just write to mem
                for val, index in data[4:4+record_len] {
                    if mirrored {
                        p.bus->write(.bits_8, initial_address + byte_count + u32(index) - move_segment, val)
                    }
                    p.bus->write(.bits_8, initial_address + byte_count + u32(index), val)
                }
                byte_count   += record_len
                in_segment    = true
                
            case 0x01:
                finished = true
                //break loop

            case 0x04: 
                base_address = get_extended_linear_address(data) or_break loop

            case 0x05:
                start_address =   data[4] << 24 \
                                | data[5] << 16 \
                                | data[6] <<  8 \
                                | data[7]

                if in_segment {
                    log.infof("code 05 segment %08x bytes %d", initial_address, byte_count)
                    in_segment = false
                }
                log.infof("set PC to address %08x", start_address)
                p.cpu->setpc(start_address)

            case:
                log.errorf("hex read aborted, unknown line: %s", line)
                ok = false
                break loop
        }
	}
    if ! finished {
        log.error("File was not fully parsed!")
        ok = false
    }
    if in_segment {
        log.infof("code 01 segment %08x bytes %d", initial_address, byte_count)
    }
    return   
}

read_raw_binary :: proc(p: ^Platform, filepath: string, position: u32 = 0) -> (ok: bool) {
    data, status := os.read_entire_file_from_filename(filepath)
    if !status {
        log.errorf("read file %s failed: %s", filepath, os.error_string)
        return false
    }
    index : u32 = 0
    for value in data {
        p.bus->write(.bits_8, position + index, u32(value))
        index += 1
    }
    log.infof("file %s %d bytes read at position %d", filepath, index, position)
    return
}


File_Type :: enum {
    INTEL,
    SREC,
    BIN
}

// general procedure for reading/writing hex files
read_file :: proc(p: ^Platform, filepath: string, move_segment: u32 = 0) -> (ok: bool) {
	filetype : File_Type

    switch {
    case strings.has_suffix(filepath, ".hex" ): filetype = .INTEL
    case strings.has_suffix(filepath, ".s68" ), 
         strings.has_suffix(filepath, ".s19" ),
         strings.has_suffix(filepath, ".s28" ), 
         strings.has_suffix(filepath, ".s37" ), 
         strings.has_suffix(filepath, ".srec"): filetype = .SREC
    case strings.has_suffix(filepath, ".bin" ), 
         strings.has_suffix(filepath, ".rom" ): filetype = .BIN
	case:
		log.errorf("read_file: unknown filetype %s", filepath)
		ok = false
		return
    }

    switch filetype {
    case .INTEL:
        log.infof("read_file %s as Intel hex", filepath)
        ok = read_intel_hex(p, filepath, move_segment)
    case .SREC:
        log.infof("read_file %s as Motorola S-record", filepath)
        ok = read_srec(p, filepath)
    case .BIN:
        log.infof("read_file %s as raw binary at position %d", filepath, move_segment)
        ok = read_raw_binary(p, filepath, move_segment)
    }

    log.infof("read_file %s: finish, ok: %v", filepath, ok)
    return
}

/*
main :: proc() {
	// https://gist.github.com/karl-zylinski/4ccf438337123e7c8994df3b03604e33
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

    logger_options := log.Options{.Level};
    context.logger  = log.create_console_logger(opt = logger_options) 
    read_srec("fuzix.s68")
    read_intel_hex("foenixmcp-a2560x.hex")
	log.destroy_console_logger(context.logger)
}
*/
