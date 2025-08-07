.include "all.asm"

.segment "BANK00"

.macro window_def wx, wy, ww, wh
    .byte wx, wy, ww, wh
    .word (wx+wy*SCREEN_WIDTH_TILES)*2
    .assert wx > 0 && (wx+ww+1) < SCREEN_WIDTH_TILES, error, "Window X pos invalid"
    .assert wy > 0 && (wy+wh*2+1) < SCREEN_HEIGHT_TILES, error, "Window Y pos invalid"
    .assert (ww*wh) <= MAX_WINDOW_AREA, error, "Window too large"
.endmacro

WindowDefinitionTable:
    ; x (tiles), y (tiles), w (characters), h (characters)
    window_def 1, 1, 1, 1
    window_def 4, 3, 24, 3
    window_def 4, 12, 10, 2
    window_def 18, 12, 10, 2
    window_def 12, 4, 14, 4
    window_def 12, 4, 14, 4
    window_def 12, 4, 14, 4
    window_def 12, 4, 14, 4
    window_def 12, 4, 14, 4
    window_def 12, 4, 14, 4
    window_def 12, 4, 14, 4

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
; Returns same ptr in A
;
; Window * WindowUnlinkFromLL(Window * WindowCurrent) {
;     Window * WindowNext = WindowCurrent->ptrNext;
;     Window * WindowPrev = WindowCurrent->ptrPrev;
;     if (WindowPrev) {
;         if (windowFrontPtr == WindowCurrent) { error(); }
;         WindowPrev->ptrNext = WindowNext;
;     } else if (windowFrontPtr == WindowCurrent) {
;         windowFrontPtr = WindowNext;
;     }
;     if (WindowNext) {
;         WindowNext->ptrPrev = WindowPrev;
;     }
;     return WindowCurrent;
; }
WindowUnlinkFromLL:
; WindowCurrent is in X after the initial TAX instruction
@WindowPrev = $00
@WindowNext = $02
    FN_PROLOGUE_PRESERVE_ONLY_A $04
    tax
    beq @Return
    ; Load the Next and Prev pointers into local variables to simplify code
    lda a:WINDOW_ACTIVE_STATE::ptrNext,x
    sta z:<@WindowNext
    lda a:WINDOW_ACTIVE_STATE::ptrPrev,x
    sta z:<@WindowPrev
    beq @DontUpdateBeforeToAfter
    ; WindowCurrent (X) has a window before it in the LL. Ensure that it is not
    ; somehow pointed to as the front of the linked list.
    ; (Integrity check)
    cpx a:windowFrontPtr
    beq @ErrorWindowInFrontHasBefore
    tay
    ; WindowPrev->ptrNext = WindowNext
    lda z:<@WindowNext
    sta a:WINDOW_ACTIVE_STATE::ptrNext,y
    bra @DontChangeFrontPtr

@DontUpdateBeforeToAfter:
    cpx a:windowFrontPtr
    bne @DontChangeFrontPtr
    lda z:<@WindowNext
    sta a:windowFrontPtr
@DontChangeFrontPtr:

    ldy z:<@WindowNext
    beq @DontUpdateAfterToBefore
    ; WindowNext->ptrPrev = WindowPrev
    lda z:<@WindowPrev
    sta a:WINDOW_ACTIVE_STATE::ptrPrev,y
@DontUpdateAfterToBefore:

    ; WindowCurrent->ptrPrev = NULL
    stz a:WINDOW_ACTIVE_STATE::ptrPrev,x
    ; WindowCurrent->ptrNext = NULL
    stz a:WINDOW_ACTIVE_STATE::ptrNext,x
    ; Return pointer to window which was removed
    txa
@Return:
    pld
    rtl

@ErrorWindowInFrontHasBefore:
    bra @ErrorWindowInFrontHasBefore

; A = window state ptr
_L_WindowAddToFrontOfLL:
    tay
    tax
    lda a:windowFrontPtr
    sta a:WINDOW_ACTIVE_STATE::ptrNext,x
    stx a:windowFrontPtr
    tax
    beq @NoPrevWindow
    tya
    sta a:WINDOW_ACTIVE_STATE::ptrPrev,x
@NoPrevWindow:
    rts

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
    ; Add to front of LL, by "pushing" onto front
    jsr _L_WindowAddToFrontOfLL
@Return:
    rtl
@ErrorPtrNull:
    bra @ErrorPtrNull
@ErrorWindowInvalid:
    bra @ErrorWindowInvalid

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
    lda f:WindowDefinitionTable+WINDOW_DEFINITION::offsetToTilemapEntry,x
    sta $0e
    tay

    ; Draw window border
    ; Top row
    lda #$2201
    sta a:.loword(bg3Buffer+(-SCREEN_WIDTH_TILES-1)*2),y
    ldx $10
    lda #$2202
@loopTop:
    sta a:.loword(bg3Buffer+(-SCREEN_WIDTH_TILES)*2),y
    iny
    iny
    dex
    bne @loopTop
    lda #$6201
    sta a:.loword(bg3Buffer+(-SCREEN_WIDTH_TILES)*2),y
    ; Sides
    ldx $0e
    lda $12
    asl
    sta $00
    clc
@loopSides:
    lda #$2203
    sta a:.loword(bg3Buffer-2),x
    lda #$6203
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
    lda #$a201
    sta a:.loword(bg3Buffer+(SCREEN_WIDTH_TILES-1)*2),x
    ldy $10
    lda #$a202
@loopBottom:
    sta a:.loword(bg3Buffer+(SCREEN_WIDTH_TILES)*2),x
    inx
    inx
    dey
    bne @loopBottom
    lda #$e201
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

    ; Mark BG3 buffer as dirty
    lda #1
    sta bg3BufferDirty
    pld
    rtl

WindowRedrawAll:
    lda a:windowFrontPtr
    beq @Return
@FindEndLoop:
    tax
    lda a:WINDOW_ACTIVE_STATE::ptrNext,x
    bne @FindEndLoop
@EndFound:
    txa
@IterBackwardsLoop:
    pha
    jsl WindowRedraw
    plx
    lda a:WINDOW_ACTIVE_STATE::ptrPrev,x
    bne @IterBackwardsLoop
@Return:
    rtl

; A = window ptr
WindowUndraw:
    FN_PROLOGUE_PRESERVE_ONLY_A $14
    sta $08
    jsl WindowGetDefinitionOffset
    tax
    lda f:WindowDefinitionTable+WINDOW_DEFINITION::width,x
    and #$00ff
    inc
    inc
    sta $10
    lda f:WindowDefinitionTable+WINDOW_DEFINITION::height,x
    and #$00ff
    inc
    asl
    sta $12
    lda f:WindowDefinitionTable+WINDOW_DEFINITION::offsetToTilemapEntry,x
    sta $0e
    tay
@PerRowLoop:
    ldx $10
    lda #0
@InnerLoop:
    sta a:.loword(bg3Buffer+(-SCREEN_WIDTH_TILES-1)*2),y
    iny
    iny
    dex
    bne @InnerLoop
    lda $0e
    clc
    adc #SCREEN_WIDTH_TILES*2
    sta $0e
    tay
    dec $12
    bne @PerRowLoop
    lda #1
    sta a:bg3BufferDirty
    pld
    rtl

; A = window ptr
; X = character
_L_RenderCharacterAtWindowCursorToBg3:
    FN_PROLOGUE $08
    sta $00
    stx $02
    jsl WindowGetDefinitionOffset
    tax
    ; Get (cursorY * 2 * SCREEN_WIDTH_TILES + cursorX)
    ldy $00
    lda a:WINDOW_ACTIVE_STATE::cursorY,y
    mult_imm SCREEN_WIDTH_TILES
    ; Window ptr gone from $00
    asl
    adc a:WINDOW_ACTIVE_STATE::cursorX,y
    ; We now have the tilemap entry # relative to the top left in A. We need
    ; to turn it into an offset relative to the start of the BG3 map.
    ; Multiply by 2 and then add the precalculated offset from the start of the
    ; BG3 buffer.
    asl
    adc f:WindowDefinitionTable+WINDOW_DEFINITION::offsetToTilemapEntry,x
    sta $00
    ; Calculate the tilemap values to use for this character.
    lda $02
    jsr _L_WindowCharAttrsToPpuMapEntry
    ; Write to BG3 mem
    ldx $00
    lda $04
    sta a:bg3Buffer,x
    lda $06
    sta a:.loword(bg3Buffer+(SCREEN_WIDTH_TILES)*2),x
    ; Mark BG3 buffer as dirty
    lda #1
    sta bg3BufferDirty
    pld
    rts

; A = window definition ID
WindowRedrawByDefinitionId:
    jsl WindowFindByDefinitionId
    cmp #0
    beq @errorWindowNotFound
    jsl WindowRedraw
    rtl
@errorWindowNotFound:
    bra @errorWindowNotFound

WindowActiveRedraw:
    lda windowFrontPtr
    jmp WindowRedraw

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
    stz a:WINDOW_ACTIVE_STATE::ptrPrev,x
    stz a:WINDOW_ACTIVE_STATE::cursorX,x
    stz a:WINDOW_ACTIVE_STATE::cursorY,x
    ; Put in front
    txa
    jsr _L_WindowAddToFrontOfLL
@NoPrevWindow:
    ; Clear the window's character buffer
    lda $02
    jsl WindowClearCharacterBuffer
    ; Draw the window
    lda $02
    jsl WindowRedraw
@return:
    pld
    rtl

@errorNoWindowsAvailable:
    bra @errorNoWindowsAvailable

; A = definition ID
WindowCloseByDefinitionId:
    FN_PROLOGUE_PRESERVE_ONLY_A $08
    jsl WindowFindByDefinitionId
    cmp #0
    beq @Return
    sta $00
    jsl WindowUnlinkFromLL
    jsl WindowUndraw
    ldx $00
    lda #$ffff
    sta a:WINDOW_ACTIVE_STATE::definitionId,x
    jsl WindowRedrawAll
@Return:
    pld
    rtl

; A = character+attribute word
; implicitly uses active window
WindowActiveDrawCharacter:
    FN_PROLOGUE_PRESERVE_ONLY_A $14
    sta $08
    lda a:windowFrontPtr
    jsl WindowGetDefinitionOffset
    tax
    lda f:WindowDefinitionTable+WINDOW_DEFINITION::width,x
    and #$00ff
    sta $10
    lda f:WindowDefinitionTable+WINDOW_DEFINITION::height,x
    and #$00ff
    sta $12
    lda f:WindowDefinitionTable+WINDOW_DEFINITION::offsetToTilemapEntry,x
    sta $0e
    lda a:windowFrontPtr
    tax
    ; Write character into char buffer
    ; Determine offset
    lda a:WINDOW_ACTIVE_STATE::cursorY,x
    ldy $10
    jsl Mult16x8
    clc
    adc a:WINDOW_ACTIVE_STATE::cursorX,x
    asl
    ; Do write into char buffer
    adc a:WINDOW_ACTIVE_STATE::charBufferPtr,x
    tay
    lda $08
    sta a:0,y
    tax
    lda a:windowFrontPtr
    jsr _L_RenderCharacterAtWindowCursorToBg3
    ; Advance cursor
    ldy a:windowFrontPtr
    lda a:WINDOW_ACTIVE_STATE::cursorX,y
    inc
    cmp $10
    bcc @storeCursorX
    lda a:WINDOW_ACTIVE_STATE::cursorY,y
    inc
    cmp $12
    ; If cursorY+1 >= height, return without adjusting cursor
    bcs @return
    ; Else, advance cursor by 1 row and store 1 to cursorX
    sta a:WINDOW_ACTIVE_STATE::cursorY,y
    lda #1
@storeCursorX:
    sta a:WINDOW_ACTIVE_STATE::cursorX,y
@return:
    pld
    rtl

WindowActiveCursorNewline:
    lda a:windowFrontPtr
    jsl WindowGetDefinitionOffset
    tax
    lda f:WindowDefinitionTable+WINDOW_DEFINITION::height,x
    and #$00ff
    dec
    ldx a:windowFrontPtr
    cmp a:WINDOW_ACTIVE_STATE::cursorY,x
    beq @doScroll
    bcc @doScroll
@noScroll:
    inc a:WINDOW_ACTIVE_STATE::cursorY,x
    bra @postScroll
@doScroll:
    jsl WindowActiveScrollCharBuffer
@postScroll:
    stz a:WINDOW_ACTIVE_STATE::cursorX,x
    rtl

WindowActiveScrollCharBuffer:
    rtl
