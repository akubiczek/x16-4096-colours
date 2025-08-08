; Image data for 'assets/images/input.png' compressed using RLE
; Original size: 38400B, compressed: 9145B
pixel_data_rle:
    ; --- 320 pixels of color $00 ---
    .byte $fe, $00  ; Repeat $00 for 127 times
    .byte $fe, $00  ; Repeat $00 for 127 times
    .byte $c1, $00  ; Repeat $00 for 66 times

    ; --- 320 pixels of color $01 ---
    .byte $fe, $01  ; Repeat $01 for 127 times
    .byte $fe, $01  ; Repeat $01 for 127 times
    .byte $c1, $01  ; Repeat $00 for 66 times

    ; --- 320 pixels of color $02 ---
    .byte $fe, $05  ; Repeat $02 for 127 times
    .byte $fe, $05  ; Repeat $02 for 127 times
    .byte $c1, $05  ; Repeat $00 for 66 times
    ; --- Terminator ---

    ; --- 320 pixels of color $03 (as three literal packets, per request) ---
    .byte $7f       ; Literal packet, 128 bytes
    .byte $06,$10,$06,$08,$06,$08,$06,$08,$06,$08,$06,$08,$06,$08,$06,$08
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$01,$02
    .byte $7f       ; Literal packet, 128 bytes
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $3f       ; Literal packet, 64 bytes
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
    .byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03

        ; --- 320 pixels of color $00 ---
    .byte $fe, $00  ; Repeat $00 for 127 times
    .byte $fe, $00  ; Repeat $00 for 127 times
    .byte $c1, $00  ; Repeat $00 for 66 times

    ; --- 320 pixels of color $01 ---
    .byte $fe, $01  ; Repeat $01 for 127 times
    .byte $fe, $01  ; Repeat $01 for 127 times
    .byte $c1, $01  ; Repeat $00 for 66 times

    ; --- 320 pixels of color $02 ---
    .byte $fe, $05  ; Repeat $02 for 127 times
    .byte $fe, $05  ; Repeat $02 for 127 times
    .byte $c1, $05  ; Repeat $00 for 66 times
    ; --- Terminator ---

    ; --- Terminator ---
    .byte $ff
