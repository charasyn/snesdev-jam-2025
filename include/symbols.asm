; This file is read from `tools/sources_from_symbolsasm.py` to determine what
; ASM files should be built and linked into the final output .sfc file.
; The files will be linked in the order that they appear here, on the lines
; which contain `; file: foo.asm`

; file: ram.asm
.global dmaFifoLastWritten
.global dmaFifoLastRead
.global frameToDisplay
.global frameCurrentlyDisplaying
.global paletteUpdateSetting
.global oamDmaSourceAddress
.global nmiDmaBudget
.global HWM_INIDISP
.global HWM_OBSEL
.global HWM_MOSAIC
.global HWM_HDMAEN
.global HWM_NMITIMEN
.global dmaFifo
.global paletteBuffer
.global oamBuffer0
.global oamBuffer1
.global pad1Held
.global pad1JustPressed
.global coroutineOrderLLHeadUsed
.global coroutineOrderLLHeadUnused
.global coroutineOrderLL
.global coroutineStateTable
.global coroutinePreviousSp
.global coroutinePreviousDp

; file: main.asm
.global Main

; file: system.asm
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
