; Minimal example of using ca65 to build SNES ROM.
; Based on https://wiki.superfamicom.org/basic-ca65-usage-for-snes-programming

.include "all.asm"

.segment "BANK00"

Main:
    FN_PROLOGUE_PRESERVE_NONE $12
    jsl EnableNmiAndAutoJoypad
    jsl ResetPpuState
    jsl WindowInit
    jsl CoroutineInit
    jsl InitPpuForText
    lda #1
    jsl WindowOpenByDefinitionId
    jsl CompleteFrame

    mov32_r_const $04, textStr
    jsl TextParse

    lda #1
    jsl WindowRedrawByDefinitionId
    jsl CompleteFrame


@forever:
    jmp @forever

.macro T_PAUSE frames
    .byte 2, 0, frames
.endmacro

textStr:
    .byte "\x10Hello world!\n"
    .byte "\x10Pause CC test:\n"
    .byte " 1 "
    T_PAUSE 60
    .byte "2 "
    T_PAUSE 60
    .byte "3 "
    T_PAUSE 60
    .byte "Done!"
    .byte 0

TestDrawText:
    ldx #0
    txy
    bra @strInitial
@strLoop:
    sta a:windowDisplayBuffer,y
    inx
    iny
    iny
@strInitial:
    lda f:textStr,x
    and #$00ff
    bne @strLoop
@strDone:
    rtl

InitPpuForText:
    FN_PROLOGUE_PRESERVE_NONE $12

    ; Upload font
    mov32_r_const $04, Asset_TextGraphics_tiles
    ldx #Asset_TextGraphics_tiles_size
    ldy #$6000
    lda #DMA_TO_VRAM_SETTING::word
    jsl QueueDmaToVram

    ; Upload palette
    ldx #Asset_TextGraphics_palette_size-2
@paletteCopyLoop:
    lda f:Asset_TextGraphics_palette,x
    sta a:paletteBuffer,x
    dex
    dex
    ;; Skip copying entry #0
    ;bne @paletteCopyLoop
    bpl @paletteCopyLoop
    lda #PALETTE_UPLOAD_SETTING::firstHalf
    sta a:paletteUpdateSetting

    ; Set PPU mode and configure BG3
    lda #1
    jsl PpuSetMode
    lda #$6000
    jsl PpuSetBg3Tile
    lda #$7C00
    ldx #BG_MAP_MODE::s32x32
    jsl PpuSetBg3Map
    ; Enable BG3 to be displayed on the main screen
    lda #$0004
    jsl PpuSetTmTs

    ; Display frame (to trigger DMAs)
    jsl CompleteFrame

    ; Maximum screen brightness
    lda #$000F
    jsl EnableScreenAndSetBrightness

    pld
    rtl

; Disabled now...
CoroutineTest:
    FN_PROLOGUE_PRESERVE_NONE $12
    mov32_r_const $04, CR_Test
    jsl CoroutineSpawn
    sta $0c
    jsl CoroutineSwitchExecutionTo
    pld
    rtl

CR_Test:
    rep #$31
    ; Set background color to $03E0
    lda #$03e0
    sta paletteBuffer
    lda #PALETTE_UPLOAD_SETTING::firstHalf
    jsl UpdatePalette
    jsl CompleteFrame

    ; Maximum screen brightness
    lda #$000F
    jsl EnableScreenAndSetBrightness

    rep #$31
    lda #$1234
    ldx #$5678
    ldy #$abcd
@forever:
    bra @forever

; TestMultiplication:
;     lda #$0101
;     ldy #$005a
;     jsl Mult16x8
;     cmp #$5a5a
; @mult1err:
;     bne @mult1err
;
;     lda #$0123
;     ldy #$0045
;     jsl Mult16x8
;     cmp #$4e6f
; @mult2err:
;     bne @mult2err
;
;     lda #123
;     ldy #100
;     jsl Mult16x8
;     cmp #12300
; @mult3err:
;     bne @mult3err
