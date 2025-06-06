.include "all.asm"

.struct COROUTINE_STATE
    sleepTime .word
    stackUsed .word
    stack .byte 16
.endstruct
.define NUM_COROUTINES 16

.segment "HIRAM"
coroutineOrderLLHeadUsed:
    .res 2
coroutineOrderLLHeadUnused:
    .res 2
coroutineOrderLL:
    .res NUM_COROUTINES
coroutineStateTable:
    .res .sizeof(COROUTINE_STATE) * NUM_COROUTINES
coroutinePreviousSp:
    .res 2
coroutinePreviousDp:
    .res 2

.segment "BANK00"
CoroutineInit:
    rep #$31
    phd
    tdc
    adc #.loword(-16)
    tcd

    lda #$00ff
    sta coroutineOrderLLHeadUsed
    sep #$20
    ldx #(NUM_COROUTINES - 1)
    stx coroutineOrderLLHeadUnused
    txa
@loop:
    dec a
    sta coroutineOrderLL,x
    dex
    bpl @loop
    rep #$30

    lda #$ffff
    sta coroutinePreviousSp
    sta coroutinePreviousDp

    pld
    rtl

; Parameters:
; DP[$04] = Code address to start execution
CoroutineSpawn:
    rep #$31
    phd
    tdc
    adc #.loword(-16)
    tcd

    ; Allocate coroutine table entry
    ; This is done by taking the head of the "unused" linked list
    ; and moving it to the head of the "used" linked list.
    ldx coroutineOrderLLHeadUnused
    cpx #$00ff
@outOfSlots:
    beq @outOfSlots
    lda coroutineOrderLL,x
    and #$00ff
    sta coroutineOrderLLHeadUnused
    sep #$20
    lda coroutineOrderLLHeadUsed
    sta coroutineOrderLL,x
    rep #$20
    stx coroutineOrderLLHeadUsed

    ; Set up the coroutineStateTable entry for this coroutine,
    ; including storing the (destination address - 1) on the stack
    txa
    mult_imm .sizeof(COROUTINE_STATE)
    tax
    stz coroutineStateTable+COROUTINE_STATE::sleepTime,x
    lda #3
    sta coroutineStateTable+COROUTINE_STATE::stackUsed,x
    lda $14
    dec
    sta coroutineStateTable+COROUTINE_STATE::stack+13,x
    sep #$20
    lda $16
    sta coroutineStateTable+COROUTINE_STATE::stack+15,x
    rep #$20

    ; Return the index of the coroutine which was just spawned.
    lda coroutineOrderLLHeadUsed
    pld
    rtl

; Parameters:
; A = coroutine index
CoroutineSwitchExecutionTo:
    FN_PROLOGUE_PRESERVE_ONLY_A $10

    ldx coroutinePreviousSp
    cpx #$ffff
@illegalNestedCoroutine:
    bne @illegalNestedCoroutine
    ldx coroutinePreviousDp
    cpx #$ffff
    bne @illegalNestedCoroutine

    tdc
    sta coroutinePreviousDp

    mult_imm .sizeof(COROUTINE_STATE)
    sta $0c
    tax
    lda coroutineStateTable+COROUTINE_STATE::stackUsed,x
    sta $00
    txa
    clc
    adc #.loword(coroutineStateTable+COROUTINE_STATE::stack+16)
    sec
    sbc $00
    sta $02
    tsc
    sta coroutinePreviousSp
    sec
    sbc $00
    tcs
    inc
    tay
    ldx $02
    lda $00
    dec
    mvn #$7e, #$7e
    ; Stack is now set up for the coroutine. Begin execution
    rtl



    pld
    rtl
