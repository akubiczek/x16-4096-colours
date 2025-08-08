.include "inc/vera.inc.asm"

; ==============================================================================
; RLE decompression routine to VERA memory
;
; Input:
;   - Address of the compressed data pointed to by a zero-page pointer
;     `ZP_RLE_PTR` (2 bytes).
; Output:
;   - Decompressed data written to VERA memory, starting at address $00000.
; ==============================================================================

.export DecompressRLEToVERA

.segment "ZEROPAGE"
rle_ptr: .addr $0000  ; 2-byte pointer to the source RLE data (compressed bitmap data)

.segment "DATA"
.include "../data/demodata_pixels.s"

; ==============================================================================
;                                 MAIN ROUTINE
; ==============================================================================
.segment "CODE"

DecompressRLEToVERA:
    ; Initialize the RLE decompressor
    ; Load the address of the compressed data into our zeropage pointer.
    lda #<pixel_data_rle
    sta rle_ptr
    lda #>pixel_data_rle
    sta rle_ptr+1

    ; Set the destination address in VERA
    ; Set VERA to write to VRAM starting at address $00000
    lda #%00000001      ; Set address select to 1 (DATA1 port)
    sta VERA::CTRL
    lda #$00            ; Low byte of VRAM address
    sta VERA::ADDRx_L
    lda #$00            ; Middle byte of VRAM address
    sta VERA::ADDRx_M
    lda #%00010000      ; High byte: VRAM Address (bit 4) and increment by 1
    sta VERA::ADDRx_H

    ; Main decompression loop
decompress_loop:
    ; Load the control byte from the RLE stream
    ldy #$00
    lda (rle_ptr),y
    jsr inc_rle_ptr ; Use a subroutine to increment the pointer

    ; Check for the terminator byte ($FF)
    cmp #$ff
    beq done

    ; Check packet type: run packet (MSB=1) or literal packet (MSB=0)
    tay
    and #%10000000
    bne handle_run_packet

; --- Handle literal packet (uncompressed data) ---
handle_literal_packet:
    tya
    ; The value in A is (length - 1). Use X as a loop counter.
    tax
literal_copy_loop:
    ldy #$00
    lda (rle_ptr),y
    sta VERA::DATA1      ; Write byte directly to VERA
    jsr inc_rle_ptr
    dex
    bpl literal_copy_loop
    jmp decompress_loop

; --- Handle run packet (repeated data) ---
handle_run_packet:
    tya
    and #$7f             ; Isolate the lower 7 bits (length - 1)
    tax                  ; Transfer (length - 1) to X as a loop counter

    ; Load the single byte that will be repeated
    ldy #$00
    lda (rle_ptr),y
    jsr inc_rle_ptr
    
run_loop:
    sta VERA::DATA1      ; Write the repeated byte to VERA
    dex
    bpl run_loop
    jmp decompress_loop

done:
    rts                  ; End the routine

; --- Internal subroutine to increment the 16-bit RLE pointer ---
inc_rle_ptr:
    inc rle_ptr
    bne end_inc
    inc rle_ptr+1
end_inc:
    rts