#!/usr/bin/env python3
'''
This script gets a list of files to assemble based on the contents of
`include/symbols.asm` - this allows for linkage order to be controlled from
symbols.asm instead of needing to edit the makefile each time.
Is it necessary? No. Did I want to do it? Yeah
'''

import pathlib
import re
from typing import Iterator

LINE_RE = re.compile( r'^; file: (\w+\.asm)$' )

def getFilesToAssemble(fSymbolsAsm: Iterator[str]) -> list[str]:
    ret = []
    for line in fSymbolsAsm:
        if m := LINE_RE.match(line):
            ret.append(f'src/{m.group(1)}')
    return ret

def main():
    projectDir = pathlib.Path(__file__).parent.parent
    with open(projectDir / "include" / "symbols.asm") as fSymbolsAsm:
        output = getFilesToAssemble(fSymbolsAsm)
    print(' '.join(output))

if __name__ == '__main__':
    main()
