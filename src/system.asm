.include "all.asm"

.segment "HIRAM"

HWM_OBSEL:
    .res 1

HWM_MOSAIC:
    .res 1

; ...

HWM_NMITIMEN:
    .res 1

pad1Held:
    .res 2

pad1JustPressed:
    .res 2

.segment "BANK00"

EnableNmiAndAutoJoypad:
    sep #$20
    lda #$81
    sta f:NMITIMEN
    sta HWM_NMITIMEN
    rep #$31
    stz pad1Held
    stz pad1JustPressed
    rtl
