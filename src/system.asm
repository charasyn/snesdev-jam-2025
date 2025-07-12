.include "all.asm"

.segment "ZPRAM"
dmaFifoLastWritten: .res 1
dmaFifoLastRead: .res 1
frameToDisplay: .res 1
frameCurrentlyDisplaying: .res 1
paletteUpdateSetting: .res 2
oamDmaSourceAddress: .res 2

; Note - DMA budget is stored in memory as a negative value and we add to it
; until it reaches zero.
nmiDmaBudget: .res 2
HWM_INIDISP: .res 1
HWM_OBSEL: .res 1
HWM_MOSAIC: .res 1

; ...

HWM_HDMAEN: .res 1
HWM_NMITIMEN: .res 1

.segment "LORAM"

dmaFifo: .res 256

.segment "HIRAM"

paletteBuffer: .res (256 * 2)
oamBuffer0: .res 544
oamBuffer1: .res 544
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
    sep #$50 ; set X=8bit, and set overflow flag for later
    lda #$0000
    tcd
    stz a:MDMAEN ; Clear Main DMA and HDMA enable
    lda #.loword(-DMA_BUDGET_TOTAL)
    sta z:<nmiDmaBudget
    ldx z:<frameToDisplay
    cpx z:<frameCurrentlyDisplaying
    beq @noFrameCompleted
    lda #.loword(-DMA_BUDGET_TOTAL + DMA_BUDGET_COST_CHANGE_FRAME)
    sta z:<nmiDmaBudget
    stx z:<frameCurrentlyDisplaying
    cpx #0
    bne @displayFrame1
@displayFrame0:
    lda #.loword(oamBuffer0)
    sta z:<oamDmaSourceAddress
    ; Set scroll registers
    ; TODO
    bra @displayFrameJoin
@displayFrame1:
    lda #.loword(oamBuffer1)
    sta z:<oamDmaSourceAddress
    ; Set scroll registers
    ; TODO
    bvc @displayFrameJoin ; branch should not be taken, cycles should match
@displayFrameJoin:
    ; Clobber DP with $4300 for speedier writes to DMA regs
    lda #$4300
    tcd
    ; Handle OAM upload
    stz a:OAMADDL
    lda #(.lobyte(OAMDATA) << 8 | 0)
    sta z:<DMAP1
    lda a:oamDmaSourceAddress
    sta z:<A1T1L
    lda #544
    sta z:<DAS1L
    ldy #^oamBuffer0
    sty z:<A1B1
    ldy #$02
    sty a:MDMAEN

    ; handle palette upload
    ldx a:paletteUpdateSetting
    beq @skipPalette
    ; If updating palette, determine new DMA budget
    lda #.loword(-DMA_BUDGET_TOTAL + DMA_BUDGET_COST_CHANGE_FRAME)
    ; Note: carry is always 1 here since the last compare should be:
    ; ldx {0 or 1}
    ; cpx #0
    adc a:paletteUploadBudgetCost,x
    sta a:nmiDmaBudget
    ; Set DMA params = 0, B-Bus address = CGDATA
    lda #(.lobyte(CGDATA) << 8 | 0)
    sta z:<DMAP1
    ; Set low word of upload source (bank will be set later)
    lda a:paletteUploadSource,x
    sta z:<A1T1L
    ; Set upload size
    lda a:paletteUploadSize,x
    sta z:<DAS1L
    ; Set upload source bank
    ldy #$7e
    sty z:<A1B1
    ; Set upload destination address in CGADD
    ldy a:paletteUploadDestination,x
    sty a:CGADD
    ; Enable DMA
    ldy #$02
    sty a:MDMAEN
    ; Reset to "normal" state
    lda #$0000
    tcd
    ; Clear saved palette update setting, since we just transferred
    stz z:<paletteUpdateSetting
@skipPalette:
@noFrameCompleted:
    ; Do VRAM DMA
    ldx z:<dmaFifoLastRead
    cpx z:<dmaFifoLastWritten
    beq @dmaDone
@dmaLoop:
    ; Cycle-counting, this loop takes 76.75 * 8 master cycles to complete
    ; (not including DMA). Including DMA overhead and rounding up, we get
    ; 81 bytes of overhead.
    lda a:dmaFifo+VRAMDMA_ENTRY::sizeInBytes,x
    clc
    adc z:<nmiDmaBudget
    bcs @dmaDone
    sta z:<nmiDmaBudget
    lda a:dmaFifo+VRAMDMA_ENTRY::sizeInBytes,x
    sta a:DAS1L
    lda a:dmaFifo+VRAMDMA_ENTRY::destAddr,x
    sta a:VMADDL
    lda a:dmaFifo+VRAMDMA_ENTRY::sourceAddr,x
    sta a:A1T1L
    ldy a:dmaFifo+VRAMDMA_ENTRY::sourceBank,x
    sty a:A1B1
    ldy a:dmaFifo+VRAMDMA_ENTRY::paramOffset,x
    lda a:dmaToVramTypeTable+DMA_TO_VRAM_SETTING_CONFIG::dmap,y
    sta a:DMAP1
    txa
    ldx a:dmaToVramTypeTable+DMA_TO_VRAM_SETTING_CONFIG::vmain,y
    stx a:VMAIN
    ldx #$02
    stx a:MDMAEN
    adc #$0008
    tax
    cpx z:<dmaFifoLastWritten
    bne @dmaLoop
@dmaDone:
    ; Enable HDMA
    ldy z:<HWM_HDMAEN
    sty a:HDMAEN
    ; Store DMA FIFO offset back to memory
    stx z:<dmaFifoLastRead
    ; Do whatever other processing is required
    ; TODO
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
    lda #DMA_TO_VRAM_SETTING::word_fixed
    ldx #$8002
    ldy #$0000
    jsl QueueDmaToVram
    lda #DMA_TO_VRAM_SETTING::word_fixed
    ldx #$7ffe
    ldy #$4001
    jsl QueueDmaToVram
    jsl WaitForDmaComplete
    ; Clear OAM
    ; Will be done by NMI.
    ; Clear CGRAM
    ; Palette buffer memory will be cleared to zeros. Upload that.
    lda #PALETTE_UPLOAD_SETTING::all
    jsl UpdatePalette
    jsl CompleteFrame
    pld
    rtl

CompleteFrame:
    sep #$20
    lda frameCurrentlyDisplaying
    eor #1
    sta frameToDisplay
@waitForFrame:
    cmp frameCurrentlyDisplaying
    bne @waitForFrame
    rep #$31
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
paletteUploadBudgetCost:
    .word 1
    .word (256 + DMA_BUDGET_COST_PER_DMA)
    .word (256 + DMA_BUDGET_COST_PER_DMA)
    .word (512 + DMA_BUDGET_COST_PER_DMA)

UpdatePalette:
    rep #$31
    sep #$20
    ora paletteUpdateSetting
    sta paletteUpdateSetting
@return:
    rep #$31
    rtl
