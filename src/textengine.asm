.include "all.asm"

.segment "BANK00"

WindowDefinitionTable:
    ; x (tiles), y (tiles), w (characters), h (characters)
    .byte 12, 4, 14, 4
    .byte 12, 4, 14, 4
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
    sta $02
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

; A = window ptr
WindowRedraw:
    FN_PROLOGUE_PRESERVE_ONLY_A $10

    pld
    rtl

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
    lda $00
    jsl WindowRedraw
@return:
    pld
    rtl

@errorNoWindowsAvailable:
    bra @errorNoWindowsAvailable
