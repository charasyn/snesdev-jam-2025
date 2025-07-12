.struct COROUTINE_STATE
    sleepTime .word
    stackUsed .word
    stack .byte 16
.endstruct
.define NUM_COROUTINES 16
