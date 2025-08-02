.macro mov32_r_const dpdest, value
    lda #(.loword(value))
    sta z:dpdest
    lda #(.hiword(value))
    sta z:.lobyte(dpdest+2)
.endmacro

.macro mov32_r_r dpdest, dpsrc
    lda z:dpsrc
    sta z:dpdest
    lda z:.lobyte(dpsrc+2)
    sta z:.lobyte(dpdest+2)
.endmacro

.macro mult_imm multiplicand
    .if multiplicand = 0
        lda #0
    .elseif multiplicand = 1
    .elseif multiplicand = 2
        asl
    .elseif multiplicand = 3
        sta z:0
        asl
        adc z:0
    .elseif multiplicand = 4
        asl
        asl
    .elseif multiplicand = 5
        sta z:0
        asl
        asl
        adc z:0
    .elseif multiplicand = 6
        asl
        sta z:0
        asl
        adc z:0
    .elseif multiplicand = 7
        sta z:0
        asl
        asl
        asl
        sec
        sbc z:0
    .elseif multiplicand = 8
        asl
        asl
        asl
; todo: what's a better way to do this? should we generate a python script?
    .elseif multiplicand = 20
        asl
        asl
        sta z:0
        asl
        asl
        adc z:0
    .elseif multiplicand = 32
        asl
        asl
        asl
        asl
        asl
    .endif
.endmacro

.macro FN_PROLOGUE_PRESERVE_NONE dp_size
    rep #$31
    phd
    tdc
    adc #.loword(-dp_size)
    tcd
.endmacro

.macro FN_PROLOGUE_PRESERVE_ONLY_A dp_size
    rep #$31
    phd
    tay
    tdc
    adc #.loword(-dp_size)
    tcd
    tya
.endmacro

.macro FN_PROLOGUE dp_size
    rep #$31
    phd
    pha
    tdc
    adc #.loword(-dp_size)
    tcd
    pla
.endmacro
