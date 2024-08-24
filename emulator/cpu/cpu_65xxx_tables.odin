
package cpu

CPU_65xxx_opcode :: enum {
    ADC, AND, ASL,           BCC, BCS, BEQ, BIT, BMI, BNE, BPL, BRA, BRK, BVC, BVS,
    CLC, CLD, CLI, CLV, CMP, CPX, CPY, DEC, DEX, DEY, EOR, INC, INX, INY, JMP, JSR,
    LDA, LDX, LDY, LSR, NOP, ORA, PHA, PHP, PHX, PHY, PLA, PLP, PLX, PLY,      ROL,
    ROR, RTI, RTS, SBC, SEC, SED, SEI,      STA, STP, STX, STY, STZ, TAX, TAY, TRB,
    TSB, TSX, TXA, TXS, TYA, WAI, ILL,
    RMB0, RMB1, RMB2, RMB3, RMB4, RMB5, RMB6, RMB7,
    SMB0, SMB1, SMB2, SMB3, SMB4, SMB5, SMB6, SMB7,
    BBS0, BBS1, BBS2, BBS3, BBS4, BBS5, BBS6, BBS7,
    BBR0, BBR1, BBR2, BBR3, BBR4, BBR5, BBR6, BBR7,
}

CPU_65xxx_mode   :: enum {
    Absolute,               DP_Indirect,            PC_Relative_Long,
    Absolute_Indirect,      DP_Indirect_Long,       S_Relative,
    Absolute_Indirect_Long, DP_Indirect_Long_Y,     S_Relative_Indirect_Y,
    Absolute_Long,          DP_Indirect_Y,          ZP,
    Absolute_Long_X,        DP_X,                   ZP_and_Relative,
    Absolute_X,             DP_X_Indirect,          ZP_Indirect,
    Absolute_X_Indirect,    DP_Y,                   ZP_Indirect_Y,
    Absolute_Y,             Illegal,                ZP_X,
    Accumulator,            Immediate,              ZP_X_Indirect,
    BlockMove,              Implied,                ZP_Y,
    DP,                     PC_Relative,
}

CPU_65xxx_mode_name : [CPU_65xxx_mode]string = {
    .Absolute =               "abs",
    .Absolute_X =             "abs,X",
    .Absolute_Y =             "abs,Y",
    .Accumulator =            "acc",
    .Immediate =              "imm",
    .Implied =                "imp",
    .DP =                     "dir",
    .DP_X =                   "dir,X",
    .DP_Y =                   "dir,Y",
    .DP_X_Indirect =          "(dir,X)",
    .DP_Indirect =            "(dir)",
    .DP_Indirect_Long =       "[dir]",
    .DP_Indirect_Y =          "(dir),Y",
    .DP_Indirect_Long_Y =     "[dir],Y",
    .Absolute_X_Indirect =    "(abs,X)",
    .Absolute_Indirect =      "(abs)",
    .Absolute_Indirect_Long = "[abs]",
    .Absolute_Long =          "long",
    .Absolute_Long_X =        "long,X",
    .BlockMove =              "src,dest",
    .PC_Relative =            "rel8",
    .PC_Relative_Long =       "rel16",
    .S_Relative =             "stk,S",
    .S_Relative_Indirect_Y =  "(stk,S),Y",
    .ZP_X_Indirect =          "(zp,X)",
    .ZP =                     "zp",
    .ZP_X =                   "zp,X",
    .ZP_Y =                   "zp,Y",
    .ZP_and_Relative =        "zp,rel",
    .ZP_Indirect_Y =          "(zp),Y",
    .ZP_Indirect =            "(zp)",
    .Illegal =                "-",
}

