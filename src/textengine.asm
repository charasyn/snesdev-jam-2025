.include "all.asm"

.segment "BANK00"

WindowDefinitionTable:
    ; x (tiles), y (tiles), w (characters), h (characters)
    .byte 1, 1, 1, 1
    .byte 14, 4, 14, 4
    .byte 12, 4, 14, 4
    .byte 12, 4, 14, 4
    .byte 12, 4, 14, 4
    .byte 12, 4, 14, 4
    .byte 12, 4, 14, 4
    .byte 12, 4, 14, 4
    .byte 12, 4, 14, 4
    .byte 12, 4, 14, 4

WindowInit:
    FN_PROLOGUE_PRESERVE_NONE $10
    ; Clear "window in front"
    lda #0
    sta a:windowFrontPtr
    ; Set "definition ID" to $FFFF for all windows, indicating the window is
    ; not in use. Also, set the buffer ptr to point to the memory used to store
    ; the text buffer for the window.
    lda #.loword(windowDisplayBuffer)
    sta $00
    ldx #0
    ldy #NUM_ACTIVE_WINDOWS
@clearWindowEntryLoop:
    lda #$ffff
    sta a:windowActiveStateTable+WINDOW_ACTIVE_STATE::definitionId,x
    lda $00
    sta a:windowActiveStateTable+WINDOW_ACTIVE_STATE::charBufferPtr,x
    clc
    adc #MAX_WINDOW_AREA * 2
    sta $00
    txa
    adc #.sizeof(WINDOW_ACTIVE_STATE)
    tax
    dey
    bne @clearWindowEntryLoop
    pld
    rtl

; A = window definition ID
; Returns pointer to window struct with that ID, or null
WindowFindByDefinitionId:
    FN_PROLOGUE_PRESERVE_ONLY_A $10
    sta $00
    lda #.loword(windowActiveStateTable)
@loop:
    tax
    ldy a:WINDOW_ACTIVE_STATE::definitionId,x
    cpy $00
    beq @return
    clc
    adc #.sizeof(WINDOW_ACTIVE_STATE)
    cmp #.loword(windowActiveStateTable+(NUM_ACTIVE_WINDOWS*.sizeof(WINDOW_ACTIVE_STATE)))
    bne @loop
    ; Failed to find window - return null
    lda #0
@return:
    pld
    rtl

; A = window state ptr to unlink
WindowUnlinkFromLL:


; A = window state ptr
WindowBringToFront:
    ; Error on null pointer
    cmp #0
    beq @ErrorPtrNull
    ; Error on an invalid window (definition ID == -1)
    tax
    lda a:WINDOW_ACTIVE_STATE::definitionId,x
    cmp #$ffff
    beq @ErrorWindowInvalid
    ; Return early if the window is already in front
    cpx a:windowFrontPtr
    beq @Return
    ; Unlink window from linked list
    txa
    jsl WindowUnlinkFromLL
    ; Error if the window was not in the LL
    cmp #0
    beq @ErrorWindowNotInLL
    ; Add to front of LL, by "pushing" onto front
    tax
    lda a:windowFrontPtr
    sta a:WINDOW_ACTIVE_STATE::ptrAfter,x
    stx a:windowFrontPtr
@Return:
    rtl
@ErrorPtrNull:
    bra @ErrorPtrNull
@ErrorWindowInvalid:
    bra @ErrorWindowInvalid
@ErrorWindowNotInLL:
    bra @ErrorWindowNotInLL

; A = window ptr
WindowGetDefinitionOffset:
    FN_PROLOGUE_PRESERVE_ONLY_A $02
    tax
    lda a:WINDOW_ACTIVE_STATE::definitionId,x
    mult_imm .sizeof(WINDOW_DEFINITION)
    pld
    rtl

; A = window ptr
WindowClearCharacterBuffer:
    FN_PROLOGUE_PRESERVE_ONLY_A $10
    sta $00
    jsl WindowGetDefinitionOffset
    tax
    lda f:WindowDefinitionTable+WINDOW_DEFINITION::width,x
    ; skip masking to 8-bit since the upper byte of Y doesn't matter
    tay
    lda f:WindowDefinitionTable+WINDOW_DEFINITION::height,x
    and #$00ff
    jsl Mult16x8
    tay
    ; Number of characters to clear in Y
    ldx $00
    lda a:WINDOW_ACTIVE_STATE::charBufferPtr,x
    tax
    ; Pointer to character buffer in X
    lda #$0020
    ; Set all characters in the buffer to (char=' ', attribute=0)
@loop:
    sta a:0,x
    inx
    inx
    dey
    bne @loop
    pld
    rtl

; A = entry in windowDisplayBuffer (low 8: char #, high 8: attrs)
; Returns the tilemap entry for the top tile in $04, bottom tile in $06
; TODO: does this follow the calling convention for returning?
_L_WindowCharAttrsToPpuMapEntry:
    sta $04
    and #$000f
    sta $06
    lda $04
    and #$00f0
    asl
    ora $06
    sta $06
    lda $04
    and #$0700
    asl
    asl
    ora $06
    sta $04
    ora #$0010
    sta $06
    rts

; A = window ptr
WindowRedraw:
    FN_PROLOGUE_PRESERVE_ONLY_A $18
    sta $08
    tax
    lda a:WINDOW_ACTIVE_STATE::charBufferPtr,x
    sta $0a
    txa
    jsl WindowGetDefinitionOffset
    sta $0c
    tax
    lda f:WindowDefinitionTable+WINDOW_DEFINITION::width,x
    and #$00ff
    sta $10
    lda f:WindowDefinitionTable+WINDOW_DEFINITION::height,x
    and #$00ff
    sta $12
    lda f:WindowDefinitionTable+WINDOW_DEFINITION::posY,x
    and #$00ff
    mult_imm SCREEN_WIDTH_TILES
    sta $00
    lda f:WindowDefinitionTable+WINDOW_DEFINITION::posX,x
    and #$00ff
    clc
    adc $00
    ; Convert tilemap entry # to offset in BG3
    asl
    sta $0e
    tay

    ; Draw window border
    ; Top row
    lda #$2001
    sta a:.loword(bg3Buffer+(-SCREEN_WIDTH_TILES-1)*2),y
    ldx $10
    lda #$2002
@loopTop:
    sta a:.loword(bg3Buffer+(-SCREEN_WIDTH_TILES)*2),y
    iny
    iny
    dex
    bne @loopTop
    lda #$6001
    sta a:.loword(bg3Buffer+(-SCREEN_WIDTH_TILES)*2),y
    ; Sides
    ldx $0e
    lda $12
    asl
    sta $00
    clc
@loopSides:
    lda #$2003
    sta a:.loword(bg3Buffer-2),x
    lda #$6003
    sta a:bg3Buffer,y
    dec $00
    beq @sidesDone
    txa
    adc #SCREEN_WIDTH_TILES*2
    tax
    tya
    adc #SCREEN_WIDTH_TILES*2
    tay
    bra @loopSides
@sidesDone:
    ; Bottom row
    lda #$a001
    sta a:.loword(bg3Buffer+(SCREEN_WIDTH_TILES-1)*2),x
    ldy $10
    lda #$a002
@loopBottom:
    sta a:.loword(bg3Buffer+(SCREEN_WIDTH_TILES)*2),x
    inx
    inx
    dey
    bne @loopBottom
    lda #$e001
    sta a:.loword(bg3Buffer+(SCREEN_WIDTH_TILES)*2),x

    ; Draw window contents
@loopCharsRow:
    lda $0e
    sta $16
    lda $10
    sta $14
@loopCharsCol:
    ldx $0a
    lda a:0,x
    inx
    inx
    stx $0a
    jsr _L_WindowCharAttrsToPpuMapEntry
    ldx $16
    lda $04
    sta a:bg3Buffer,x
    lda $06
    sta a:.loword(bg3Buffer+(SCREEN_WIDTH_TILES)*2),x
    inx
    inx
    stx $16
    dec $14
    bne @loopCharsCol
    lda $0e
    clc
    adc #SCREEN_WIDTH_TILES*2*2
    sta $0e
    dec $12
    bne @loopCharsRow
    pld
    rtl

; A = window definition ID
WindowRedrawByDefinitionId:
    jsl WindowFindByDefinitionId
    cmp #0
    beq @errorWindowNotFound
    jsl WindowRedraw
    rtl
@errorWindowNotFound:
    bra @errorWindowNotFound

; A = window definition ID
WindowOpenByDefinitionId:
    FN_PROLOGUE_PRESERVE_ONLY_A $10
    sta $00
    jsl WindowFindByDefinitionId
    cmp #0
    beq @createWindow
    ; The window already exists. Bring it to the front.
    jsl WindowBringToFront
    pld
    rtl
@createWindow:
    ; Find an unused window (definitionId == 0xFFFF)
    lda #$ffff
    jsl WindowFindByDefinitionId
    cmp #0
    beq @errorNoWindowsAvailable
    sta $02
    tax
    lda $00
    sta a:WINDOW_ACTIVE_STATE::definitionId,x
    stz a:WINDOW_ACTIVE_STATE::attributes,x
    stz a:WINDOW_ACTIVE_STATE::ptrBefore,x
    stz a:WINDOW_ACTIVE_STATE::cursorX,x
    stz a:WINDOW_ACTIVE_STATE::cursorY,x
    ; Put in front
    lda a:windowFrontPtr
    sta a:WINDOW_ACTIVE_STATE::ptrAfter,x
    stx a:windowFrontPtr
    ; Clear the window's character buffer
    txa
    jsl WindowClearCharacterBuffer
    ; Draw the window
    lda $02
    jsl WindowRedraw
@return:
    pld
    rtl

@errorNoWindowsAvailable:
    bra @errorNoWindowsAvailable
