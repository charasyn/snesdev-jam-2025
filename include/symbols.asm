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
.global HWM_HDMAEN
.global dmaFifo
.global HWM_INIDISP
.global HWM_OBSEL
.global HWM_MOSAIC
.global HWM_BGMODE
.global HWM_BG12NBA
.global HWM_BG34NBA
.global HWM_NMITIMEN
.global paletteBuffer
.global oamBuffer0
.global oamBuffer1
.global bg3Buffer
.global bg3BufferDirty
.global pad1Held
.global pad1JustPressed
.global coroutineOrderLLHeadUsed
.global coroutineOrderLLHeadUnused
.global coroutineOrderLL
.global coroutineStateTable
.global coroutinePreviousSp
.global coroutinePreviousDp
.global windowFrontPtr
.global windowDefinitionToActiveIdx
.global windowActiveStateTable
.global windowDisplayBuffer

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
.global PpuSetBg3Map
.global PpuSetBg3Tile
.global PpuSetMode
.global PpuSetTmTs

; file: dma.asm
.global dmaToVramTypeTable
.global QueueDmaToVram
.global WaitForDmaComplete

; file: coroutines.asm
.global CoroutineInit
.global CoroutineSpawn
.global CoroutineSwitchExecutionTo

; file: math.asm
.global Mult16x8

; file: windows.asm
.global WindowInit
.global WindowRedrawByDefinitionId
.global WindowOpenByDefinitionId
.global WindowActiveDrawCharacter
.global WindowActiveCursorNewline

; file: textengine.asm
.global TextParse

; from data:
.global Asset_MapTest_tiles
.global Asset_MapTest_map
.global Asset_MapTest_palette
.global Asset_TextGraphics_tiles
.global Asset_TextGraphics_tiles_size
.global Asset_TextGraphics_palette
.global Asset_TextGraphics_palette_size
