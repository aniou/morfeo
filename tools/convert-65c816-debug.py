#!/usr/bin/python3

import fileinput
import re
import sys

addr_mode = {
    'abs': 'mode_Absolute_DBR',
    'abs,X': 'mode_Absolute_X',
    'abs,Y': 'mode_Absolute_Y',
    'acc': 'mode_Accumulator',
    'imm': 'mode_Immediate',
    'imp': 'mode_Implied',
    'dir': 'mode_DP',
    'dir,X': 'mode_DP_X',
    'dir,Y': 'mode_DP_Y',
    '(dir,X)': 'mode_DP_X_Indirect',
    '(dir)': 'mode_DP_Indirect',
    '[dir]': 'mode_DP_Indirect_Long',
    '(dir),Y': 'mode_DP_Indirect_Y',
    '[dir],Y': 'mode_DP_Indirect_Long_Y',
    '(abs,X)': 'mode_Absolute_X_Indirect',
    '(abs)': 'mode_Absolute_Indirect',
    '[abs]': 'mode_Absolute_Indirect_Long',
    'long': 'mode_Absolute_Long',
    'long,X': 'mode_Absolute_Long_X',
    'src,dest': 'mode_BlockMove',
    'rel8': 'mode_PC_Relative',
    'rel16': 'mode_PC_Relative_Long',
    'stk,S': 'mode_S_Relative',
    '(stk,S),Y': 'mode_S_Relative_Indirect_Y'
}


print("""
CPU_w65c816_opcodes : [256]CPU_w65c816_debug = {""")

#counter = 0
for line in fileinput.input(sys.argv[1], openhook=fileinput.hook_encoded("utf-8")):
    match = re.search(r'^[0-9A-F][0-9A-F] ', line)
    if not match:
        continue

    t = line.split()
    if len(t) < 2:
        print("ERR: bad line %s" % (line))
        continue

    #print(t)

    opcode = int(t[0], 16)


    opname = t[6].upper()
    desc   = "// %s" % ' '.join(t[6:])
    cycles = t[2][0:1]

    mode    = addr_mode[t[3]]

    if opname=='PER':
        mode    = 'mode_PC_Relative_Long'

    if opname=='JMP' and mode=='mode_Absolute_DBR':
        mode    = 'mode_Absolute'

    if opname=='JSR' and mode=='mode_Absolute_DBR':
        mode    = 'mode_Absolute'

    if mode.endswith('_DBR') or mode.endswith('_PBR'):
        mode = mode[:-4]

    mode = mode[5:] # strip mode_ from beginning
    hexopcode="0x%02x" % opcode
    print("    { %5s, .%-22s }, // %02x" % ("." + opname, mode, opcode))

print("""
}
""")
