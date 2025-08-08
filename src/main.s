.include "inc/vera.inc.asm"
.include "inc/macros.inc.asm"

.import enable_bitmap_mode
.import clear_screen
.import DecompressRLEToVERA

; ==============================================================================
; INFORMATIONS
; 278 cycles per scanline
; ==============================================================================

CACHE_START_ADDR = $2c00
STRIP_HEIGHT = 30
NUMBER_OF_COLORS_TO_COPY = 128 ; 256, 128, 64, 32 or 16

BYTES_PER_COLOR  = 2
TOTAL_PALETTE_BYTES = NUMBER_OF_PALETTES * NUMBER_OF_COLORS * BYTES_PER_COLOR

.segment "INIT"
.segment "ONCE"

; ==============================================================================
; ZEROPAGE VARIABLES
; ==============================================================================
.segment "ZEROPAGE"
irq_line:          .word $0000
palette_counter:   .byte $00

src_ptr:    .addr $0000 ; 2-byte pointer to the data source
bytes_left: .addr $0000 ; 2-byte counter for remaining bytes to copy

; ==============================================================================
; READ-ONLY DATA (Palettes and Bitmap)
; ==============================================================================
.segment "DATA"
.include "../data/demodata_palettes.s"

; ==============================================================================
; MAIN PROGRAM CODE
; ==============================================================================

.segment "CODE"

    jsr enable_bitmap_mode
    jsr cache_real_palette
    jsr clear_screen
    jsr DecompressRLEToVERA

    ; jsr set_custom_irq_handler
@loop:
    jmp @loop

cache_real_palette:
    ; --- Step 1: Initialize pointers and counters ---
    lda #%00000001
    trb VERA::CTRL          ;clear bit 0 to activate DATA0 address
    lda #<CACHE_START_ADDR
    sta VERA::ADDRx_L
    lda #>CACHE_START_ADDR
    sta VERA::ADDRx_M
    lda #%00010001          ;enable auto-increment address by 1
    sta VERA::ADDRx_H

    ; Set the 'src_ptr' pointer to the start of the palette data
    lda #<palette_data_start
    sta src_ptr
    lda #>palette_data_start
    sta src_ptr+1

    ; Set the 16-bit 'bytes_left' counter to the total number of bytes
    lda #<TOTAL_PALETTE_BYTES
    sta bytes_left
    lda #>TOTAL_PALETTE_BYTES
    sta bytes_left+1

    ; --- Step 2: Main copy loop ---
@copy_loop:
    ; Load a byte from the source using the pointer (indirect mode)
    ldy #$00
    lda (src_ptr),y

    ; Store the byte to VERA (which auto-increments its internal address)
    sta VERA::DATA0

    ; Increment our 2-byte source pointer
    inc src_ptr
    bne @skip_inc_high_byte
    inc src_ptr+1
@skip_inc_high_byte:

    ; Decrement the 16-bit counter for remaining bytes.
    ; This method is readable and safe.
    lda bytes_left
    bne @dec_low_byte   ; If the low byte is not zero, just decrement it
    dec bytes_left+1    ; Otherwise (when it was 0), decrement the high byte
@dec_low_byte:
    dec bytes_left

    ; Check if the counter has reached zero.
    ; If an ORA of both bytes results in zero, it means the entire 16-bit counter is zero.
    lda bytes_left
    ora bytes_left+1
    bne @copy_loop      ; If not zero, continue the loop

    rts

cache_fake_palette:
    lda #%00000001
    trb VERA::CTRL          ;clear bit 0 to activate DATA0 address
    lda #<CACHE_START_ADDR
    sta VERA::ADDRx_L
    lda #>CACHE_START_ADDR
    sta VERA::ADDRx_M
    lda #%00010001          ;enable auto-increment address by 1
    sta VERA::ADDRx_H

    lda #$ff                
    sta VERA::DATA0
    sta VERA::DATA0

    rts

copy_palette_optimized:


    lda #%00000001
    trb VERA::CTRL          ;clear bit 0 to activate DATA0 address (destination)
    lda #$00
    sta VERA::ADDRx_L
    lda #$fa
    sta VERA::ADDRx_M
    lda #%00010001          ;enable auto-increment address by 1
    sta VERA::ADDRx_H

    ldx #NUMBER_OF_COLORS_TO_COPY/8 ; (2 cycles)      
byte_loop:
    .repeat 16            ; 16*32 = 512 bytes to be copied (256 cycles total)
    lda VERA::DATA1       ; read from VRAM cache, increment source address automatically  (4 cycles)
    sta VERA::DATA0       ; Zapisz do VERA, adres w VERA sam się zwiększy (4 cycles)
    .endrepeat
    dex                   ; (2 cycles)
    bne byte_loop         ; (2 cycles)
    
    ; inc palette_pointer+1 ; Przesuń wskaźnik na następną stronę danych źródłowych
    ; dex                   ; Zmniejsz licznik stron
    ; bne page_loop         ; Kopiuj kolejną stronę

    ; lda palette_counter
    ; inc
    ; sta palette_counter
    ; cmp #$03
    ; bne @skip_reset
    ; lda #$00 ; restore original palette_counter value
    ; sta palette_counter

    ; set pointer to point the beggining of the color palette
    ; lda #<color_palette
    ; sta palette_pointer
    ; lda #>color_palette
    ; sta palette_pointer+1

 @skip_reset:   
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

    ; set interrupt to line xxx
    set_line_int $00, $00

    cli
    rts

; ----------------------------------------------- ;
custom_irq_handler:
    ; clear LINE interrupt status
    lda #%00000010      ; 2 cycles
    sta VERA::ISR       ; 4 cycles

    jsr copy_palette_optimized

    ; bring back black color
    ; lda #$00
    ; sta VERA::ADDRx_L
    ; lda #$fa
    ; sta VERA::ADDRx_M
    ; lda #$00
    ; sta VERA::DATA0
    ; sta VERA::DATA0

    ; set irq line to the next batch
    lda palette_counter
    inc
    cmp #NUMBER_OF_PALETTES
    bne @set_next_batch

    ; restore counter and IRQ line
    stz palette_counter
    jsr zero_irq_line
    jmp @end

@set_next_batch:
    sta palette_counter
    jsr increase_irq_line

@end:
    ply
    plx
    pla
    rti

increase_irq_line:
    lda <irq_line
    adc #STRIP_HEIGHT
    sta <irq_line
    sta VERA::IRQLINE_L
    bcc @skip
    inc >irq_line
    lda VERA::IEN
    ora #%10000000
    sta VERA::IEN  ;IRQLINE_H (bit 8)
@skip:
    rts

zero_irq_line:    
    set_line_int $00, $00
    lda #$00
    sta <irq_line

    lda #%00000001
    tsb VERA::CTRL          ;set bit 0 to activate DATA1 address (source)
    lda #<CACHE_START_ADDR
    sta VERA::ADDRx_L
    lda #>CACHE_START_ADDR
    sta VERA::ADDRx_M
    lda #%00010001          ;enable auto-increment address by 1
    sta VERA::ADDRx_H

    rts


