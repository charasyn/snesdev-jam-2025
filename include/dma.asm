.enum DMA_TO_VRAM_SETTING
    word = 0
    word_fixed = 3
    lobyte = 6
    lobyte_fixed = 9
    hibyte = 12
    hibyte_fixed = 15
.endenum

.struct DMA_TO_VRAM_SETTING_CONFIG
    dmap .byte
    bbad .byte
    vmain .byte
.endstruct

; Notes on DMA channel allocation
; The DMA channels will be used as such:
; Ch.0: used for normal DMA by non-interrupt code
; Ch.1: used for normal DMA by interrupt handler
; Ch.2: HDMA
; Ch.3: HDMA
; Ch.4: HDMA
; Ch.5: HDMA
; Ch.6: HDMA
; Ch.7: HDMA

.struct VRAMDMA_ENTRY
    sizeInBytes .word
    destAddr .word
    sourceAddr .word
    sourceBank .byte
    paramOffset .byte
.endstruct

; Note - DMA budget is stored in memory as a negative value and we add to it
; until it reaches zero.
; This is too small but we'll use it for now, until I have calculated an actual
; value.
DMA_BUDGET_TOTAL = 3800
DMA_BUDGET_COST_PER_DMA = 81
DMA_BUDGET_COST_CHANGE_FRAME = 544 + DMA_BUDGET_COST_PER_DMA

; When DMA transfers are larger than this size, they will be split into
; multiple transfers of this size. Must be a multiple of 4.
DMA_CHUNK_SIZE = 1024
