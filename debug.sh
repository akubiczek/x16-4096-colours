#!/bin/bash

/usr/local/bin/cl65 -t cx16 -l ./build/main.lst -o ./build/main.prg -u __EXEHDR__ ./src/main.asm && /Applications/CommanderX16/x16emu -scale 2 -prg ./build/main.prg -run -debug