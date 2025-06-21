; Minimal example of using ca65 to build SNES ROM.
; Based on https://wiki.superfamicom.org/basic-ca65-usage-for-snes-programming

.include "all.asm"

.segment "BANK00"

Main:
    jsl EnableNmiAndAutoJoypad
    jsl ResetPpuState
    jsl CoroutineInit
    jsl CoroutineTest
@forever:
    jmp @forever

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
