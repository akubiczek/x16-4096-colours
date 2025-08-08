.include "inc/vera.inc.asm"

; ==============================================================================
; GRAPHICS RELATED PROCEDURES
; ==============================================================================

.export enable_bitmap_mode
.export clear_screen

.segment "CODE"

; switches X16 to 320x240 bitmap mode
enable_bitmap_mode:
    lda #%00000111
    sta VERA::L1_CONFIG
    lda #%00000000
    sta VERA::L1_TILEBASE
    lda #%00000000
    sta VERA::CTRL
    lda #64 ; 320x240
    sta VERA::DC_HSCALE ; 320 h pixels
    sta VERA::DC_VSCALE ; 240 v pixels
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

; fills screen with #$00 pixels
clear_screen:
    lda #%00000001
    trb VERA::CTRL
    lda #$00
    sta VERA::ADDRx_L
    lda #$00
    sta VERA::ADDRx_M
    lda #%00010000
    sta VERA::ADDRx_H

    lda #$00
    ldy #$00
@cpy_next_256:    
    ldx #$00
@cpy_next:
    sta VERA::DATA0
    sta VERA::DATA0
    sta VERA::DATA0
    sta VERA::DATA0
    inx
    cpx #200
    bne @cpy_next
    iny
    cpy #96 ; 200*96*4 = 76800 => all pixels
    bne @cpy_next_256
    rts