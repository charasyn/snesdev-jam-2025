.macro mov32_r_const dpaddr, value
    lda #(.loword(value))
    sta z:dpaddr
    lda #(.hiword(value))
    sta z:.lobyte(dpaddr+2)
.endmacro
