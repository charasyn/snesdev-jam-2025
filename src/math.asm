.include "all.asm"

.segment "BANK00"

; WARNING: Not C calling convention compliant
; Parameters:
;   A = 16-bit multiplicand
;   Y =  8-bit multiplier (in 16-bit mode)
;   P has M and X bits clear (16-bit)
; Return:
;   A = 16-bit result
; Preserves X register, doesn't touch DP.
Mult16x8:
    .i16
    .a16
    phd
    xba
    pha
    lda #WRMPYA & $FF00
    tcd
    sty z:<WRMPYA
    ; WARNING! Do not write WRMPYB while a multiplication is ongoing;
    ; it will not work. You need to write 9+ cycles after writing it
    ; the first time.
    sep #$20
    pla
    beq @upperByteZero
    sta z:<WRMPYB
    pla
    nop
    ldy z:<RDMPYL
    sta z:<WRMPYB
    rep #$20
    tya
    xba
    and #$ff00
    clc
    adc z:<RDMPYL
    pld
    rtl
@upperByteZero:
    pla
    sta z:<WRMPYB
    rep #$20
    pld
    lda f:RDMPYL
    rtl
