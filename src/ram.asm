;;; symbolhandler: export-all
.include "all.asm"

.segment "ZPRAM"
dmaFifoLastWritten: .res 1
dmaFifoLastRead: .res 1
frameToDisplay: .res 1
frameCurrentlyDisplaying: .res 1
paletteUpdateSetting: .res 2
oamDmaSourceAddress: .res 2

; Note - DMA budget is stored in memory as a negative value and we add to it
; until it reaches zero.
nmiDmaBudget: .res 2

; ...

HWM_HDMAEN: .res 1

.segment "LORAM"

dmaFifo: .res 256

.segment "HIRAM"

HWM_INIDISP: .res 1
HWM_OBSEL: .res 1
HWM_MOSAIC: .res 1
HWM_BGMODE: .res 1
HWM_BG12NBA: .res 1
HWM_BG34NBA: .res 1
HWM_NMITIMEN: .res 1

paletteBuffer: .res (256 * 2)
oamBuffer0: .res 544
oamBuffer1: .res 544

bg3Buffer: .res (32 * 28 * 2)
bg3BufferDirty: .res 2

pad1Held: .res 2
pad1JustPressed: .res 2

coroutineOrderLLHeadUsed: .res 2
coroutineOrderLLHeadUnused: .res 2
coroutineOrderLL: .res NUM_COROUTINES
coroutineStateTable: .res .sizeof(COROUTINE_STATE) * NUM_COROUTINES
coroutinePreviousSp: .res 2
coroutinePreviousDp: .res 2

windowFrontPtr: .res 2
windowDefinitionToPtr: .res NUM_WINDOW_DEFINITIONS
windowActiveStateTable: .res .sizeof(WINDOW_ACTIVE_STATE) * NUM_ACTIVE_WINDOWS
windowDisplayBuffer: .res 2 * MAX_WINDOW_AREA * NUM_ACTIVE_WINDOWS
