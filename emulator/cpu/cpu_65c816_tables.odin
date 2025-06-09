
// cycle tables, used to 

package cpu

// base cycles, reduced according to following tables
@(private)
cycles_65c816 := [256]u32 {
    8, 7, 8, 5, 7, 4, 7, 7, 3, 3, 2, 4, 8, 5, 8, 6, // 0
    2, 7, 6, 8, 7, 5, 8, 7, 2, 6, 2, 2, 8, 6, 9, 6, // 1
    6, 7, 8, 5, 4, 4, 7, 7, 4, 3, 2, 5, 5, 5, 8, 6, // 2
    2, 7, 6, 8, 5, 5, 8, 7, 2, 6, 2, 2, 6, 6, 9, 6, // 3
    7, 7, 2, 5, 7, 4, 7, 7, 4, 3, 2, 3, 3, 5, 8, 6, // 4
    2, 7, 6, 8, 7, 5, 8, 7, 2, 6, 4, 2, 4, 6, 9, 6, // 5
    6, 7, 6, 5, 4, 4, 7, 7, 5, 3, 2, 6, 5, 5, 8, 6, // 6
    2, 7, 6, 8, 5, 5, 8, 7, 2, 6, 5, 2, 6, 6, 9, 6, // 7
    3, 7, 4, 5, 4, 4, 4, 7, 2, 3, 2, 3, 5, 5, 5, 6, // 8
    2, 7, 6, 8, 5, 5, 5, 7, 2, 6, 2, 2, 5, 6, 6, 6, // 9
    3, 7, 3, 5, 4, 4, 4, 7, 2, 3, 2, 4, 5, 5, 5, 6, // a
    2, 7, 6, 8, 5, 5, 5, 7, 2, 6, 2, 2, 6, 6, 6, 6, // b
    3, 7, 3, 5, 4, 4, 7, 7, 2, 3, 2, 3, 5, 5, 8, 6, // c
    2, 7, 6, 8, 6, 5, 8, 7, 2, 6, 4, 3, 6, 6, 9, 6, // d
    3, 7, 3, 5, 4, 4, 7, 7, 2, 3, 2, 3, 5, 5, 8, 6, // e
    2, 7, 6, 8, 5, 5, 8, 7, 2, 6, 5, 2, 8, 6, 9, 6, // f
 // 0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f    
}

// cycle reduction when M flag == 1
@(private)
decCycles_flagM := [256]u32 {
	0, 1, 0, 1, 2, 1, 2, 1, 0, 1, 0, 0, 2, 1, 2, 1,
	0, 1, 1, 1, 2, 1, 2, 1, 0, 1, 0, 0, 2, 1, 2, 1,
	0, 1, 0, 1, 1, 1, 2, 1, 0, 1, 0, 0, 1, 1, 2, 1,
	0, 1, 1, 1, 1, 1, 2, 1, 0, 1, 0, 0, 1, 1, 2, 1,
	0, 1, 0, 1, 0, 1, 2, 1, 1, 1, 0, 0, 0, 1, 2, 1,
	0, 1, 1, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 2, 1,
	0, 1, 0, 1, 1, 1, 2, 1, 1, 1, 0, 0, 0, 1, 2, 1,
	0, 1, 1, 1, 1, 1, 2, 1, 0, 1, 0, 0, 0, 1, 2, 1,
	0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1,
	0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1,
	0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1,
	0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1,
	0, 1, 0, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 2, 1,
	0, 1, 1, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 2, 1,
	0, 1, 0, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 2, 1,
	0, 1, 1, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 2, 1,
 // 0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f    
}

// cycle reduction when X flag == 1
@(private)
decCycles_flagX := [256]u32 {
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 0
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, // 1
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 2
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, // 3
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 4
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, // 5
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 6
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, // 7
	0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, // 8
	0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 9
	1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, // a
	0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 2, 1, 2, 0, // b
	1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, // c
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, // d
	1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, // e
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, // f
 // 0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f    
}

// cycle increase when DL (lo of D register) != 00
@(private)
incCycles_regDL_not00 := [256]u32 {
	0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
}


// cycle increase when px (page crossing) occured
@(private)
incCycles_PageCross := [256]u32 {
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0,
}

CPU_w65c816_debug :: struct {
    opcode: CPU_65xxx_opcode,
    mode:   CPU_65xxx_mode,
}

CPU_w65c816_opcodes : [256]CPU_w65c816_debug = {
    {  .BRK, .Implied                }, // 00
    {  .ORA, .DP_X_Indirect          }, // 01
    {  .COP, .Immediate              }, // 02
    {  .ORA, .S_Relative             }, // 03
    {  .TSB, .DP                     }, // 04
    {  .ORA, .DP                     }, // 05
    {  .ASL, .DP                     }, // 06
    {  .ORA, .DP_Indirect_Long       }, // 07
    {  .PHP, .Implied                }, // 08
    {  .ORA, .Immediate_flag_M      }, // 09
    {  .ASL, .Accumulator            }, // 0a
    {  .PHD, .Implied                }, // 0b
    {  .TSB, .Absolute               }, // 0c
    {  .ORA, .Absolute               }, // 0d
    {  .ASL, .Absolute               }, // 0e
    {  .ORA, .Absolute_Long          }, // 0f
    {  .BPL, .PC_Relative            }, // 10
    {  .ORA, .DP_Indirect_Y          }, // 11
    {  .ORA, .DP_Indirect            }, // 12
    {  .ORA, .S_Relative_Indirect_Y  }, // 13
    {  .TRB, .DP                     }, // 14
    {  .ORA, .DP_X                   }, // 15
    {  .ASL, .DP_X                   }, // 16
    {  .ORA, .DP_Indirect_Long_Y     }, // 17
    {  .CLC, .Implied                }, // 18
    {  .ORA, .Absolute_Y             }, // 19
    {  .INC, .Accumulator            }, // 1a
    {  .TCS, .Implied                }, // 1b
    {  .TRB, .Absolute               }, // 1c
    {  .ORA, .Absolute_X             }, // 1d
    {  .ASL, .Absolute_X             }, // 1e
    {  .ORA, .Absolute_Long_X        }, // 1f
    {  .JSR, .Absolute               }, // 20
    {  .AND, .DP_X_Indirect          }, // 21
    {  .JSL, .Absolute_Long          }, // 22
    {  .AND, .S_Relative             }, // 23
    {  .BIT, .DP                     }, // 24
    {  .AND, .DP                     }, // 25
    {  .ROL, .DP                     }, // 26
    {  .AND, .DP_Indirect_Long       }, // 27
    {  .PLP, .Implied                }, // 28
    {  .AND, .Immediate_flag_M       }, // 29
    {  .ROL, .Accumulator            }, // 2a
    {  .PLD, .Implied                }, // 2b
    {  .BIT, .Absolute               }, // 2c
    {  .AND, .Absolute               }, // 2d
    {  .ROL, .Absolute               }, // 2e
    {  .AND, .Absolute_Long          }, // 2f
    {  .BMI, .PC_Relative            }, // 30
    {  .AND, .DP_Indirect_Y          }, // 31
    {  .AND, .DP_Indirect            }, // 32
    {  .AND, .S_Relative_Indirect_Y  }, // 33
    {  .BIT, .DP_X                   }, // 34
    {  .AND, .DP_X                   }, // 35
    {  .ROL, .DP_X                   }, // 36
    {  .AND, .DP_Indirect_Long_Y     }, // 37
    {  .SEC, .Implied                }, // 38
    {  .AND, .Absolute_Y             }, // 39
    {  .DEC, .Accumulator            }, // 3a
    {  .TSC, .Implied                }, // 3b
    {  .BIT, .Absolute_X             }, // 3c
    {  .AND, .Absolute_X             }, // 3d
    {  .ROL, .Absolute_X             }, // 3e
    {  .AND, .Absolute_Long_X        }, // 3f
    {  .RTI, .Implied                }, // 40
    {  .EOR, .DP_X_Indirect          }, // 41
    {  .WDM, .Immediate              }, // 42
    {  .EOR, .S_Relative             }, // 43
    {  .MVP, .BlockMove              }, // 44
    {  .EOR, .DP                     }, // 45
    {  .LSR, .DP                     }, // 46
    {  .EOR, .DP_Indirect_Long       }, // 47
    {  .PHA, .Implied                }, // 48
    {  .EOR, .Immediate_flag_M       }, // 49
    {  .LSR, .Accumulator            }, // 4a
    {  .PHK, .Implied                }, // 4b
    {  .JMP, .Absolute               }, // 4c
    {  .EOR, .Absolute               }, // 4d
    {  .LSR, .Absolute               }, // 4e
    {  .EOR, .Absolute_Long          }, // 4f
    {  .BVC, .PC_Relative            }, // 50
    {  .EOR, .DP_Indirect_Y          }, // 51
    {  .EOR, .DP_Indirect            }, // 52
    {  .EOR, .S_Relative_Indirect_Y  }, // 53
    {  .MVN, .BlockMove              }, // 54
    {  .EOR, .DP_X                   }, // 55
    {  .LSR, .DP_X                   }, // 56
    {  .EOR, .DP_Indirect_Long_Y     }, // 57
    {  .CLI, .Implied                }, // 58
    {  .EOR, .Absolute_Y             }, // 59
    {  .PHY, .Implied                }, // 5a
    {  .TCD, .Implied                }, // 5b
    {  .JMP, .Absolute_Long          }, // 5c
    {  .EOR, .Absolute_X             }, // 5d
    {  .LSR, .Absolute_X             }, // 5e
    {  .EOR, .Absolute_Long_X        }, // 5f
    {  .RTS, .Implied                }, // 60
    {  .ADC, .DP_X_Indirect          }, // 61
    {  .PER, .PC_Relative_Long       }, // 62
    {  .ADC, .S_Relative             }, // 63
    {  .STZ, .DP                     }, // 64
    {  .ADC, .DP                     }, // 65
    {  .ROR, .DP                     }, // 66
    {  .ADC, .DP_Indirect_Long       }, // 67
    {  .PLA, .Implied                }, // 68
    {  .ADC, .Immediate_flag_M       }, // 69
    {  .ROR, .Accumulator            }, // 6a
    {  .RTL, .Implied                }, // 6b
    {  .JMP, .Absolute_Indirect      }, // 6c
    {  .ADC, .Absolute               }, // 6d
    {  .ROR, .Absolute               }, // 6e
    {  .ADC, .Absolute_Long          }, // 6f
    {  .BVS, .PC_Relative            }, // 70
    {  .ADC, .DP_Indirect_Y          }, // 71
    {  .ADC, .DP_Indirect            }, // 72
    {  .ADC, .S_Relative_Indirect_Y  }, // 73
    {  .STZ, .DP_X                   }, // 74
    {  .ADC, .DP_X                   }, // 75
    {  .ROR, .DP_X                   }, // 76
    {  .ADC, .DP_Indirect_Long_Y     }, // 77
    {  .SEI, .Implied                }, // 78
    {  .ADC, .Absolute_Y             }, // 79
    {  .PLY, .Implied                }, // 7a
    {  .TDC, .Implied                }, // 7b
    {  .JMP, .Absolute_X_Indirect    }, // 7c
    {  .ADC, .Absolute_X             }, // 7d
    {  .ROR, .Absolute_X             }, // 7e
    {  .ADC, .Absolute_Long_X        }, // 7f
    {  .BRA, .PC_Relative            }, // 80
    {  .STA, .DP_X_Indirect          }, // 81
    {  .BRL, .PC_Relative_Long       }, // 82
    {  .STA, .S_Relative             }, // 83
    {  .STY, .DP                     }, // 84
    {  .STA, .DP                     }, // 85
    {  .STX, .DP                     }, // 86
    {  .STA, .DP_Indirect_Long       }, // 87
    {  .DEY, .Implied                }, // 88
    {  .BIT, .Immediate_flag_M       }, // 89
    {  .TXA, .Implied                }, // 8a
    {  .PHB, .Implied                }, // 8b
    {  .STY, .Absolute               }, // 8c
    {  .STA, .Absolute               }, // 8d
    {  .STX, .Absolute               }, // 8e
    {  .STA, .Absolute_Long          }, // 8f
    {  .BCC, .PC_Relative            }, // 90
    {  .STA, .DP_Indirect_Y          }, // 91
    {  .STA, .DP_Indirect            }, // 92
    {  .STA, .S_Relative_Indirect_Y  }, // 93
    {  .STY, .DP_X                   }, // 94
    {  .STA, .DP_X                   }, // 95
    {  .STX, .DP_Y                   }, // 96
    {  .STA, .DP_Indirect_Long_Y     }, // 97
    {  .TYA, .Implied                }, // 98
    {  .STA, .Absolute_Y             }, // 99
    {  .TXS, .Implied                }, // 9a
    {  .TXY, .Implied                }, // 9b
    {  .STZ, .Absolute               }, // 9c
    {  .STA, .Absolute_X             }, // 9d
    {  .STZ, .Absolute_X             }, // 9e
    {  .STA, .Absolute_Long_X        }, // 9f
    {  .LDY, .Immediate_flag_X       }, // a0
    {  .LDA, .DP_X_Indirect          }, // a1
    {  .LDX, .Immediate_flag_X       }, // a2
    {  .LDA, .S_Relative             }, // a3
    {  .LDY, .DP                     }, // a4
    {  .LDA, .DP                     }, // a5
    {  .LDX, .DP                     }, // a6
    {  .LDA, .DP_Indirect_Long       }, // a7
    {  .TAY, .Implied                }, // a8
    {  .LDA, .Immediate_flag_M       }, // a9
    {  .TAX, .Implied                }, // aa
    {  .PLB, .Implied                }, // ab
    {  .LDY, .Absolute               }, // ac
    {  .LDA, .Absolute               }, // ad
    {  .LDX, .Absolute               }, // ae
    {  .LDA, .Absolute_Long          }, // af
    {  .BCS, .PC_Relative            }, // b0
    {  .LDA, .DP_Indirect_Y          }, // b1
    {  .LDA, .DP_Indirect            }, // b2
    {  .LDA, .S_Relative_Indirect_Y  }, // b3
    {  .LDY, .DP_X                   }, // b4
    {  .LDA, .DP_X                   }, // b5
    {  .LDX, .DP_Y                   }, // b6
    {  .LDA, .DP_Indirect_Long_Y     }, // b7
    {  .CLV, .Implied                }, // b8
    {  .LDA, .Absolute_Y             }, // b9
    {  .TSX, .Implied                }, // ba
    {  .TYX, .Implied                }, // bb
    {  .LDY, .Absolute_X             }, // bc
    {  .LDA, .Absolute_X             }, // bd
    {  .LDX, .Absolute_Y             }, // be
    {  .LDA, .Absolute_Long_X        }, // bf
    {  .CPY, .Immediate_flag_X       }, // c0
    {  .CMP, .DP_X_Indirect          }, // c1
    {  .REP, .Immediate              }, // c2
    {  .CMP, .S_Relative             }, // c3
    {  .CPY, .DP                     }, // c4
    {  .CMP, .DP                     }, // c5
    {  .DEC, .DP                     }, // c6
    {  .CMP, .DP_Indirect_Long       }, // c7
    {  .INY, .Implied                }, // c8
    {  .CMP, .Immediate_flag_M       }, // c9
    {  .DEX, .Implied                }, // ca
    {  .WAI, .Implied                }, // cb
    {  .CPY, .Absolute               }, // cc
    {  .CMP, .Absolute               }, // cd
    {  .DEC, .Absolute               }, // ce
    {  .CMP, .Absolute_Long          }, // cf
    {  .BNE, .PC_Relative            }, // d0
    {  .CMP, .DP_Indirect_Y          }, // d1
    {  .CMP, .DP_Indirect            }, // d2
    {  .CMP, .S_Relative_Indirect_Y  }, // d3
    {  .PEI, .DP                     }, // d4
    {  .CMP, .DP_X                   }, // d5
    {  .DEC, .DP_X                   }, // d6
    {  .CMP, .DP_Indirect_Long_Y     }, // d7
    {  .CLD, .Implied                }, // d8
    {  .CMP, .Absolute_Y             }, // d9
    {  .PHX, .Implied                }, // da
    {  .STP, .Implied                }, // db
    {  .JMP, .Absolute_Indirect_Long }, // dc
    {  .CMP, .Absolute_X             }, // dd
    {  .DEC, .Absolute_X             }, // de
    {  .CMP, .Absolute_Long_X        }, // df
    {  .CPX, .Immediate_flag_X       }, // e0
    {  .SBC, .DP_X_Indirect          }, // e1
    {  .SEP, .Immediate              }, // e2
    {  .SBC, .S_Relative             }, // e3
    {  .CPX, .DP                     }, // e4
    {  .SBC, .DP                     }, // e5
    {  .INC, .DP                     }, // e6
    {  .SBC, .DP_Indirect_Long       }, // e7
    {  .INX, .Implied                }, // e8
    {  .SBC, .Immediate_flag_M       }, // e9
    {  .NOP, .Implied                }, // ea
    {  .XBA, .Implied                }, // eb
    {  .CPX, .Absolute               }, // ec
    {  .SBC, .Absolute               }, // ed
    {  .INC, .Absolute               }, // ee
    {  .SBC, .Absolute_Long          }, // ef
    {  .BEQ, .PC_Relative            }, // f0
    {  .SBC, .DP_Indirect_Y          }, // f1
    {  .SBC, .DP_Indirect            }, // f2
    {  .SBC, .S_Relative_Indirect_Y  }, // f3
    {  .PEA, .Immediate16            }, // f4
    {  .SBC, .DP_X                   }, // f5
    {  .INC, .DP_X                   }, // f6
    {  .SBC, .DP_Indirect_Long_Y     }, // f7
    {  .SED, .Implied                }, // f8
    {  .SBC, .Absolute_Y             }, // f9
    {  .PLX, .Implied                }, // fa
    {  .XCE, .Implied                }, // fb
    {  .JSR, .Absolute_X_Indirect    }, // fc
    {  .SBC, .Absolute_X             }, // fd
    {  .INC, .Absolute_X             }, // fe
    {  .SBC, .Absolute_Long_X        }, // ff

}

