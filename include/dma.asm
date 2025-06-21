.enum DMA_TO_VRAM_SETTING
    word
    word_fixed
    lobyte
    lobyte_fixed
    hibyte
    hibyte_fixed
.endenum

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
