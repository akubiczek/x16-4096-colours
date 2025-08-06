; ==============================================================================
; RLE decompression routine to VERA memory
;
; Input:
;   - Address of the compressed data pointed to by a zero-page pointer
;     `ZP_RLE_PTR` (2 bytes).
; Output:
;   - Decompressed data written to VERA memory, starting at address $00000.
; ==============================================================================

; --- Constant definitions ---
VERA_ADDRx_L = $9f20
VERA_ADDRx_M = $9f21
VERA_ADDRx_H = $9f22
VERA_DATA0   = $9f23
VERA_CTRL    = $9f25

; --- Zero-page pointer definitions ---
ZP_RLE_PTR   = $fb  ; 2-byte pointer to RLE data (address: $fb, $fc)

; ==============================================================================
;                                 MAIN ROUTINE
; ==============================================================================
DecompressRLEToVERA:
    ; --- Step 1: Set the destination address in VERA ---
    ; Set VERA to write to VRAM (address space 0) starting at address $00000
    ; with an auto-increment of 1 byte for the DATA0 port.

    lda #%00000001      ; Set address increment to 1
    sta VERA_CTRL       ; We want to set the increment bit, not clear it.

    lda #$00            ; Low byte of VRAM address ($00000)
    sta VERA_ADDRx_L
    lda #$00            ; Middle byte of VRAM address ($00000)
    sta VERA_ADDRx_M
    lda #%00010000      ; High byte: VRAM Address (bit 4) and DATA0 port selection (bits 0-3)
    sta VERA_ADDRx_H

    ; --- Step 2: Main decompression loop ---
    ; Y will be used as a counter for inner loops and as an offset for the pointer
    ldy #$00

decompress_loop:
    ; Load the control byte from the RLE stream
    lda (ZP_RLE_PTR),y
    inc ZP_RLE_PTR
    bne !+
    inc ZP_RLE_PTR+1
!:

    ; Check for the terminator byte
    cmp #$ff
    beq done

    ; Check if it's a run packet (MSB=1) or a literal packet (MSB=0)
    bmi handle_run_packet ; Branch if Minus (MSB=1)

; --- Handle literal packet ---
; --- It means the incoming bytes are not compressed and should be copied "as it is" ---
handle_literal_packet:
    tax               
.copy_loop:
    ldy #$00            ; Offset for the pointer is always 0
    lda (ZP_RLE_PTR),y
    sta VERA_DATA0      ; Write byte to VERA
    inc ZP_RLE_PTR
    bne !+
    inc ZP_RLE_PTR+1
!:
    dex
    bpl .copy_loop ; Loop `length` times (from N-1 down to 0)
    jmp decompress_loop

; --- Handle run packet ---
handle_run_packet:
    and #$7f            ; Isolate the lower 7 bits (length-1)
    tax                 ; Transfer (length-1) to X as a loop counter

    ; Load the byte to be repeated
    ldy #$00
    lda (ZP_RLE_PTR),y
    inc ZP_RLE_PTR
    bne !+
    inc ZP_RLE_PTR+1
!:
    ; Loop to write the same byte repeatedly
.run_loop:
    sta VERA_DATA0      ; Write the repeated byte (it's in A) to VERA
    dex
    bpl .run_loop
    jmp decompress_loop

done:
    rts                 ; End the routine