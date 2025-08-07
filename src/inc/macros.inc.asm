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