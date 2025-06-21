.include "all.asm"

.segment "ZPRAM"
frameDoneRendering: .res 2
paletteUpdateSetting: .res 2

.segment "HIRAM"

paletteBuffer: .res (256 * 2)
HWM_INIDISP: .res 1
HWM_OBSEL: .res 1
HWM_MOSAIC: .res 1

; ...

HWM_NMITIMEN: .res 1
pad1Held: .res 2
pad1JustPressed: .res 2

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
    bra BrkVector
IrqVector:
    rti

NmiVector:
    ; Do far jump so we will be executing at FastROM speeds
    jml NmiHandler
NmiHandler:
    rep #$31
    pha
    phx
    phy
    phd
    phb
    ; Set data bank to $80
    phk
    plb

    ; TODO: nmi handler goes here
    lda #$0000
    tcd
    lda z:.lobyte(frameDoneRendering)
    beq @endOfNmi
    stz z:.lobyte(frameDoneRendering)
    ; handle palette upload
    lda z:.lobyte(paletteUpdateSetting)
    beq @skipPalette
    asl
    ; Smaller index registers makes it faster
    sep #$10
    tax
    ; Clobber DP with $4300 for speed
    lda #$4300
    tcd
    ; Set DMA params = 0, B-Bus address = CGDATA
    lda #(.lobyte(CGDATA) << 8 | 0)
    sta z:.lobyte(DMAP1)
    ; Set low word of upload source (bank will be set later)
    lda paletteUploadSource,x
    sta z:.lobyte(A1T1L)
    ; Set upload size
    lda paletteUploadSize,x
    sta z:.lobyte(DAS1L)
    sep #$20
    ; Set upload source bank
    lda #$7e
    sta z:.lobyte(A1B1)
    ; Set upload destination address in CGADD
    lda paletteUploadDestination,x
    sta a:CGADD
    ; Enable DMA
    lda #$02
    sta a:MDMAEN
    ; Reset to "normal" state
    rep #$31
    lda #$0000
    tcd
    ; Clear saved palette update setting, since we just transferred
    stz z:.lobyte(paletteUpdateSetting)
@skipPalette:
@endOfNmi:
    rep #$31
    plb
    pld
    ply
    plx
    pla
    rti

ResetPpuState:
    FN_PROLOGUE_PRESERVE_NONE 8
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
    ; Update software state
    jsl DisableScreen
    ; Clear VRAM
    mov32_r_const $04, Zeros
    lda DMA_TO_VRAM_SETTING::word_fixed
    ldx #0
    txy
    jsl DmaToVramImmediate
    ; Clear OAM
    ; TODO
    ; Clear CGRAM
    ; Palette buffer memory will be cleared to zeros. Upload that.
    lda #PALETTE_UPLOAD_SETTING::all
    jsl UpdatePalette
    jsl CompleteFrame
    pld
    rtl

CompleteFrame:
    rep #$31
    lda #1
    sta frameDoneRendering
@waitForFrame:
    lda frameDoneRendering
    bne @waitForFrame
    rtl

Zeros:
    .dword 0

DisableScreen:
    ; Call to disable screen.
    sep #$20
    lda #$80
EnableScreenAndSetBrightness:
    ; Call with A = $00-$0F to set brightness
    ; Call with A = $80 to enable forced blank
    sep #$20
    sta f:INIDISP
    sta HWM_INIDISP
    rep #$31
    rtl

EnableNmiAndAutoJoypad:
    sep #$20
    lda #$81
    sta f:NMITIMEN
    sta HWM_NMITIMEN
    rep #$31
    stz pad1Held
    stz pad1JustPressed
    rtl

paletteUploadSize:
    .word 1
    .word 256
    .word 256
    .word 512
paletteUploadSource:
    .word .loword(paletteBuffer)
    .word .loword(paletteBuffer)
    .word .loword((paletteBuffer+256))
    .word .loword(paletteBuffer)
paletteUploadDestination:
    .word $ff
    .word $00
    .word $80
    .word $00

UpdatePalette:
    rep #$31
    sep #$20
    ora paletteUpdateSetting
    sta paletteUpdateSetting
@return:
    rep #$31
    rtl
