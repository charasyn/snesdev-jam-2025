.include "all.asm"

.segment "BANK00"

TextParse:
    FN_PROLOGUE_PRESERVE_NONE $10
    mov32_r_r $08, $14
@loop:
    lda [$08]
    inc $08
    and #$00ff
    beq @return
    cmp #$0010
    bcs @normalCharacter
    ; TODO: more fancy parsing stuff
    ; handle smart word wrapping, control codes, etc.
    cmp #2
    beq @cc02
    cmp #10
    beq @newline
    jmp @invalidCc
@normalCharacter:
    jsl TextDrawCharacter
    bra @loop
@newline:
    jsl WindowActiveCursorNewline
    bra @loop
@cc02:
    lda [$08]
    ldx $08
    inx
    inx
    stx $08
    sta $00
    and #$00ff
    cmp #@numCc02Jump
    bcs @invalidCc
    asl
    tax
    lda $00
    xba
    and #$00ff
    jsr (@cc02JumpTable,x)
    bra @loop
@invalidCc:
    bra @invalidCc
@return:
    pld
    rtl

@cc02JumpTable:
    .word .loword(_L_CcPause)
@numCc02Jump = 1

_L_CcPause:
    inc
@loop:
    dec
    beq @return
    pha
    jsl TextTickOneFrame
    pla
    bra @loop
@return:
    rts

TextDrawCharacter:
    jsl WindowActiveDrawCharacter
    jml TextTickOneFrame

TextTickOneFrame:
    jml CompleteFrame
