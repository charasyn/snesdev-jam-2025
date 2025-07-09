.include "error.inc"

; EXPORTS
.export ClearOam
.export SpritemapToOam
.export Walkman_Spritemap

; IMPORTS
; main.asm
.import oam_buffer, oam_x, oam_y, oam_attr, oam_tile
.import oamhi_buffer

.segment "SPRITEMAPS"
; SPRITEMAP FORMAT:
; relative_x, relative_y, tile, attr, flags (1 = big, 2 = end of spritemap)
Walkman_Spritemap:
    .byte   0, -8,  0, $30, %01
    .byte   0,  8, 32, $30, %01

    .byte  16, -8,  2, $30, %01
    .byte  16,  8, 34, $30, %01

    .byte  32, -8,  4, $30, %01
    .byte  32,  8, 36, $30, %01

    .byte -16, -8,  8, $30, %01
    .byte -16,  8, 38, $30, %01

    .byte -32, -8, 10, $30, %01
    .byte -32,  8, 40, $30, %11

.segment "SPRITE_RAM"
oam_offset:    .res 2
oamhi_ptr:     .res 2
oamhi_bits:    .res 1
spritemap_x:   .res 1
spritemap_y:   .res 1

.segment "SPRITE"
; Clears the OAM buffer
; Clobbers: A, X
ClearOam:       php

                sep  #$30
                lda  #%01010101
                sta  oamhi_bits

                rep  #$20
                stz  oam_offset
                lda  #oamhi_buffer
                sta  oamhi_ptr

                lda  #(224<<8)|1
                ldx  #128-4
                : sta oam_buffer+128*0,x
                  sta oam_buffer+128*1,x
                  sta oam_buffer+128*2,x
                  sta oam_buffer+128*3,x
                  dex
                  dex
                  dex
                  dex
                  bpl :-

                ; Set X position msb
                lda #%010101010101010101
                ldx #30
                : sta oamhi_buffer,x
                  dex
                  dex
                  bpl :-

                plp
                rtl

; A low  = Spritemap bank
; X      = Spritemap address
; A high = Base X position
; Y      = Base Y position
SpritemapToOam: php
                phb
                phd

                pea  spritemap_x & $FF00
                pld

                sep  #$20
                and  #~$40
                pha
                plb

                xba
                sta <spritemap_x
                tya       ; A is 8-bits, indexes are 16-bits
                sta <spritemap_y

                rep  #$11 ; + clc
                ldy <oam_offset
  @Loop:          ; clc   ; Carry is always clear
                  lda <spritemap_x
                  adc a:0,x
                  sta  oam_x,y

                  lsr <oamhi_bits ; TODO: 9TH X POSITION BIT

                  clc
                  lda <spritemap_y
                  adc a:1,x
                  sta  oam_y,y

                  lda a:2,x
                  sta  oam_tile,y

                  lda a:3,x
                  sta  oam_attr,y

                  lda a:4,x
                  lsr  a
                  ror <oamhi_bits ; Size bit

                  lsr  a          ; Spritemap END bit
                  bcs  @ExitLoop

                .repeat 5
                  inx
                .endrepeat

                .repeat 4
                  iny
                .endrepeat

                  cpy  #128*4
                  bcs  @OamLimit

                  tya
                  and  #15
                  bne  @Loop

                  lda <oamhi_bits
                  sta  (<oamhi_ptr)
                  inc <oamhi_ptr

                  lda  #%01010101
                  sta <oamhi_bits
                  bra  @Loop

@ExitLoop:      sec
                ror  <oamhi_bits
                lsr  <oamhi_bits
                sec
                ror  <oamhi_bits
                lsr  <oamhi_bits

                lda  <oamhi_bits
                sta  (<oamhi_ptr)

                pld
                plb
                plp
                rtl

@OamLimit:      THROW Error::OamError
