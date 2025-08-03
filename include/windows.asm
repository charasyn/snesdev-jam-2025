NUM_WINDOW_DEFINITIONS = 10
NUM_ACTIVE_WINDOWS = 4
MAX_WINDOW_AREA = 384 ; characters

.struct WINDOW_DEFINITION
    posX .byte
    posY .byte
    width .byte
    height .byte
    offsetToTilemapEntry .word
.endstruct

.struct WINDOW_ACTIVE_STATE
    definitionId .word
    attributes .word
    ptrBefore .word
    ptrAfter .word
    cursorX .word
    cursorY .word
    charBufferPtr .word
.endstruct
