.include "inc/vera.inc.asm"

.macro  set_line_int LINE_L, LINE_H
    lda #LINE_L
    sta $9F28 ;IRQLINE_L (Write only)

    lda VERA::IEN
    .if (LINE_H > 0)
    ora #%10000000
    .else
    and #%01111111
    .endif
    sta VERA::IEN  ;IRQLINE_H (bit 8)
.endmacro

.segment "INIT"
.segment "ONCE"
.segment "ZEROPAGE"
palette_counter:   .byte $00
bitmap_pointer:    .addr $0000
palette_pointer:   .addr $0000

.segment "DATA"
color_palette:
.include "data/demodata_palettes.s"
.include "data/demodata_pixels.s"

.segment "CODE"

    jsr enable_bitmap_mode
    jsr reset_pointers
    jsr clear_bitmap
    ; jsr copy_bitmap
    jsr set_custom_irq_handler
@loop:
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


copy_palette_optimized:
    lda #%00000001
    trb VERA::CTRL
    lda #$00
    sta VERA::ADDRx_L
    lda #$fa
    sta VERA::ADDRx_M
    lda #%00010001
    sta VERA::ADDRx_H

    ldx #$02              ; Licznik stron (2 * 256 bajtów)
page_loop:
    ldy #$00              ; Resetuj indeks Y dla każdej strony
byte_loop:
    lda (palette_pointer),y ; Wczytaj bajt ze źródła (np. $A000+Y)
    sta VERA::DATA0       ; Zapisz do VERA, adres w VERA sam się zwiększy
    iny                   ; Następny bajt
    bne byte_loop         ; Pętla 256 razy
    
    inc palette_pointer+1 ; Przesuń wskaźnik na następną stronę danych źródłowych
    dex                   ; Zmniejsz licznik stron
    bne page_loop         ; Kopiuj kolejną stronę

    lda palette_counter
    inc
    sta palette_counter
    cmp #$03
    bne @skip_reset
    lda #$00 ; restore original palette_counter value
    sta palette_counter

    ; set pointer to point the beggining of the color palette
    lda #<color_palette
    sta palette_pointer
    lda #>color_palette
    sta palette_pointer+1

 @skip_reset:   
    rts

clear_bitmap:
    lda #%00000001
    trb VERA::CTRL
    lda #$00 ; 320 / 2 - 150 / 2
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

; ----------------------------------------------- ;
set_custom_irq_handler:
    sei

    ; set my handler
    lda #<custom_irq_handler
    sta $0314
    lda #>custom_irq_handler
    sta $0315

    ; enable LINE and VSYNC interrupt
    lda #%00000010 ; set LINE and VSYNC bits in IEN register
    sta VERA::IEN

    ; set interrupt to line $00a
    set_line_int $0a, $00

    cli
    rts

; ----------------------------------------------- ;
custom_irq_handler:
    ; clear LINE interrupt status
    lda #%00000010      ; 2 cycles
    sta VERA::ISR       ; 4 cycles

    jsr copy_palette_optimized

    ; bring back black color
    lda #$00
    sta VERA::ADDRx_L
    lda #$fa
    sta VERA::ADDRx_M

    lda #$00
    sta VERA::DATA0
    sta VERA::DATA0

    ply
    plx
    pla
    rti

custom_irq_handler_off:
    ; 278 cycles per scanline, 556 per two lines

    ; clear LINE interrupt status
    lda #%00000010      ; 2 cycles
    sta VERA::ISR       ; 4 cycles


    lda #%00000001      ; 2 cycles
    trb VERA::CTRL      ; 5 cycles
    lda #$00            ; 2 cycles
    sta VERA::ADDRx_L   ; 4 cycles
    lda #$fa            ; 2 cycles 21
    sta VERA::ADDRx_M   ; 4 cycles
    lda #%00010001      ; 2 cycles
    sta VERA::ADDRx_H   ; 4 cycles
    lda #$ff            ; 2 cycles
    sta VERA::DATA0     ; 4 cycles
    sta VERA::DATA0     ; 4 cycles 41

    lda #$00            ; 4 cycles
@loop:
    inc                 ; 1 cycle
    cmp #102            ; 2 cycles
    bne @loop           ; 2 cycles

    lda #%00000001
    trb VERA::CTRL
    lda #$00
    sta VERA::ADDRx_L
    lda #$fa
    sta VERA::ADDRx_M
    lda #%00010001
    sta VERA::ADDRx_H
    lda #$00
    sta VERA::DATA0
    sta VERA::DATA0

    ply
    plx
    pla
    rti

