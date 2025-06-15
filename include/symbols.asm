; This file is read from `tools/sources_from_symbolsasm.py` to determine what
; ASM files should be built and linked into the final output .sfc file.
; The files will be linked in the order that they appear here, on the lines
; which contain `; file: foo.asm`

; file: main.asm
.global ResetVector
.global BrkVector
.global IrqVector
.global NmiVector
.global Main
.global ResetPpuState
.global Zeros

; file: system.asm
.global EnableNmiAndAutoJoypad

; file: dma.asm
.global DmaToVramImmediate

; file: coroutines.asm
.global CoroutineInit
.global CoroutineSpawn
.global CoroutineSwitchExecutionTo
