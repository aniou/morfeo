
package morfeo

import "core:log"
import "vendor:sdl2"
import "lib:emu"
import "emulator:platform"

scan_to_key : [sdl2.NUM_SCANCODES]emu.KEY = {
    sdl2.SCANCODE_UNKNOWN      = .key_none,
    sdl2.SCANCODE_A            = .key_a,
    sdl2.SCANCODE_B            = .key_b,
    sdl2.SCANCODE_C            = .key_c,
    sdl2.SCANCODE_D            = .key_d,
    sdl2.SCANCODE_E            = .key_e,
    sdl2.SCANCODE_F            = .key_f,
    sdl2.SCANCODE_G            = .key_g,
    sdl2.SCANCODE_H            = .key_h,
    sdl2.SCANCODE_I            = .key_i,
    sdl2.SCANCODE_J            = .key_j,
    sdl2.SCANCODE_K            = .key_k,
    sdl2.SCANCODE_L            = .key_l,
    sdl2.SCANCODE_M            = .key_m,
    sdl2.SCANCODE_N            = .key_n,
    sdl2.SCANCODE_O            = .key_o,
    sdl2.SCANCODE_P            = .key_p,
    sdl2.SCANCODE_Q            = .key_q,
    sdl2.SCANCODE_R            = .key_r,
    sdl2.SCANCODE_S            = .key_s,
    sdl2.SCANCODE_T            = .key_t,
    sdl2.SCANCODE_U            = .key_u,
    sdl2.SCANCODE_V            = .key_v,
    sdl2.SCANCODE_W            = .key_w,
    sdl2.SCANCODE_X            = .key_x,
    sdl2.SCANCODE_Y            = .key_y,
    sdl2.SCANCODE_Z            = .key_z,
    sdl2.SCANCODE_1            = .key_1,
    sdl2.SCANCODE_2            = .key_2,
    sdl2.SCANCODE_3            = .key_3,
    sdl2.SCANCODE_4            = .key_4,
    sdl2.SCANCODE_5            = .key_5,
    sdl2.SCANCODE_6            = .key_6,
    sdl2.SCANCODE_7            = .key_7,
    sdl2.SCANCODE_8            = .key_8,
    sdl2.SCANCODE_9            = .key_9,
    sdl2.SCANCODE_0            = .key_0,
    sdl2.SCANCODE_GRAVE        = .key_grave,
    sdl2.SCANCODE_MINUS        = .key_minus,
    sdl2.SCANCODE_EQUALS       = .key_equals,
    sdl2.SCANCODE_BACKSLASH    = .key_backslash,
    sdl2.SCANCODE_BACKSPACE    = .key_backspace,
    sdl2.SCANCODE_SPACE        = .key_space,
    sdl2.SCANCODE_TAB          = .key_tab,
    sdl2.SCANCODE_CAPSLOCK     = .key_capslock,
    sdl2.SCANCODE_LSHIFT       = .key_shift_left,
    sdl2.SCANCODE_LCTRL        = .key_control_left,
    sdl2.SCANCODE_LGUI         = .key_gui_left,
    sdl2.SCANCODE_LALT         = .key_alt_left,
    sdl2.SCANCODE_RSHIFT       = .key_shift_right,
    sdl2.SCANCODE_RCTRL        = .key_control_right,
    sdl2.SCANCODE_RGUI         = .key_gui_right,
    sdl2.SCANCODE_RALT         = .key_alt_right,
    sdl2.SCANCODE_APPLICATION  = .key_apps,
    sdl2.SCANCODE_RETURN       = .key_enter,
    sdl2.SCANCODE_ESCAPE       = .key_esc,
    sdl2.SCANCODE_F1           = .key_f1,
    sdl2.SCANCODE_F2           = .key_f2,
    sdl2.SCANCODE_F3           = .key_f3,
    sdl2.SCANCODE_F4           = .key_f4,
    sdl2.SCANCODE_F5           = .key_f5,
    sdl2.SCANCODE_F6           = .key_f6,
    sdl2.SCANCODE_F7           = .key_f7,
    sdl2.SCANCODE_F8           = .key_f8,
    sdl2.SCANCODE_F9           = .key_f9,
    sdl2.SCANCODE_F10          = .key_f10,
    sdl2.SCANCODE_F11          = .key_f11,
    sdl2.SCANCODE_F12          = .key_f12,
    sdl2.SCANCODE_PRINTSCREEN  = .key_printscrn,
    sdl2.SCANCODE_SCROLLLOCK   = .key_scroll_lock,
    sdl2.SCANCODE_PAUSE        = .key_pause,
    sdl2.SCANCODE_LEFTBRACKET  = .key_bracket_left,
    sdl2.SCANCODE_INSERT       = .key_insert,
    sdl2.SCANCODE_HOME         = .key_home,
    sdl2.SCANCODE_PAGEUP       = .key_page_up,
    sdl2.SCANCODE_DELETE       = .key_delete,
    sdl2.SCANCODE_END          = .key_end,
    sdl2.SCANCODE_PAGEDOWN     = .key_page_down,
    sdl2.SCANCODE_UP           = .key_arrow_up,
    sdl2.SCANCODE_LEFT         = .key_arrow_left,
    sdl2.SCANCODE_DOWN         = .key_arrow_down,
    sdl2.SCANCODE_RIGHT        = .key_arrow_right,
    sdl2.SCANCODE_KP_DIVIDE    = .key_kp_slash,
    sdl2.SCANCODE_KP_MULTIPLY  = .key_kp_asterisk,
    sdl2.SCANCODE_KP_MINUS     = .key_kp_minus,
    sdl2.SCANCODE_KP_PLUS      = .key_kp_plus,
    sdl2.SCANCODE_KP_ENTER     = .key_kp_enter,
    sdl2.SCANCODE_KP_PERIOD    = .key_kp_dot,
    sdl2.SCANCODE_KP_0         = .key_kp_0,
    sdl2.SCANCODE_KP_1         = .key_kp_1,
    sdl2.SCANCODE_KP_2         = .key_kp_2,
    sdl2.SCANCODE_KP_3         = .key_kp_3,
    sdl2.SCANCODE_KP_4         = .key_kp_4,
    sdl2.SCANCODE_KP_5         = .key_kp_5,
    sdl2.SCANCODE_KP_6         = .key_kp_6,
    sdl2.SCANCODE_KP_7         = .key_kp_7,
    sdl2.SCANCODE_KP_8         = .key_kp_8,
    sdl2.SCANCODE_KP_9         = .key_kp_9,
    sdl2.SCANCODE_RIGHTBRACKET = .key_bracket_right,
    sdl2.SCANCODE_SEMICOLON    = .key_semicolon,
    sdl2.SCANCODE_APOSTROPHE   = .key_apostrophe,
    sdl2.SCANCODE_COMMA        = .key_comma,
    sdl2.SCANCODE_PERIOD       = .key_period,
    sdl2.SCANCODE_SLASH        = .key_slash,
    sdl2.SCANCODE_AUDIONEXT    = .key_track_next,
    sdl2.SCANCODE_AUDIOPREV    = .key_track_prev,
    sdl2.SCANCODE_AUDIOSTOP    = .key_stop,
    sdl2.SCANCODE_AUDIOPLAY    = .key_play,
    sdl2.SCANCODE_AUDIOMUTE    = .key_mute,
    sdl2.SCANCODE_VOLUMEUP     = .key_volume_up,
    sdl2.SCANCODE_VOLUMEDOWN   = .key_volume_down,
    sdl2.SCANCODE_MEDIASELECT  = .key_media,
    sdl2.SCANCODE_MAIL         = .key_mail,
    sdl2.SCANCODE_CALCULATOR   = .key_calculator,
    sdl2.SCANCODE_COMPUTER     = .key_computer,
    sdl2.SCANCODE_AC_SEARCH    = .key_www_search,
    sdl2.SCANCODE_AC_HOME      = .key_www_home,
    sdl2.SCANCODE_AC_BACK      = .key_www_back,
    sdl2.SCANCODE_AC_FORWARD   = .key_www_forward,
    sdl2.SCANCODE_AC_STOP      = .key_www_stop,
    sdl2.SCANCODE_AC_REFRESH   = .key_www_refresh,
    sdl2.SCANCODE_AC_BOOKMARKS = .key_www_fav,
}

/*
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
    if p.bus.ps20->send_key(gui.ps2_queued_codes[0]) {      // IRQ is triggered by ps2 module
        ordered_remove(&gui.ps2_queued_codes, 0)
    }
}
*/
