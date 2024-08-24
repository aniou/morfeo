
// cycle tables, used to 

package cpu

// base cycles, reduced according to following tables
//
// note: BRK (00) has 7 cycles on 65c02 anyway, but code
//       is shared between 65c816 when it is a 8-e cycles,
//       thus 8 was set in following table to limit
//       special cases in program
//
@(private)
cycles_w65c02s := [256]u32 {
 // 0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f    
    8, 6, 2, 1, 5, 3, 5, 5, 3, 2, 2, 1, 6, 4, 6, 5, // 0
    2, 5, 5, 1, 5, 4, 6, 5, 2, 4, 2, 1, 6, 4, 6, 5, // 1
    6, 6, 2, 1, 3, 3, 5, 5, 4, 2, 2, 1, 4, 4, 6, 5, // 2
    2, 5, 5, 1, 4, 4, 6, 5, 2, 4, 2, 1, 4, 4, 6, 5, // 3
    6, 6, 2, 1, 3, 3, 5, 5, 3, 2, 2, 1, 3, 4, 6, 5, // 4
    2, 5, 5, 1, 4, 4, 6, 5, 2, 4, 3, 1, 8, 4, 6, 5, // 5
    6, 6, 2, 1, 3, 3, 5, 5, 4, 2, 2, 1, 6, 4, 6, 5, // 6
    2, 5, 5, 1, 4, 4, 6, 5, 2, 4, 4, 1, 6, 4, 6, 5, // 7
    3, 6, 2, 1, 3, 3, 3, 5, 2, 2, 2, 1, 4, 4, 4, 5, // 8
    2, 6, 5, 1, 4, 4, 4, 5, 2, 5, 2, 1, 4, 5, 5, 5, // 9
    2, 6, 2, 1, 3, 3, 3, 5, 2, 2, 2, 1, 4, 4, 4, 5, // a
    2, 5, 5, 1, 4, 4, 4, 5, 2, 4, 2, 1, 4, 4, 4, 5, // b
    2, 6, 2, 1, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 5, // c
    2, 5, 5, 1, 4, 4, 6, 5, 2, 4, 3, 3, 4, 4, 7, 5, // d
    2, 6, 2, 1, 3, 3, 5, 5, 2, 2, 2, 1, 4, 4, 6, 5, // e
    2, 5, 5, 1, 4, 4, 6, 5, 2, 4, 4, 1, 4, 4, 7, 5, // f
 // 0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f    
}

// cycle increase in Decimal mode
@(private)
inc_flag_d_w65c02s := [256]u32 {
 // 0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f    
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 0 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 1
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 2
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 3
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 4
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 5
    0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, // 6
    0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, // 7
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 8
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 9
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // a
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // b
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // c
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // d
    0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, // e
    0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, // f
 // 0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f    
}

// cycle increase when px (page crossing) occured
@(private)
inc_px_w65c02s := [256]u32 {
 // 0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f    
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 0 
    0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, // 1 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 2 
    0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, // 3 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 4 
    0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, // 5 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 6 
    0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, // 7 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 8 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 9 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // a 
    0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, // b 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // c 
    0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, // d 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // e 
    0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, // f 
 // 0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f    
}

CPU_W65C06_debug :: struct {
    opcode: CPU_65xxx_opcode,
    bytes:  int,
    mode:   CPU_65xxx_mode,
}

CPU_W65C06_opcodes : [256]CPU_W65C06_debug = {
    {  .BRK, 1, .PC_Relative          }, // 00
    {  .ORA, 2, .ZP_X_Indirect        }, // 01
    {  .ILL, 2, .Illegal              }, // 02
    {  .ILL, 1, .Illegal              }, // 03
    {  .TSB, 2, .ZP                   }, // 04
    {  .ORA, 2, .ZP                   }, // 05
    {  .ASL, 2, .ZP                   }, // 06
    { .RMB0, 2, .ZP                   }, // 07
    {  .PHP, 1, .Implied              }, // 08
    {  .ORA, 2, .Immediate            }, // 09
    {  .ASL, 1, .Accumulator          }, // 0a
    {  .ILL, 1, .Illegal              }, // 0b
    {  .TSB, 3, .Absolute             }, // 0c
    {  .ORA, 3, .Absolute             }, // 0d
    {  .ASL, 3, .Absolute             }, // 0e
    { .BBR0, 3, .ZP_and_Relative      }, // 0f
    {  .BPL, 2, .PC_Relative          }, // 10
    {  .ORA, 2, .ZP_Indirect_Y        }, // 11
    {  .ORA, 2, .ZP_Indirect          }, // 12
    {  .ILL, 1, .Illegal              }, // 13
    {  .TRB, 2, .ZP                   }, // 14
    {  .ORA, 2, .ZP_X                 }, // 15
    {  .ASL, 2, .ZP_X                 }, // 16
    { .RMB1, 2, .ZP                   }, // 17
    {  .CLC, 1, .Implied              }, // 18
    {  .ORA, 3, .Absolute_Y           }, // 19
    {  .INC, 1, .Implied              }, // 1a
    {  .ILL, 1, .Illegal              }, // 1b
    {  .TRB, 3, .Absolute             }, // 1c
    {  .ORA, 3, .Absolute_X           }, // 1d
    {  .ASL, 3, .Absolute_X           }, // 1e
    { .BBR1, 3, .ZP_and_Relative      }, // 1f
    {  .JSR, 3, .Absolute             }, // 20
    {  .AND, 2, .ZP_X_Indirect        }, // 21
    {  .ILL, 2, .Illegal              }, // 22
    {  .ILL, 1, .Illegal              }, // 23
    {  .BIT, 2, .ZP                   }, // 24
    {  .AND, 2, .ZP                   }, // 25
    {  .ROL, 2, .ZP                   }, // 26
    { .RMB2, 2, .ZP                   }, // 27
    {  .PLP, 1, .Implied              }, // 28
    {  .AND, 2, .Immediate            }, // 29
    {  .ROL, 1, .Accumulator          }, // 2a
    {  .ILL, 1, .Illegal              }, // 2b
    {  .BIT, 3, .Absolute             }, // 2c
    {  .AND, 3, .Absolute             }, // 2d
    {  .ROL, 3, .Absolute             }, // 2e
    { .BBR2, 3, .ZP_and_Relative      }, // 2f
    {  .BMI, 2, .PC_Relative          }, // 30
    {  .AND, 2, .ZP_Indirect_Y        }, // 31
    {  .AND, 2, .ZP_Indirect          }, // 32
    {  .ILL, 1, .Illegal              }, // 33
    {  .BIT, 2, .ZP_X                 }, // 34
    {  .AND, 2, .ZP_X                 }, // 35
    {  .ROL, 2, .ZP_X                 }, // 36
    { .RMB3, 2, .ZP                   }, // 37
    {  .SEC, 1, .Implied              }, // 38
    {  .AND, 3, .Absolute_Y           }, // 39
    {  .DEC, 1, .Implied              }, // 3a
    {  .ILL, 1, .Illegal              }, // 3b
    {  .BIT, 3, .Absolute_X           }, // 3c
    {  .AND, 3, .Absolute_X           }, // 3d
    {  .ROL, 3, .Absolute_X           }, // 3e
    { .BBR3, 3, .ZP_and_Relative      }, // 3f
    {  .RTI, 1, .Implied              }, // 40
    {  .EOR, 2, .ZP_X_Indirect        }, // 41
    {  .ILL, 2, .Illegal              }, // 42
    {  .ILL, 1, .Illegal              }, // 43
    {  .ILL, 2, .Illegal              }, // 44
    {  .EOR, 2, .ZP                   }, // 45
    {  .LSR, 2, .ZP                   }, // 46
    { .RMB4, 2, .ZP                   }, // 47
    {  .PHA, 1, .Implied              }, // 48
    {  .EOR, 2, .Immediate            }, // 49
    {  .LSR, 1, .Accumulator          }, // 4a
    {  .ILL, 1, .Illegal              }, // 4b
    {  .JMP, 3, .Absolute             }, // 4c
    {  .EOR, 3, .Absolute             }, // 4d
    {  .LSR, 3, .Absolute             }, // 4e
    { .BBR4, 3, .ZP_and_Relative      }, // 4f
    {  .BVC, 2, .PC_Relative          }, // 50
    {  .EOR, 2, .ZP_Indirect_Y        }, // 51
    {  .EOR, 2, .ZP_Indirect          }, // 52
    {  .ILL, 1, .Illegal              }, // 53
    {  .ILL, 2, .Illegal              }, // 54
    {  .EOR, 2, .ZP_X                 }, // 55
    {  .LSR, 2, .ZP_X                 }, // 56
    { .RMB5, 2, .ZP                   }, // 57
    {  .CLI, 1, .Implied              }, // 58
    {  .EOR, 3, .Absolute_Y           }, // 59
    {  .PHY, 1, .Implied              }, // 5a
    {  .ILL, 1, .Illegal              }, // 5b
    {  .ILL, 3, .Illegal              }, // 5c
    {  .EOR, 3, .Absolute_X           }, // 5d
    {  .LSR, 3, .Absolute_X           }, // 5e
    { .BBR5, 3, .ZP_and_Relative      }, // 5f
    {  .RTS, 1, .Implied              }, // 60
    {  .ADC, 2, .ZP_X_Indirect        }, // 61
    {  .ILL, 2, .Illegal              }, // 62
    {  .ILL, 1, .Illegal              }, // 63
    {  .STZ, 2, .ZP                   }, // 64
    {  .ADC, 2, .ZP                   }, // 65
    {  .ROR, 2, .ZP                   }, // 66
    { .RMB6, 2, .ZP                   }, // 67
    {  .PLA, 1, .Implied              }, // 68
    {  .ADC, 2, .Immediate            }, // 69
    {  .ROR, 1, .Accumulator          }, // 6a
    {  .ILL, 1, .Illegal              }, // 6b
    {  .JMP, 3, .Absolute_Indirect    }, // 6c
    {  .ADC, 3, .Absolute             }, // 6d
    {  .ROR, 3, .Absolute             }, // 6e
    { .BBR6, 3, .ZP_and_Relative      }, // 6f
    {  .BVS, 2, .PC_Relative          }, // 70
    {  .ADC, 2, .ZP_Indirect_Y        }, // 71
    {  .ADC, 2, .ZP_Indirect          }, // 72
    {  .ILL, 1, .Illegal              }, // 73
    {  .STZ, 2, .ZP_X                 }, // 74
    {  .ADC, 2, .ZP_X                 }, // 75
    {  .ROR, 2, .ZP_X                 }, // 76
    { .RMB7, 2, .ZP                   }, // 77
    {  .SEI, 1, .Implied              }, // 78
    {  .ADC, 3, .Absolute_Y           }, // 79
    {  .PLY, 1, .Implied              }, // 7a
    {  .ILL, 1, .Illegal              }, // 7b
    {  .JMP, 3, .Absolute_X_Indirect  }, // 7c
    {  .ADC, 3, .Absolute_X           }, // 7d
    {  .ROR, 3, .Absolute_X           }, // 7e
    { .BBR7, 3, .ZP_and_Relative      }, // 7f
    {  .BRA, 2, .Implied              }, // 80
    {  .STA, 2, .ZP_X_Indirect        }, // 81
    {  .ILL, 2, .Illegal              }, // 82
    {  .ILL, 1, .Illegal              }, // 83
    {  .STY, 2, .ZP                   }, // 84
    {  .STA, 2, .ZP                   }, // 85
    {  .STX, 2, .ZP                   }, // 86
    { .SMB0, 2, .ZP                   }, // 87
    {  .DEY, 1, .Implied              }, // 88
    {  .BIT, 2, .Immediate            }, // 89
    {  .TXA, 1, .Implied              }, // 8a
    {  .ILL, 1, .Illegal              }, // 8b
    {  .STY, 3, .Absolute             }, // 8c
    {  .STA, 3, .Absolute             }, // 8d
    {  .STX, 3, .Absolute             }, // 8e
    { .BBS0, 3, .ZP_and_Relative      }, // 8f
    {  .BCC, 2, .PC_Relative          }, // 90
    {  .STA, 2, .ZP_Indirect_Y        }, // 91
    {  .STA, 2, .ZP_Indirect          }, // 92
    {  .ILL, 1, .Illegal              }, // 93
    {  .STY, 2, .ZP_X                 }, // 94
    {  .STA, 2, .ZP_X                 }, // 95
    {  .STX, 2, .ZP_Y                 }, // 96
    { .SMB1, 2, .ZP                   }, // 97
    {  .TYA, 1, .Implied              }, // 98
    {  .STA, 3, .Absolute_Y           }, // 99
    {  .TXS, 1, .Implied              }, // 9a
    {  .ILL, 1, .Illegal              }, // 9b
    {  .STZ, 3, .Absolute             }, // 9c
    {  .STA, 3, .Absolute_X           }, // 9d
    {  .STZ, 3, .Absolute_X           }, // 9e
    { .BBS1, 3, .ZP_and_Relative      }, // 9f
    {  .LDY, 2, .Immediate            }, // a0
    {  .LDA, 2, .ZP_X_Indirect        }, // a1
    {  .LDX, 2, .Immediate            }, // a2
    {  .ILL, 1, .Illegal              }, // a3
    {  .LDY, 2, .ZP                   }, // a4
    {  .LDA, 2, .ZP                   }, // a5
    {  .LDX, 2, .ZP                   }, // a6
    { .SMB2, 2, .ZP                   }, // a7
    {  .TAY, 1, .Implied              }, // a8
    {  .LDA, 2, .Immediate            }, // a9
    {  .TAX, 1, .Implied              }, // aa
    {  .ILL, 1, .Illegal              }, // ab
    {  .LDY, 3, .Absolute             }, // ac
    {  .LDA, 3, .Absolute             }, // ad
    {  .LDX, 3, .Absolute             }, // ae
    { .BBS2, 3, .ZP_and_Relative      }, // af
    {  .BCS, 2, .PC_Relative          }, // b0
    {  .LDA, 2, .ZP_Indirect_Y        }, // b1
    {  .LDA, 2, .ZP_Indirect          }, // b2
    {  .ILL, 1, .Illegal              }, // b3
    {  .LDY, 2, .ZP_X                 }, // b4
    {  .LDA, 2, .ZP_X                 }, // b5
    {  .LDX, 2, .ZP_Y                 }, // b6
    { .SMB3, 2, .ZP                   }, // b7
    {  .CLV, 1, .Implied              }, // b8
    {  .LDA, 3, .Absolute_Y           }, // b9
    {  .TSX, 1, .Implied              }, // ba
    {  .ILL, 1, .Illegal              }, // bb
    {  .LDY, 3, .Absolute_X           }, // bc
    {  .LDA, 3, .Absolute_X           }, // bd
    {  .LDX, 3, .Absolute_Y           }, // be
    { .BBS3, 3, .ZP_and_Relative      }, // bf
    {  .CPY, 2, .Immediate            }, // c0
    {  .CMP, 2, .ZP_X_Indirect        }, // c1
    {  .ILL, 2, .Illegal              }, // c2
    {  .ILL, 1, .Illegal              }, // c3
    {  .CPY, 2, .ZP                   }, // c4
    {  .CMP, 2, .ZP                   }, // c5
    {  .DEC, 2, .ZP                   }, // c6
    { .SMB4, 2, .ZP                   }, // c7
    {  .INY, 1, .Implied              }, // c8
    {  .CMP, 2, .Immediate            }, // c9
    {  .DEX, 1, .Implied              }, // ca
    {  .WAI, 1, .Implied              }, // cb
    {  .CPY, 3, .Absolute             }, // cc
    {  .CMP, 3, .Absolute             }, // cd
    {  .DEC, 3, .Absolute             }, // ce
    { .BBS4, 3, .ZP_and_Relative      }, // cf
    {  .BNE, 2, .PC_Relative          }, // d0
    {  .CMP, 2, .ZP_Indirect_Y        }, // d1
    {  .CMP, 2, .ZP_Indirect          }, // d2
    {  .ILL, 1, .Illegal              }, // d3
    {  .ILL, 2, .Illegal              }, // d4
    {  .CMP, 2, .ZP_X                 }, // d5
    {  .DEC, 2, .ZP_X                 }, // d6
    { .SMB5, 2, .ZP                   }, // d7
    {  .CLD, 1, .Implied              }, // d8
    {  .CMP, 3, .Absolute_Y           }, // d9
    {  .PHX, 1, .Implied              }, // da
    {  .STP, 1, .Implied              }, // db
    {  .ILL, 3, .Illegal              }, // dc
    {  .CMP, 3, .Absolute_X           }, // dd
    {  .DEC, 3, .Absolute_X           }, // de
    { .BBS5, 3, .ZP_and_Relative      }, // df
    {  .CPX, 2, .Immediate            }, // e0
    {  .SBC, 2, .ZP_X_Indirect        }, // e1
    {  .ILL, 2, .Illegal              }, // e2
    {  .ILL, 1, .Illegal              }, // e3
    {  .CPX, 2, .ZP                   }, // e4
    {  .SBC, 2, .ZP                   }, // e5
    {  .INC, 2, .ZP                   }, // e6
    { .SMB6, 2, .ZP                   }, // e7
    {  .INX, 1, .Implied              }, // e8
    {  .SBC, 2, .Immediate            }, // e9
    {  .NOP, 1, .Implied              }, // ea
    {  .ILL, 1, .Illegal              }, // eb
    {  .CPX, 3, .Absolute             }, // ec
    {  .SBC, 3, .Absolute             }, // ed
    {  .INC, 3, .Absolute             }, // ee
    { .BBS6, 3, .ZP_and_Relative      }, // ef
    {  .BEQ, 2, .PC_Relative          }, // f0
    {  .SBC, 2, .ZP_Indirect_Y        }, // f1
    {  .SBC, 2, .ZP_Indirect          }, // f2
    {  .ILL, 1, .Illegal              }, // f3
    {  .ILL, 2, .Illegal              }, // f4
    {  .SBC, 2, .ZP_X                 }, // f5
    {  .INC, 2, .ZP_X                 }, // f6
    { .SMB7, 2, .ZP                   }, // f7
    {  .SED, 1, .Implied              }, // f8
    {  .SBC, 3, .Absolute_Y           }, // f9
    {  .PLX, 1, .Implied              }, // fa
    {  .ILL, 1, .Illegal              }, // fb
    {  .ILL, 3, .Illegal              }, // fc
    {  .SBC, 3, .Absolute_X           }, // fd
    {  .INC, 3, .Absolute_X           }, // fe
    { .BBS7, 3, .ZP_and_Relative      }, // ff
}


