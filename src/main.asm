.include "vera.inc.asm"

.segment "INIT"
.segment "ONCE"
.segment "ZEROPAGE"
bitmap_pointer:    .addr $0000
palette_pointer:   .addr $0000

.segment "DATA"
.include "palette.inc.asm"
.include "bitmap.inc.asm"

.segment "CODE"

@loop:
    sei
    jsr bitmamp_mode
    jsr reset_pointers
    jsr copy_palette
    jsr copy_bitmap
    jmp @loop

reset_pointers:
    ; set pointer to point the beggining of the bitmap
    lda #<bitmap_data
    sta bitmap_pointer
    lda #>bitmap_data
    sta bitmap_pointer+1

   ; set pointer to point the beggining of the color palette
    lda #<color_palette
    sta palette_pointer
    lda #>color_palette
    sta palette_pointer+1
    rts

copy_palette:
    lda #%00000001
    trb VERA::CTRL
    lda #$00
    sta VERA::ADDRx_L
    lda #$fa
    sta VERA::ADDRx_M
    lda #%00010001
    sta VERA::ADDRx_H

    ; copy 512 bytes
    ldx #$02
    ldy #$00
@cpy:
    lda (palette_pointer)
    sta VERA::DATA0
    clc
    lda palette_pointer
    adc #$01
    sta palette_pointer
    lda palette_pointer+1
    adc #$00 ; adc adds with the carry!
    sta palette_pointer+1
    iny
    cpy #$00
    bne @cpy
    dex
    bne @cpy
    rts

copy_bitmap:
    lda #%00000001
    trb VERA::CTRL
    lda #85 ; 320 / 2 - 150 / 2
    sta VERA::ADDRx_L
    lda #$00
    sta VERA::ADDRx_M
    lda #%00010000
    sta VERA::ADDRx_H

    ldx #$00
@cpy:
    ldy #$00 ; column
@cpy_line:
    lda (bitmap_pointer), y
    sta VERA::DATA0
    iny
    cpy #150 ; image width
    bne @cpy_line

    ; increase destination address by 170 (320-150)
    clc
    lda VERA::ADDRx_L
    adc #170
    sta VERA::ADDRx_L
    lda VERA::ADDRx_M
    adc #$00 ; adc adds with the carry!
    sta VERA::ADDRx_M
    lda VERA::ADDRx_H
    adc #$00 ; adc adds with the carry!
    sta VERA::ADDRx_H

    clc
    lda bitmap_pointer
    adc #150
    sta bitmap_pointer
    lda bitmap_pointer+1
    adc #$00 ; adc adds with the carry!
    sta bitmap_pointer+1 ; increase high byte of address
    inx
    cpx #212 ; image height
    bne @cpy
    rts

bitmamp_mode:
    lda #%00000111
    sta VERA::L1_CONFIG
    lda #%00000000
    sta VERA::L1_TILEBASE
    lda #%00000000
    sta VERA::CTRL
    lda #64
    sta VERA::DC_HSCALE
    sta VERA::DC_VSCALE
    lda #%00000010 ; DCSEL=1
    sta VERA::CTRL
    lda #$00
    sta VERA::DC_HSTART
    sta VERA::DC_VSTART
    lda #$a0
    sta VERA::DC_HSTOP
    lda #$f0
    sta VERA::DC_VSTOP
    rts