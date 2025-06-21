.include "all.asm"
.struct DMA_TO_VRAM_SETTING_CONFIG
    dmap .byte
    bbad .byte
    vmain .byte
.endstruct

.segment "HIRAM"
dmaToVramQueue:

.segment "BANK00"
dmaToVramTypeTable:
    .byte $01, .lobyte(VMADDL), $80 ; word
    .byte $09, .lobyte(VMADDL), $80 ; word_fixed
    .byte $00, .lobyte(VMADDL), $00 ; lobyte
    .byte $08, .lobyte(VMADDL), $00 ; lobyte_fixed
    .byte $00, .lobyte(VMADDH), $80 ; hibyte
    .byte $08, .lobyte(VMADDH), $80 ; hibyte_fixed

DmaToVramImmediate:
    rtl
