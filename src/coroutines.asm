.include "all.asm"

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
    ; Locals:
    ; $0C - Offset to the relevant coroutine entry in coroutineStateTable

    ; Check if we're already running a coroutine and enter an infinite loop if
    ; we are. We don't support this for now.
    ; Don't clobber A so we can use it later.
    ldx coroutinePreviousSp
    cpx #$ffff
@illegalNestedCoroutine:
    bne @illegalNestedCoroutine
    ldx coroutinePreviousDp
    cpx #$ffff
    bne @illegalNestedCoroutine

    ; A is still the coroutine index. Get the offset into the coroutine data
    ; (array-of-structs).
    mult_imm .sizeof(COROUTINE_STATE)
    sta $0c
    tax
    ; Get stack used by this coroutine
    lda coroutineStateTable+COROUTINE_STATE::stackUsed,x
    sta $00
    ; Get address of lowest byte used in the saved stack
    txa
    clc
    adc #.loword(coroutineStateTable+COROUTINE_STATE::stack+16)
    sec
    sbc $00
    tax
    ; X now holds the lowest used address in the saved stack
    ; Preserve both stacks so we can store them later
    tdc
    sta coroutinePreviousDp
    tsc
    sta coroutinePreviousSp
    ; Subtract the needed space from the current processor stack
    sec
    sbc $00
    tcs

    ; The stack has now been expanded to allow for the space needed for this
    ; coroutine. Now, let's copy it.
    ; The correct address for the saved stack is in X.
    ; 6502 stack always points to an unused byte; we need to increase the
    ; address to point to the byte which will be used
    inc
    tay ; Put destination address in Y
    ; Get number of bytes to transfer (minus 1 because of how mvn works)
    lda $00
    dec
    mvn #$7e, #$7e
    ; Stack is now set up for the coroutine. Begin execution
    rtl



    pld
    rtl
