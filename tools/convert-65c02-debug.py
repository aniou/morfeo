#!/usr/bin/python3

import fileinput
import re

addr_mode = {
    'abs': 'Absolute',
    'abs,X': 'Absolute_X',
    'abs,Y': 'Absolute_Y',
    'acc': 'Accumulator',
    'imm': 'Immediate',
    'imp': 'Implied',
    'dir': 'DP',
    'dir,X': 'DP_X',
    'dir,Y': 'DP_Y',
    '(dir,X)': 'DP_X_Indirect',
    '(dir)': 'DP_Indirect',
    '[dir]': 'DP_Indirect_Long',
    '(dir),Y': 'DP_Indirect_Y',
    '[dir],Y': 'DP_Indirect_Long_Y',
    '(abs,X)': 'Absolute_X_Indirect',
    '(abs)': 'Absolute_Indirect',
    '[abs]': 'Absolute_Indirect_Long',
    'long': 'Absolute_Long',
    'long,X': 'Absolute_Long_X',
    'src,dest': 'BlockMove',
    'rel8': 'PC_Relative',
    'rel16': 'PC_Relative_Long',
    'stk,S': 'S_Relative',
    '(stk,S),Y': 'S_Relative_Indirect_Y',
    'rel': 'PC_Relative',
    '(zp,X)': 'ZP_X_Indirect',
    'zp': 'ZP',
    'zp,X': 'ZP_X',
    'zp,Y': 'ZP_Y',
    'zp,rel': 'ZP_and_Relative',
    '(zp),Y': 'ZP_Indirect_Y',
    '(zp)': 'ZP_Indirect',
}


#counter = 0
for line in fileinput.input("w65c02s_commands-ordered.txt", openhook=fileinput.hook_encoded("utf-8")):
    match = re.search(r'^[0-9A-F][0-9A-F] ', line)
    if not match:
        continue

    t = line.split()
    if len(t) < 2:
        print("ERR: bad line %s" % (line))
        continue

    #print(t)

    opcode = int(t[0], 16)
    #while counter < opcode:
    #    print("\t\t{0x%02x, \"XXX\", m_Implied,                   1, 1, c.xxx},\t// illegal/unknown opcode" % counter)
    #    counter+=1


    opname = t[5].upper()

    desc   = "// %-14s %s  %s" % (' '.join(t[5:]), t[1], t[2])
    cycles = t[2][0:1]

    if opname == 'BBS':
        opname="BBS%s" % t[6].split(',')[0]
        
    if opname == 'BBR':
        opname="BBR%s" % t[6].split(',')[0]

    if opname == 'RMB':
        opname="RMB%s" % t[6].split(',')[0]

    if opname == 'SMB':
        opname="SMB%s" % t[6].split(',')[0]

    size    = int(t[1])
    mode    = addr_mode[t[3]]

    if opname=='PER':
        mode    = 'PC_Relative_Long'

    if opname == '-':
        opname="ILL"
        mode  ="Illegal"

    #counter+=1

    hexopcode="0x%02x" % opcode
    # {0x00, "brk", m_Implied, 1, 8, c.brk},
    # mode=mode+','
    #print("\t\t{0x%02x, \"%s\", %-28s %i, %s, c.%s},\t%s" % (opcode, opname, mode, size, cycles, opname, desc))
    #print(hexopcode, cycles, opname, size, mode, desc)
    print("    { %5s, %i, .%-20s }, // %02x" % ("." + opname, size, mode, opcode))
