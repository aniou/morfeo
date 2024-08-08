
package cpu

w65c816_run_opcode :: proc(cpu: ^CPU_65C816) {
    switch (cpu.ir) {

    case 0x00:                                    // BRK
        mode_Implied                  (cpu)
        oper_BRK                      (cpu)

    case 0x01:                                    // ORA ($10,X)
        mode_DP_X_Indirect            (cpu)
        oper_ORA                      (cpu)

    case 0x02:                                    // COP #$12
        mode_Immediate                (cpu)
        oper_COP                      (cpu)

    case 0x03:                                    // ORA $32,S
        mode_S_Relative               (cpu)
        oper_ORA                      (cpu)

    case 0x04:                                    // TSB $10
        mode_DP                       (cpu)
        oper_TSB                      (cpu)

    case 0x05:                                    // ORA $10
        mode_DP                       (cpu)
        oper_ORA                      (cpu)

    case 0x06:                                    // ASL $10
        mode_DP                       (cpu)
        oper_ASL                      (cpu)

    case 0x07:                                    // ORA [$10]
        mode_DP_Indirect_Long         (cpu)
        oper_ORA                      (cpu)

    case 0x08:                                    // PHP
        mode_Implied                  (cpu)
        oper_PHP                      (cpu)

    case 0x09:                                    // ORA #$54
        mode_Immediate_flag_M         (cpu)
        oper_ORA                      (cpu)

    case 0x0a:                                    // ASL
        mode_Accumulator              (cpu)
        oper_ASL_A                    (cpu)

    case 0x0b:                                    // PHD
        mode_Implied                  (cpu)
        oper_PHD                      (cpu)

    case 0x0c:                                    // TSB $9876
        mode_Absolute_DBR             (cpu)
        oper_TSB                      (cpu)

    case 0x0d:                                    // ORA $9876
        mode_Absolute_DBR             (cpu)
        oper_ORA                      (cpu)

    case 0x0e:                                    // ASL $9876
        mode_Absolute_DBR             (cpu)
        oper_ASL                      (cpu)

    case 0x0f:                                    // ORA $FEDBCA
        mode_Absolute_Long            (cpu)
        oper_ORA                      (cpu)

    case 0x10:                                    // BPL LABEL
        mode_PC_Relative              (cpu)
        oper_BPL                      (cpu)

    case 0x11:                                    // ORA ($10),Y
        mode_DP_Indirect_Y            (cpu)
        oper_ORA                      (cpu)

    case 0x12:                                    // ORA ($10)
        mode_DP_Indirect              (cpu)
        oper_ORA                      (cpu)

    case 0x13:                                    // ORA ($32,S),Y
        mode_S_Relative_Indirect_Y    (cpu)
        oper_ORA                      (cpu)

    case 0x14:                                    // TRB $10
        mode_DP                       (cpu)
        oper_TRB                      (cpu)

    case 0x15:                                    // ORA $10,X
        mode_DP_X                     (cpu)
        oper_ORA                      (cpu)

    case 0x16:                                    // ASL $10,X
        mode_DP_X                     (cpu)
        oper_ASL                      (cpu)

    case 0x17:                                    // ORA [$10],Y
        mode_DP_Indirect_Long_Y       (cpu)
        oper_ORA                      (cpu)

    case 0x18:                                    // CLC
        mode_Implied                  (cpu)
        oper_CLC                      (cpu)

    case 0x19:                                    // ORA $9876,Y
        mode_Absolute_Y               (cpu)
        oper_ORA                      (cpu)

    case 0x1a:                                    // INC
        mode_Accumulator              (cpu)
        oper_INC_A                    (cpu)

    case 0x1b:                                    // TCS
        mode_Implied                  (cpu)
        oper_TCS                      (cpu)

    case 0x1c:                                    // TRB $9876
        mode_Absolute_DBR             (cpu)
        oper_TRB                      (cpu)

    case 0x1d:                                    // ORA $9876,X
        mode_Absolute_X               (cpu)
        oper_ORA                      (cpu)

    case 0x1e:                                    // ASL $9876,X
        mode_Absolute_X               (cpu)
        oper_ASL                      (cpu)

    case 0x1f:                                    // ORA $FEDCBA,X
        mode_Absolute_Long_X          (cpu)
        oper_ORA                      (cpu)

    case 0x20:                                    // JSR $1234
        mode_Absolute_DBR             (cpu)
        oper_JSR                      (cpu)

    case 0x21:                                    // AND ($10,X)
        mode_DP_X_Indirect            (cpu)
        oper_AND                      (cpu)

    case 0x22:                                    // JSL $123456
        mode_Absolute_Long            (cpu)
        oper_JSL                      (cpu)

    case 0x23:                                    // AND $32,S
        mode_S_Relative               (cpu)
        oper_AND                      (cpu)

    case 0x24:                                    // BIT $10
        mode_DP                       (cpu)
        oper_BIT                      (cpu)

    case 0x25:                                    // AND $10
        mode_DP                       (cpu)
        oper_AND                      (cpu)

    case 0x26:                                    // ROL $10
        mode_DP                       (cpu)
        oper_ROL                      (cpu)

    case 0x27:                                    // AND [$10]
        mode_DP_Indirect_Long         (cpu)
        oper_AND                      (cpu)

    case 0x28:                                    // PLP
        mode_Implied                  (cpu)
        oper_PLP                      (cpu)

    case 0x29:                                    // AND #$54
        mode_Immediate_flag_M         (cpu)
        oper_AND                      (cpu)

    case 0x2a:                                    // ROL
        mode_Accumulator              (cpu)
        oper_ROL_A                    (cpu)

    case 0x2b:                                    // PLD
        mode_Implied                  (cpu)
        oper_PLD                      (cpu)

    case 0x2c:                                    // BIT $9876
        mode_Absolute_DBR             (cpu)
        oper_BIT                      (cpu)

    case 0x2d:                                    // AND $9876
        mode_Absolute_DBR             (cpu)
        oper_AND                      (cpu)

    case 0x2e:                                    // ROL $9876
        mode_Absolute_DBR             (cpu)
        oper_ROL                      (cpu)

    case 0x2f:                                    // AND $FEDBCA
        mode_Absolute_Long            (cpu)
        oper_AND                      (cpu)

    case 0x30:                                    // BMI LABEL
        mode_PC_Relative              (cpu)
        oper_BMI                      (cpu)

    case 0x31:                                    // AND ($10),Y
        mode_DP_Indirect_Y            (cpu)
        oper_AND                      (cpu)

    case 0x32:                                    // AND ($10)
        mode_DP_Indirect              (cpu)
        oper_AND                      (cpu)

    case 0x33:                                    // AND ($32,S),Y
        mode_S_Relative_Indirect_Y    (cpu)
        oper_AND                      (cpu)

    case 0x34:                                    // BIT $10,X
        mode_DP_X                     (cpu)
        oper_BIT                      (cpu)

    case 0x35:                                    // AND $10,X
        mode_DP_X                     (cpu)
        oper_AND                      (cpu)

    case 0x36:                                    // ROL $10,X
        mode_DP_X                     (cpu)
        oper_ROL                      (cpu)

    case 0x37:                                    // AND [$10],Y
        mode_DP_Indirect_Long_Y       (cpu)
        oper_AND                      (cpu)

    case 0x38:                                    // SEC
        mode_Implied                  (cpu)
        oper_SEC                      (cpu)

    case 0x39:                                    // AND $9876,Y
        mode_Absolute_Y               (cpu)
        oper_AND                      (cpu)

    case 0x3a:                                    // DEC
        mode_Accumulator              (cpu)
        oper_DEC_A                    (cpu)

    case 0x3b:                                    // TSC
        mode_Implied                  (cpu)
        oper_TSC                      (cpu)

    case 0x3c:                                    // BIT $9876,X
        mode_Absolute_X               (cpu)
        oper_BIT                      (cpu)

    case 0x3d:                                    // AND $9876,X
        mode_Absolute_X               (cpu)
        oper_AND                      (cpu)

    case 0x3e:                                    // ROL $9876,X
        mode_Absolute_X               (cpu)
        oper_ROL                      (cpu)

    case 0x3f:                                    // AND $FEDCBA,X
        mode_Absolute_Long_X          (cpu)
        oper_AND                      (cpu)

    case 0x40:                                    // RTI
        mode_Implied                  (cpu)
        oper_RTI                      (cpu)

    case 0x41:                                    // EOR ($10,X)
        mode_DP_X_Indirect            (cpu)
        oper_EOR                      (cpu)

    case 0x42:                                    // WDM
        mode_Immediate                (cpu)
        oper_WDM                      (cpu)

    case 0x43:                                    // EOR $32,S
        mode_S_Relative               (cpu)
        oper_EOR                      (cpu)

    case 0x44:                                    // MVP #$12,#$34
        mode_BlockMove                (cpu)
        oper_MVP                      (cpu)

    case 0x45:                                    // EOR $10
        mode_DP                       (cpu)
        oper_EOR                      (cpu)

    case 0x46:                                    // LSR $10
        mode_DP                       (cpu)
        oper_LSR                      (cpu)

    case 0x47:                                    // EOR [$10]
        mode_DP_Indirect_Long         (cpu)
        oper_EOR                      (cpu)

    case 0x48:                                    // PHA
        mode_Implied                  (cpu)
        oper_PHA                      (cpu)

    case 0x49:                                    // EOR #$54
        mode_Immediate_flag_M         (cpu)
        oper_EOR                      (cpu)

    case 0x4a:                                    // LSR
        mode_Accumulator              (cpu)
        oper_LSR_A                    (cpu)

    case 0x4b:                                    // PHK
        mode_Implied                  (cpu)
        oper_PHK                      (cpu)

    case 0x4c:                                    // JMP $1234
        mode_Absolute_PBR             (cpu)
        oper_JMP                      (cpu)

    case 0x4d:                                    // EOR $9876
        mode_Absolute_DBR             (cpu)
        oper_EOR                      (cpu)

    case 0x4e:                                    // LSR $9876
        mode_Absolute_DBR             (cpu)
        oper_LSR                      (cpu)

    case 0x4f:                                    // EOR $FEDBCA
        mode_Absolute_Long            (cpu)
        oper_EOR                      (cpu)

    case 0x50:                                    // BVC LABEL
        mode_PC_Relative              (cpu)
        oper_BVC                      (cpu)

    case 0x51:                                    // EOR ($10),Y
        mode_DP_Indirect_Y            (cpu)
        oper_EOR                      (cpu)

    case 0x52:                                    // EOR ($10)
        mode_DP_Indirect              (cpu)
        oper_EOR                      (cpu)

    case 0x53:                                    // EOR ($32,S),Y
        mode_S_Relative_Indirect_Y    (cpu)
        oper_EOR                      (cpu)

    case 0x54:                                    // MVN #$12,#$34
        mode_BlockMove                (cpu)
        oper_MVN                      (cpu)

    case 0x55:                                    // EOR $10,X
        mode_DP_X                     (cpu)
        oper_EOR                      (cpu)

    case 0x56:                                    // LSR $10,X
        mode_DP_X                     (cpu)
        oper_LSR                      (cpu)

    case 0x57:                                    // EOR [$10],Y
        mode_DP_Indirect_Long_Y       (cpu)
        oper_EOR                      (cpu)

    case 0x58:                                    // CLI
        mode_Implied                  (cpu)
        oper_CLI                      (cpu)

    case 0x59:                                    // EOR $9876,Y
        mode_Absolute_Y               (cpu)
        oper_EOR                      (cpu)

    case 0x5a:                                    // PHY
        mode_Implied                  (cpu)
        oper_PHY                      (cpu)

    case 0x5b:                                    // TCD
        mode_Implied                  (cpu)
        oper_TCD                      (cpu)

    case 0x5c:                                    // JMP $FEDCBA
        mode_Absolute_Long            (cpu)
        oper_JMP                      (cpu)

    case 0x5d:                                    // EOR $9876,X
        mode_Absolute_X               (cpu)
        oper_EOR                      (cpu)

    case 0x5e:                                    // LSR $9876,X
        mode_Absolute_X               (cpu)
        oper_LSR                      (cpu)

    case 0x5f:                                    // EOR $FEDCBA,X
        mode_Absolute_Long_X          (cpu)
        oper_EOR                      (cpu)

    case 0x60:                                    // RTS
        mode_Implied                  (cpu)
        oper_RTS                      (cpu)

    case 0x61:                                    // ADC ($10,X)
        mode_DP_X_Indirect            (cpu)
        oper_ADC                      (cpu)

    case 0x62:                                    // PER LABEL
        mode_PC_Relative_Long         (cpu)
        oper_PER                      (cpu)

    case 0x63:                                    // ADC $32,S
        mode_S_Relative               (cpu)
        oper_ADC                      (cpu)

    case 0x64:                                    // STZ $10
        mode_DP                       (cpu)
        oper_STZ                      (cpu)

    case 0x65:                                    // ADC $10
        mode_DP                       (cpu)
        oper_ADC                      (cpu)

    case 0x66:                                    // ROR $10
        mode_DP                       (cpu)
        oper_ROR                      (cpu)

    case 0x67:                                    // ADC [$10]
        mode_DP_Indirect_Long         (cpu)
        oper_ADC                      (cpu)

    case 0x68:                                    // PLA
        mode_Implied                  (cpu)
        oper_PLA                      (cpu)

    case 0x69:                                    // ADC #$54
        mode_Immediate_flag_M         (cpu)
        oper_ADC                      (cpu)

    case 0x6a:                                    // ROR
        mode_Accumulator              (cpu)
        oper_ROR_A                    (cpu)

    case 0x6b:                                    // RTL
        mode_Implied                  (cpu)
        oper_RTL                      (cpu)

    case 0x6c:                                    // JMP ($1234)
        mode_Absolute_Indirect        (cpu)
        oper_JMP                      (cpu)

    case 0x6d:                                    // ADC $9876
        mode_Absolute_DBR             (cpu)
        oper_ADC                      (cpu)

    case 0x6e:                                    // ROR $9876
        mode_Absolute_DBR             (cpu)
        oper_ROR                      (cpu)

    case 0x6f:                                    // ADC $FEDBCA
        mode_Absolute_Long            (cpu)
        oper_ADC                      (cpu)

    case 0x70:                                    // BVS LABEL
        mode_PC_Relative              (cpu)
        oper_BVS                      (cpu)

    case 0x71:                                    // ADC ($10),Y
        mode_DP_Indirect_Y            (cpu)
        oper_ADC                      (cpu)

    case 0x72:                                    // ADC ($10)
        mode_DP_Indirect              (cpu)
        oper_ADC                      (cpu)

    case 0x73:                                    // ADC ($32,S),Y
        mode_S_Relative_Indirect_Y    (cpu)
        oper_ADC                      (cpu)

    case 0x74:                                    // STZ $10,X
        mode_DP_X                     (cpu)
        oper_STZ                      (cpu)

    case 0x75:                                    // ADC $10,X
        mode_DP_X                     (cpu)
        oper_ADC                      (cpu)

    case 0x76:                                    // ROR $10,X
        mode_DP_X                     (cpu)
        oper_ROR                      (cpu)

    case 0x77:                                    // ADC [$10],Y
        mode_DP_Indirect_Long_Y       (cpu)
        oper_ADC                      (cpu)

    case 0x78:                                    // SEI
        mode_Implied                  (cpu)
        oper_SEI                      (cpu)

    case 0x79:                                    // ADC $9876,Y
        mode_Absolute_Y               (cpu)
        oper_ADC                      (cpu)

    case 0x7a:                                    // PLY
        mode_Implied                  (cpu)
        oper_PLY                      (cpu)

    case 0x7b:                                    // TDC
        mode_Implied                  (cpu)
        oper_TDC                      (cpu)

    case 0x7c:                                    // JMP ($1234,X)
        mode_Absolute_X_Indirect      (cpu)
        oper_JMP                      (cpu)

    case 0x7d:                                    // ADC $9876,X
        mode_Absolute_X               (cpu)
        oper_ADC                      (cpu)

    case 0x7e:                                    // ROR $9876,X
        mode_Absolute_X               (cpu)
        oper_ROR                      (cpu)

    case 0x7f:                                    // ADC $FEDCBA,X
        mode_Absolute_Long_X          (cpu)
        oper_ADC                      (cpu)

    case 0x80:                                    // BRA LABEL
        mode_PC_Relative              (cpu)
        oper_BRA                      (cpu)

    case 0x81:                                    // STA ($10,X)
        mode_DP_X_Indirect            (cpu)
        oper_STA                      (cpu)

    case 0x82:                                    // BRL LABEL
        mode_PC_Relative_Long         (cpu)
        oper_BRL                      (cpu)

    case 0x83:                                    // STA $32,S
        mode_S_Relative               (cpu)
        oper_STA                      (cpu)

    case 0x84:                                    // STY $10
        mode_DP                       (cpu)
        oper_STY                      (cpu)

    case 0x85:                                    // STA $10
        mode_DP                       (cpu)
        oper_STA                      (cpu)

    case 0x86:                                    // STX $10
        mode_DP                       (cpu)
        oper_STX                      (cpu)

    case 0x87:                                    // STA [$10]
        mode_DP_Indirect_Long         (cpu)
        oper_STA                      (cpu)

    case 0x88:                                    // DEY
        mode_Implied                  (cpu)
        oper_DEY                      (cpu)

    case 0x89:                                    // BIT #$54
        mode_Immediate_flag_M         (cpu)
        oper_BIT                      (cpu)

    case 0x8a:                                    // TXA
        mode_Implied                  (cpu)
        oper_TXA                      (cpu)

    case 0x8b:                                    // PHB
        mode_Implied                  (cpu)
        oper_PHB                      (cpu)

    case 0x8c:                                    // STY $9876
        mode_Absolute_DBR             (cpu)
        oper_STY                      (cpu)

    case 0x8d:                                    // STA $9876
        mode_Absolute_DBR             (cpu)
        oper_STA                      (cpu)

    case 0x8e:                                    // STX $9876
        mode_Absolute_DBR             (cpu)
        oper_STX                      (cpu)

    case 0x8f:                                    // STA $FEDBCA
        mode_Absolute_Long            (cpu)
        oper_STA                      (cpu)

    case 0x90:                                    // BCC LABEL
        mode_PC_Relative              (cpu)
        oper_BCC                      (cpu)

    case 0x91:                                    // STA ($10),Y
        mode_DP_Indirect_Y            (cpu)
        oper_STA                      (cpu)

    case 0x92:                                    // STA ($10)
        mode_DP_Indirect              (cpu)
        oper_STA                      (cpu)

    case 0x93:                                    // STA ($32,S),Y
        mode_S_Relative_Indirect_Y    (cpu)
        oper_STA                      (cpu)

    case 0x94:                                    // STY $10,X
        mode_DP_X                     (cpu)
        oper_STY                      (cpu)

    case 0x95:                                    // STA $10,X
        mode_DP_X                     (cpu)
        oper_STA                      (cpu)

    case 0x96:                                    // STX $10,Y
        mode_DP_Y                     (cpu)
        oper_STX                      (cpu)

    case 0x97:                                    // STA [$10],Y
        mode_DP_Indirect_Long_Y       (cpu)
        oper_STA                      (cpu)

    case 0x98:                                    // TYA
        mode_Implied                  (cpu)
        oper_TYA                      (cpu)

    case 0x99:                                    // STA $9876,Y
        mode_Absolute_Y               (cpu)
        oper_STA                      (cpu)

    case 0x9a:                                    // TXS
        mode_Implied                  (cpu)
        oper_TXS                      (cpu)

    case 0x9b:                                    // TXY
        mode_Implied                  (cpu)
        oper_TXY                      (cpu)

    case 0x9c:                                    // STZ $9876
        mode_Absolute_DBR             (cpu)
        oper_STZ                      (cpu)

    case 0x9d:                                    // STA $9876,X
        mode_Absolute_X               (cpu)
        oper_STA                      (cpu)

    case 0x9e:                                    // STZ $9876,X
        mode_Absolute_X               (cpu)
        oper_STZ                      (cpu)

    case 0x9f:                                    // STA $FEDCBA,X
        mode_Absolute_Long_X          (cpu)
        oper_STA                      (cpu)

    case 0xa0:                                    // LDY #$54
        mode_Immediate_flag_X         (cpu)
        oper_LDY                      (cpu)

    case 0xa1:                                    // LDA ($10,X)
        mode_DP_X_Indirect            (cpu)
        oper_LDA                      (cpu)

    case 0xa2:                                    // LDX #$54
        mode_Immediate_flag_X         (cpu)
        oper_LDX                      (cpu)

    case 0xa3:                                    // LDA $32,S
        mode_S_Relative               (cpu)
        oper_LDA                      (cpu)

    case 0xa4:                                    // LDY $10
        mode_DP                       (cpu)
        oper_LDY                      (cpu)

    case 0xa5:                                    // LDA $10
        mode_DP                       (cpu)
        oper_LDA                      (cpu)

    case 0xa6:                                    // LDX $10
        mode_DP                       (cpu)
        oper_LDX                      (cpu)

    case 0xa7:                                    // LDA [$10]
        mode_DP_Indirect_Long         (cpu)
        oper_LDA                      (cpu)

    case 0xa8:                                    // TAY
        mode_Implied                  (cpu)
        oper_TAY                      (cpu)

    case 0xa9:                                    // LDA #$54
        mode_Immediate_flag_M         (cpu)
        oper_LDA                      (cpu)

    case 0xaa:                                    // TAX
        mode_Implied                  (cpu)
        oper_TAX                      (cpu)

    case 0xab:                                    // PLB
        mode_Implied                  (cpu)
        oper_PLB                      (cpu)

    case 0xac:                                    // LDY $9876
        mode_Absolute_DBR             (cpu)
        oper_LDY                      (cpu)

    case 0xad:                                    // LDA $9876
        mode_Absolute_DBR             (cpu)
        oper_LDA                      (cpu)

    case 0xae:                                    // LDX $9876
        mode_Absolute_DBR             (cpu)
        oper_LDX                      (cpu)

    case 0xaf:                                    // LDA $FEDBCA
        mode_Absolute_Long            (cpu)
        oper_LDA                      (cpu)

    case 0xb0:                                    // BCS LABEL
        mode_PC_Relative              (cpu)
        oper_BCS                      (cpu)

    case 0xb1:                                    // LDA ($10),Y
        mode_DP_Indirect_Y            (cpu)
        oper_LDA                      (cpu)

    case 0xb2:                                    // LDA ($10)
        mode_DP_Indirect              (cpu)
        oper_LDA                      (cpu)

    case 0xb3:                                    // LDA ($32,S),Y
        mode_S_Relative_Indirect_Y    (cpu)
        oper_LDA                      (cpu)

    case 0xb4:                                    // LDY $10,X
        mode_DP_X                     (cpu)
        oper_LDY                      (cpu)

    case 0xb5:                                    // LDA $10,X
        mode_DP_X                     (cpu)
        oper_LDA                      (cpu)

    case 0xb6:                                    // LDX $10,Y
        mode_DP_Y                     (cpu)
        oper_LDX                      (cpu)

    case 0xb7:                                    // LDA [$10],Y
        mode_DP_Indirect_Long_Y       (cpu)
        oper_LDA                      (cpu)

    case 0xb8:                                    // CLV
        mode_Implied                  (cpu)
        oper_CLV                      (cpu)

    case 0xb9:                                    // LDA $9876,Y
        mode_Absolute_Y               (cpu)
        oper_LDA                      (cpu)

    case 0xba:                                    // TSX
        mode_Implied                  (cpu)
        oper_TSX                      (cpu)

    case 0xbb:                                    // TYX
        mode_Implied                  (cpu)
        oper_TYX                      (cpu)

    case 0xbc:                                    // LDY $9876,X
        mode_Absolute_X               (cpu)
        oper_LDY                      (cpu)

    case 0xbd:                                    // LDA $9876,X
        mode_Absolute_X               (cpu)
        oper_LDA                      (cpu)

    case 0xbe:                                    // LDX $9876,Y
        mode_Absolute_Y               (cpu)
        oper_LDX                      (cpu)

    case 0xbf:                                    // LDA $FEDCBA,X
        mode_Absolute_Long_X          (cpu)
        oper_LDA                      (cpu)

    case 0xc0:                                    // CPY #$54
        mode_Immediate_flag_X         (cpu)
        oper_CPY                      (cpu)

    case 0xc1:                                    // CMP ($10,X)
        mode_DP_X_Indirect            (cpu)
        oper_CMP                      (cpu)

    case 0xc2:                                    // REP #$12
        mode_Immediate                (cpu)
        oper_REP                      (cpu)

    case 0xc3:                                    // CMP $32,S
        mode_S_Relative               (cpu)
        oper_CMP                      (cpu)

    case 0xc4:                                    // CPY $10
        mode_DP                       (cpu)
        oper_CPY                      (cpu)

    case 0xc5:                                    // CMP $10
        mode_DP                       (cpu)
        oper_CMP                      (cpu)

    case 0xc6:                                    // DEC $10
        mode_DP                       (cpu)
        oper_DEC                      (cpu)

    case 0xc7:                                    // CMP [$10]
        mode_DP_Indirect_Long         (cpu)
        oper_CMP                      (cpu)

    case 0xc8:                                    // INY
        mode_Implied                  (cpu)
        oper_INY                      (cpu)

    case 0xc9:                                    // CMP #$54
        mode_Immediate_flag_M         (cpu)
        oper_CMP                      (cpu)

    case 0xca:                                    // DEX
        mode_Implied                  (cpu)
        oper_DEX                      (cpu)

    case 0xcb:                                    // WAI
        mode_Implied                  (cpu)
        oper_WAI                      (cpu)

    case 0xcc:                                    // CPY $9876
        mode_Absolute_DBR             (cpu)
        oper_CPY                      (cpu)

    case 0xcd:                                    // CMP $9876
        mode_Absolute_DBR             (cpu)
        oper_CMP                      (cpu)

    case 0xce:                                    // DEC $9876
        mode_Absolute_DBR             (cpu)
        oper_DEC                      (cpu)

    case 0xcf:                                    // CMP $FEDBCA
        mode_Absolute_Long            (cpu)
        oper_CMP                      (cpu)

    case 0xd0:                                    // BNE LABEL
        mode_PC_Relative              (cpu)
        oper_BNE                      (cpu)

    case 0xd1:                                    // CMP ($10),Y
        mode_DP_Indirect_Y            (cpu)
        oper_CMP                      (cpu)

    case 0xd2:                                    // CMP ($10)
        mode_DP_Indirect              (cpu)
        oper_CMP                      (cpu)

    case 0xd3:                                    // CMP ($32,S),Y
        mode_S_Relative_Indirect_Y    (cpu)
        oper_CMP                      (cpu)

    case 0xd4:                                    // PEI $12
        mode_DP                       (cpu)
        oper_PEI                      (cpu)

    case 0xd5:                                    // CMP $10,X
        mode_DP_X                     (cpu)
        oper_CMP                      (cpu)

    case 0xd6:                                    // DEC $10,X
        mode_DP_X                     (cpu)
        oper_DEC                      (cpu)

    case 0xd7:                                    // CMP [$10],Y
        mode_DP_Indirect_Long_Y       (cpu)
        oper_CMP                      (cpu)

    case 0xd8:                                    // CLD
        mode_Implied                  (cpu)
        oper_CLD                      (cpu)

    case 0xd9:                                    // CMP $9876,Y
        mode_Absolute_Y               (cpu)
        oper_CMP                      (cpu)

    case 0xda:                                    // PHX
        mode_Implied                  (cpu)
        oper_PHX                      (cpu)

    case 0xdb:                                    // STP
        mode_Implied                  (cpu)
        oper_STP                      (cpu)

    case 0xdc:                                    // JMP [$1234]
        mode_Absolute_Indirect_Long   (cpu)
        oper_JMP                      (cpu)

    case 0xdd:                                    // CMP $9876,X
        mode_Absolute_X               (cpu)
        oper_CMP                      (cpu)

    case 0xde:                                    // DEC $9876,X
        mode_Absolute_X               (cpu)
        oper_DEC                      (cpu)

    case 0xdf:                                    // CMP $FEDCBA,X
        mode_Absolute_Long_X          (cpu)
        oper_CMP                      (cpu)

    case 0xe0:                                    // CPX #$54
        mode_Immediate_flag_X         (cpu)
        oper_CPX                      (cpu)

    case 0xe1:                                    // SBC ($10,X)
        mode_DP_X_Indirect            (cpu)
        oper_SBC                      (cpu)

    case 0xe2:                                    // SEP #$12
        mode_Immediate                (cpu)
        oper_SEP                      (cpu)

    case 0xe3:                                    // SBC $32,S
        mode_S_Relative               (cpu)
        oper_SBC                      (cpu)

    case 0xe4:                                    // CPX $10
        mode_DP                       (cpu)
        oper_CPX                      (cpu)

    case 0xe5:                                    // SBC $10
        mode_DP                       (cpu)
        oper_SBC                      (cpu)

    case 0xe6:                                    // INC $10
        mode_DP                       (cpu)
        oper_INC                      (cpu)

    case 0xe7:                                    // SBC [$10]
        mode_DP_Indirect_Long         (cpu)
        oper_SBC                      (cpu)

    case 0xe8:                                    // INX
        mode_Implied                  (cpu)
        oper_INX                      (cpu)

    case 0xe9:                                    // SBC #$54
        mode_Immediate_flag_M         (cpu)
        oper_SBC                      (cpu)

    case 0xea:                                    // NOP
        mode_Implied                  (cpu)
        oper_NOP                      (cpu)

    case 0xeb:                                    // XBA
        mode_Implied                  (cpu)
        oper_XBA                      (cpu)

    case 0xec:                                    // CPX $9876
        mode_Absolute_DBR             (cpu)
        oper_CPX                      (cpu)

    case 0xed:                                    // SBC $9876
        mode_Absolute_DBR             (cpu)
        oper_SBC                      (cpu)

    case 0xee:                                    // INC $9876
        mode_Absolute_DBR             (cpu)
        oper_INC                      (cpu)

    case 0xef:                                    // SBC $FEDBCA
        mode_Absolute_Long            (cpu)
        oper_SBC                      (cpu)

    case 0xf0:                                    // BEQ LABEL
        mode_PC_Relative              (cpu)
        oper_BEQ                      (cpu)

    case 0xf1:                                    // SBC ($10),Y
        mode_DP_Indirect_Y            (cpu)
        oper_SBC                      (cpu)

    case 0xf2:                                    // SBC ($10)
        mode_DP_Indirect              (cpu)
        oper_SBC                      (cpu)

    case 0xf3:                                    // SBC ($32,S),Y
        mode_S_Relative_Indirect_Y    (cpu)
        oper_SBC                      (cpu)

    case 0xf4:                                    // PEA #$1234
        mode_Immediate                (cpu)
        oper_PEA                      (cpu)

    case 0xf5:                                    // SBC $10,X
        mode_DP_X                     (cpu)
        oper_SBC                      (cpu)

    case 0xf6:                                    // INC $10,X
        mode_DP_X                     (cpu)
        oper_INC                      (cpu)

    case 0xf7:                                    // SBC [$10],Y
        mode_DP_Indirect_Long_Y       (cpu)
        oper_SBC                      (cpu)

    case 0xf8:                                    // SED
        mode_Implied                  (cpu)
        oper_SED                      (cpu)

    case 0xf9:                                    // SBC $9876,Y
        mode_Absolute_Y               (cpu)
        oper_SBC                      (cpu)

    case 0xfa:                                    // PLX
        mode_Implied                  (cpu)
        oper_PLX                      (cpu)

    case 0xfb:                                    // XCE
        mode_Implied                  (cpu)
        oper_XCE                      (cpu)

    case 0xfc:                                    // JSR ($1234,X)
        mode_Absolute_X_Indirect      (cpu)
        oper_JSR                      (cpu)

    case 0xfd:                                    // SBC $9876,X
        mode_Absolute_X               (cpu)
        oper_SBC                      (cpu)

    case 0xfe:                                    // INC $9876,X
        mode_Absolute_X               (cpu)
        oper_INC                      (cpu)

    case 0xff:                                    // SBC $FEDCBA,X
        mode_Absolute_Long_X          (cpu)
        oper_SBC                      (cpu)


    }
}

