.include "all.asm"


.segment "BANK00"
dmaToVramTypeTable:
    .byte $01, .lobyte(VMDATAL), $80 ; word
    .byte $09, .lobyte(VMDATAL), $80 ; word_fixed
    .byte $00, .lobyte(VMDATAL), $00 ; lobyte
    .byte $08, .lobyte(VMDATAL), $00 ; lobyte_fixed
    .byte $00, .lobyte(VMDATAH), $80 ; hibyte
    .byte $08, .lobyte(VMDATAH), $80 ; hibyte_fixed

; Signature:
; void QueueDmaToVram(u16 type, u16 size, u16 dest, void FAR * source)
; A: type
; X: size (0 to 65535)
; Y: dest
; $04: source
; Note that unlike the hardware DMA, a size of zero will do zero bytes.
QueueDmaToVram:
    @VAR_Type := $00
    @VAR_RunningSize := $02
    @VAR_Tmp32A := $04
    @VAR_CurrentSize := $08
    @VAR_Dest := $0a
    @VAR_TransferSource := $10
    @STACKSIZE = $14
    @PARAM_Source := @STACKSIZE + $04

    FN_PROLOGUE @STACKSIZE
    sta z:@VAR_Type
    stx z:@VAR_RunningSize
    sty z:@VAR_Dest
    mov32_r_r @VAR_TransferSource, @PARAM_Source

    ; If the screen is not currently enabled, do the DMA right away.
    lda a:HWM_INIDISP
    and #$0080
    beq @useTransferQueue
    ; Screen is off (forced-blank) - do DMA now.
    ; ... except ensure any queued DMAs have completed for correct ordering.
    ; We also don't want to get interrupted between setting VMAIN and VMADDL
    ; and running the DMA, and have the NMI do a DMA which overwrites them.
    jsl WaitForDmaComplete
    ; Switch bank to $80 and set index regs 8-bit
    sep #$10
    phb
    phk
    plb
    lda z:@VAR_RunningSize
    sta a:DAS0L
    lda z:@VAR_TransferSource
    sta a:A1T0L
    ldy z:@VAR_TransferSource+2
    sty a:A1B0
    ldy z:@VAR_Type
    lda a:dmaToVramTypeTable+DMA_TO_VRAM_SETTING_CONFIG::dmap,y
    sta a:DMAP0
    ldx a:dmaToVramTypeTable+DMA_TO_VRAM_SETTING_CONFIG::vmain,y
    stx a:VMAIN
    lda z:@VAR_Dest
    sta a:VMADDL
    ldy #$01
    sty a:MDMAEN
    rep #$31
    plb
    pld
    rtl

@useTransferQueue:
    lda z:@VAR_RunningSize
    beq @done
@outerLoop:
    cmp #DMA_CHUNK_SIZE
    bcc @noChunking
    lda #DMA_CHUNK_SIZE
@noChunking:
    sta z:@VAR_CurrentSize
    tax
    ; Adjust Dest for future transfer based on current transfer size
    lsr
    adc z:@VAR_Dest
    ; Write the DMA entry into the queue.
    ldy z:@VAR_Dest
    sta z:@VAR_Dest
    mov32_r_r @VAR_Tmp32A, @VAR_TransferSource
    lda z:@VAR_Type
    jsl WriteSingleDmaEntry
    ; Transfer has been written to queue. Update info for next transfer.
    ; Dest has already been updated.
    ; Check if the transfer type is fixed. If it is, skip updating source addr.
    lda z:@VAR_Type
    and #1
    bne @fixedTransfer
    ; Transfer is not fixed; advance source addr.
    lda z:@VAR_TransferSource
    clc
    adc z:@VAR_CurrentSize
    sta z:@VAR_TransferSource
@fixedTransfer:
    ; Decrease running size by the size of the transfer we just queued.
    lda z:@VAR_RunningSize
    sec
    sbc z:@VAR_CurrentSize
    sta z:@VAR_RunningSize
    bne @outerLoop
@done:
    pld
    rtl

; Signature:
; void WriteSingleDmaEntry(u16 type, u16 size, u16 dest, void FAR * source)
; A: type
; X: size (1 to DMA_CHUNK_SIZE)
; Y: dest
; $04: source
; Note that unlike the hardware DMA, a size of zero will do zero bytes.
WriteSingleDmaEntry:
    FN_PROLOGUE $10
    sta $00
    stx $02
    ; Wait for DMA queue to have space in it
    lda a:dmaFifoLastWritten
    and #$00ff
    ; Preserve DMA index in X
    tax
    clc
    adc #8
    and #$00ff
    sta $04
    ; $04 now has the desired dmaFifoLastWritten once we've written 
    ; Check if the dmaFifoLastRead is still there
@waitForSpaceLoop:
    lda a:dmaFifoLastRead
    and #$00ff
    cmp $04
    beq @waitForSpaceLoop
    ; We now have space to add our entry to the queue. Do it.
    lda $02
    sta a:dmaFifo+VRAMDMA_ENTRY::sizeInBytes,x
    tya
    sta a:dmaFifo+VRAMDMA_ENTRY::destAddr,x
    lda $14
    sta a:dmaFifo+VRAMDMA_ENTRY::sourceAddr,x
    sep #$20
    lda $16
    sta a:dmaFifo+VRAMDMA_ENTRY::sourceBank,x
    lda $00
    sta a:dmaFifo+VRAMDMA_ENTRY::paramOffset,x
    ; Update the last written pointer of the FIFO.
    lda $04
    sta a:dmaFifoLastWritten
    rep #$20
    ; All done.
    pld
    rtl

WaitForDmaComplete:
    sep #$20
    lda a:dmaFifoLastWritten
@loop:
    cmp a:dmaFifoLastRead
    bne @loop
    rep #$31
    rtl
