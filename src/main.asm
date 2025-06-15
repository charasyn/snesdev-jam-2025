; Minimal example of using ca65 to build SNES ROM.
; Based on https://wiki.superfamicom.org/basic-ca65-usage-for-snes-programming

.include "all.asm"

.segment "HEADER"        ; +$7FE0 in file
    .byte "CHE TEST             " ; ROM name
    .byte $30            ; LoROM, fast-capable
    .byte 0              ; no battery RAM
    .byte $08            ; 256K ROM
    .byte 0              ; no RAM
    .byte 0,0,0          ; leave country, developer, version at zero
    .word $AAAA,$5555    ; dummy checksum and complement
    .word 0, 0, 0, .loword(BrkVector)
    .word 0, .loword(NmiVector), 0, .loword(IrqVector)
    .word 0, 0, 0, 0
    .word 0, 0, .loword(ResetVector), 0

.segment "BANK00"

ResetVector:
    clc             ; native mode
    xce
    rep #$ff        ; Clear all flags (sets A/X/Y 16-bit)
    sep #$24        ; Set A 8-bit, set interrupt disable flag
    ; Disable interrupts, HDMA
    lda #0
    sta f:NMITIMEN
    sta f:HDMAEN
    ; Disable rendering
    lda #$80
    sta f:INIDISP

    ; Set up processor stack
    rep #$20
    lda #(.loword(__PSTACK_START__) + __PSTACK_SIZE__ - 1)
    tcs
    ; Clear memory
    lda #0
    sta f:$7e0000
    tax
    ldy #2
    dec
    mvn #$7e, #$7e
    mvn #$7e, #$7f
    ; Set up data bank
    pea $7e7e
    plb
    plb
    ; Set up direct page local variable stack
.ifdef DEBUG
    lda #(.loword(__DSTACK_START__) + __DSTACK_SIZE__ - 4)
    tcd
    lda #$aaaa
    sta $00
    lda #$5555
    sta $02
.else
    lda #(.loword(__DSTACK_START__) + __DSTACK_SIZE__)
    tcd
.endif
    ; Enable FastROM
    sep #$20
    lda #$01
    sta f:MEMSEL
    rep #$30

    ; Call main function (using FastROM speeds)
    jml Main

BrkVector:
IrqVector:
NmiVector:
    rti

Main:
    jsl ResetPpuState
    jsl EnableNmiAndAutoJoypad
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
    sep #$20
    ; Set background color to $03E0
    lda #$00
    sta f:CGADD
    lda #$E0
    sta f:CGDATA
    lda #$03
    sta f:CGDATA

    ; Maximum screen brightness
    lda #$0F
    sta f:INIDISP

    rep #$31
    lda #$1234
    ldx #$5678
    ldy #$abcd
@forever:
    bra @forever

ResetPpuState:
    rep #$31
    phd
    tdc
    adc #.loword(-8)
    tcd
    ; Clear misc. registers
    phd
    lda #$2100
    tcd
    phb
    phk ; bank $80
    plb
    stz z:.lobyte(INIDISP)
    stz z:.lobyte(BGMODE)
    stz z:.lobyte(BG1SC)
    stz z:.lobyte(BG3SC)
    stz z:.lobyte(BG12NBA)
    stz z:.lobyte(BG1HOFS)
    stz z:.lobyte(BG1HOFS)
    stz z:.lobyte(BG2HOFS)
    stz z:.lobyte(BG3HOFS)
    stz z:.lobyte(BG4HOFS)
    stz z:.lobyte(VMAIN)
    stz z:.lobyte(M7SEL)
    stz z:.lobyte(M7A)
    stz z:.lobyte(M7C)
    stz z:.lobyte(M7X)
    stz z:.lobyte(M7X)
    stz z:.lobyte(W12SEL)
    stz z:.lobyte(WOBJSEL)
    stz z:.lobyte(WH1)
    stz z:.lobyte(WH3)
    stz z:.lobyte(WOBJLOG)
    stz z:.lobyte(TS)
    stz z:.lobyte(TSW)
    stz z:.lobyte(CGADSUB)
    stz z:.lobyte(SETINI)
    plb
    pld
    ; Clear VRAM
    mov32_r_const $04, Zeros
    lda DMA_TO_VRAM_SETTING::word_fixed
    ldx #0
    txy
    jsl DmaToVramImmediate
    ; Clear OAM, CGRAM
    ; TODO
    pld
    rtl

Zeros:
    .dword 0
