; This file is read from `tools/sources_from_symbolsasm.py` to determine what
; ASM files should be built and linked into the final output .sfc file.
; The files will be linked in the order that they appear here, on the lines
; which contain `; file: foo.asm`

; file: main.asm
.global Main

; file: system.asm
.global dmaFifoLastRead
.global dmaFifoLastWritten
.global paletteBuffer
.global pad1Held
.global pad1JustPressed
.global dmaFifo

.global ResetVector
.global BrkVector
.global IrqVector
.global NmiVector
.global ResetPpuState
.global Zeros
.global DisableScreen
.global EnableScreenAndSetBrightness
.global EnableNmiAndAutoJoypad
.global UpdatePalette
.global CompleteFrame

; file: dma.asm
.global dmaToVramTypeTable
.global QueueDmaToVram
.global WaitForDmaComplete

; file: coroutines.asm
.global CoroutineInit
.global CoroutineSpawn
.global CoroutineSwitchExecutionTo

; from data:
.global test_tiles
.global test_map
.global test_palette
