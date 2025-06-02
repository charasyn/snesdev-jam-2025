.struct COROUTINE_STATE
    sleepTime .word
    stackUsed .word
    stack .byte 16
.endstruct
.define NUM_COROUTINES 16

.segment "HIRAM"
coroutineOrderLLHead:
    .res 2
coroutineOrderLL:
    .res NUM_COROUTINES
coroutineStateTable:
    .res .sizeof(COROUTINE_STATE) * NUM_COROUTINES

.segment "BANK00"
CoroutineInit:
    rep #$31
    phd
    tdc
    adc #.loword(-16)
    tcd

    lda #.loword(-1)
    sta coroutineOrderLLHead
    sep #$20
    lda #$80
    ldx #(NUM_COROUTINES - 1)
@loop:
    sta coroutineOrderLL,x
    dex
    bpl @loop

    pld
    rtl
