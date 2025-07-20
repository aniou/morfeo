
package morfeo

import "core:log"

import "vendor:sdl2"

import "emulator:platform"

sc_null            :: 0x00
sc_escape          :: 0x01
sc_1               :: 0x02
sc_2               :: 0x03
sc_3               :: 0x04
sc_4               :: 0x05
sc_5               :: 0x06
sc_6               :: 0x07
sc_7               :: 0x08
sc_8               :: 0x09
sc_9               :: 0x0A
sc_0               :: 0x0B
sc_minus           :: 0x0C
sc_equals          :: 0x0D
sc_backspace       :: 0x0E
sc_tab             :: 0x0F
sc_q               :: 0x10
sc_w               :: 0x11
sc_e               :: 0x12
sc_r               :: 0x13
sc_t               :: 0x14
sc_y               :: 0x15
sc_u               :: 0x16
sc_i               :: 0x17
sc_o               :: 0x18
sc_p               :: 0x19
sc_bracketLeft     :: 0x1A
sc_bracketRight    :: 0x1B
sc_enter           :: 0x1C
sc_controlLeft     :: 0x1D
sc_a               :: 0x1E
sc_s               :: 0x1F
sc_d               :: 0x20
sc_f               :: 0x21
sc_g               :: 0x22
sc_h               :: 0x23
sc_j               :: 0x24
sc_k               :: 0x25
sc_l               :: 0x26
sc_semicolon       :: 0x27
sc_apostrophe      :: 0x28
sc_grave           :: 0x29
sc_shiftLeft       :: 0x2A
sc_backslash       :: 0x2B
sc_z               :: 0x2C
sc_x               :: 0x2D
sc_c               :: 0x2E
sc_v               :: 0x2F
sc_b               :: 0x30
sc_n               :: 0x31
sc_m               :: 0x32
sc_comma           :: 0x33
sc_period          :: 0x34
sc_slash           :: 0x35
sc_shiftRight      :: 0x36
sc_numpad_multiply :: 0x37
sc_altLeft         :: 0x38
sc_space           :: 0x39
sc_capslock        :: 0x3A
sc_F1              :: 0x3B
sc_F2              :: 0x3C
sc_F3              :: 0x3D
sc_F4              :: 0x3E
sc_F5              :: 0x3F
sc_F6              :: 0x40
sc_F7              :: 0x41
sc_F8              :: 0x42
sc_F9              :: 0x43
sc_F10             :: 0x44
sc_F11             :: 0x57
sc_F12             :: 0x58
sc_up_arrow        :: 0x48 // also maps to num keypad 8
sc_left_arrow      :: 0x4B // also maps to num keypad 4
sc_right_arrow     :: 0x4D // also maps to num keypad 6
sc_down_arrow      :: 0x50 // also maps to num keypad 2


ps2_scancode :: proc(code: sdl2.Scancode) -> u8 {
    #partial switch code {
    case sdl2.SCANCODE_0:
        return sc_0
    case sdl2.SCANCODE_1,
         sdl2.SCANCODE_2,
         sdl2.SCANCODE_3,
         sdl2.SCANCODE_4,
         sdl2.SCANCODE_5,
         sdl2.SCANCODE_6,
         sdl2.SCANCODE_7,
         sdl2.SCANCODE_8,
         sdl2.SCANCODE_9:
        return u8(sc_1 + u8(code - sdl2.SCANCODE_1))
    case sdl2.SCANCODE_A:
        return sc_a
    case sdl2.SCANCODE_B:
        return sc_b
    case sdl2.SCANCODE_C:
        return sc_c
    case sdl2.SCANCODE_D:
        return sc_d
    case sdl2.SCANCODE_E:
        return sc_e
    case sdl2.SCANCODE_F:
        return sc_f
    case sdl2.SCANCODE_G:
        return sc_g
    case sdl2.SCANCODE_H:
        return sc_h
    case sdl2.SCANCODE_I:
        return sc_i
    case sdl2.SCANCODE_J:
        return sc_j
    case sdl2.SCANCODE_K:
        return sc_k
    case sdl2.SCANCODE_L:
        return sc_l
    case sdl2.SCANCODE_M:
        return sc_m
    case sdl2.SCANCODE_N:
        return sc_n
    case sdl2.SCANCODE_O:
        return sc_o
    case sdl2.SCANCODE_P:
        return sc_p
    case sdl2.SCANCODE_Q:
        return sc_q
    case sdl2.SCANCODE_R:
        return sc_r
    case sdl2.SCANCODE_S:
        return sc_s
    case sdl2.SCANCODE_T:
        return sc_t
    case sdl2.SCANCODE_U:
        return sc_u
    case sdl2.SCANCODE_V:
        return sc_v
    case sdl2.SCANCODE_W:
        return sc_w
    case sdl2.SCANCODE_X:
        return sc_x
    case sdl2.SCANCODE_Y:
        return sc_y
    case sdl2.SCANCODE_Z:
        return sc_z
    case sdl2.SCANCODE_RETURN:
        return sc_enter
    case sdl2.SCANCODE_DELETE, sdl2.SCANCODE_BACKSPACE:
        return sc_backspace
    case sdl2.SCANCODE_SPACE:
        return sc_space
    case sdl2.SCANCODE_COMMA:
        return sc_comma
    case sdl2.SCANCODE_PERIOD:
        return sc_period
    case sdl2.SCANCODE_SEMICOLON:
        return sc_semicolon
    case sdl2.SCANCODE_ESCAPE:
        return sc_escape
    case sdl2.SCANCODE_GRAVE:
        return sc_grave
    case sdl2.SCANCODE_APOSTROPHE:
        return sc_apostrophe
    case sdl2.SCANCODE_LEFTBRACKET:
        return sc_bracketLeft
    case sdl2.SCANCODE_RIGHTBRACKET:
        return sc_bracketRight
    case sdl2.SCANCODE_MINUS:
        return sc_minus
    case sdl2.SCANCODE_EQUALS:
        return sc_equals
    case sdl2.SCANCODE_TAB:
        return sc_tab
    case sdl2.SCANCODE_SLASH:
        return sc_slash
    case sdl2.SCANCODE_BACKSLASH:
        return sc_backslash
    case sdl2.SCANCODE_LSHIFT:
        return sc_shiftLeft
    case sdl2.SCANCODE_RSHIFT:
        return sc_shiftRight
    case sdl2.SCANCODE_LALT:
        return sc_altLeft
    case sdl2.SCANCODE_LCTRL:
        return sc_controlLeft
    case sdl2.SCANCODE_UP:
        return sc_up_arrow
    case sdl2.SCANCODE_DOWN:
        return sc_down_arrow
    case sdl2.SCANCODE_LEFT:
        return sc_left_arrow
    case sdl2.SCANCODE_RIGHT:
        return sc_right_arrow
    case sdl2.SCANCODE_F1,
         sdl2.SCANCODE_F2,
         sdl2.SCANCODE_F3,
         sdl2.SCANCODE_F4,
         sdl2.SCANCODE_F5,
         sdl2.SCANCODE_F6,
         sdl2.SCANCODE_F7,
         sdl2.SCANCODE_F8,
         sdl2.SCANCODE_F9,
         sdl2.SCANCODE_F10:
        return u8(sc_F1 + u8(code - sdl2.SCANCODE_F1))
    case sdl2.SCANCODE_F11,
        sdl2.SCANCODE_F12:
        return u8(sc_F11 + u8(code - sdl2.SCANCODE_F11))
    case:
        return sc_null
    }
}

send_key_to_ps2 :: proc(p: ^platform.Platform, code: sdl2.Scancode, event: sdl2.EventType) {
    ps2code := ps2_scancode(code)

    if ps2code == sc_null {
        log.warnf("gui  unknown scancode: %v", code)
        return
    } 

    if event == .KEYUP {
        ps2code += 0x80
    }

    append(&gui.ps2_queued_codes, ps2code)
    send_queued_key_to_ps2(p)
}


send_queued_key_to_ps2 :: proc(p: ^platform.Platform) {
    //if len(gui.ps2_queued_codes) == 0 {
    //    return
    //}

    if p.bus.ps20->send_key(gui.ps2_queued_codes[0]) {      // IRQ is triggered by ps2 module
        ordered_remove(&gui.ps2_queued_codes, 0)
    }
}



