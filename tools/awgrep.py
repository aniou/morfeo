#!/usr/bin/python3 -tt

"""
grep-alike tool that shows a procedure in which regexp was found
"""

import fileinput
import sys
import re

if len(sys.argv) < 2:
    print("Usage: awgrep.py [regexp] [file1 [file2 [file3...]]]")
    sys.exit(1)

comment  = False
proc     = ""
pattern  = re.compile(sys.argv[1])

for f in sys.argv[2:]:
    for line in fileinput.input(f, openhook=fileinput.hook_encoded("utf-8")):

        line = line.rstrip()
        if line.startswith('/*'):
            comment = True

        if line.endswith('*/'):
            comment = False

        if comment:
            continue

        match = re.search(r'^([0-9A-Za-z_]+) +::.+proc', line)
        if match:
            proc = match.group(1)   

        match = re.search(pattern, line)
        if match:
            line = line.lstrip()
            if line.startswith('//'):
                continue

            print("%-32s %s" % (proc, line))
