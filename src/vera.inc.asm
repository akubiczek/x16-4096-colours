.ifndef VERA_INC
VERA_INC=1

.scope VERA

    ; External registers

    .struct
                .org    $9F20
    ADDRx_L         .byte           ; Address for data port access
    ADDRx_M         .byte
    ADDRx_H         .byte
    DATA0           .byte           ; First data port
    DATA1           .byte           ; Second data port
    CTRL            .byte           ; Control register
    IEN             .byte           ; Interrupt enable bits
    ISR             .byte           ; Interrupt flags
    IRQLINE_L       .byte           ; Line where IRQ will occur

                .org    $9F28

    SCANLINE_L      .byte           ; Line where IRQ occured (the same address as IRQLINE_L)
    DC_VIDEO        .byte           ;
    DC_HSCALE       .byte           ;
    DC_VSCALE       .byte           ;
    DC_BORDER       .byte           ;

                .org    $9F29

    DC_HSTART       .byte           ;
    DC_HSTOP        .byte           ;
    DC_VSTART       .byte           ;
    DC_VSTOP        .byte           ;

                .org    $9F2D

    L0_CONFIG       .byte           ;
    L0_MAPBASE      .byte           ;
    L0_TILEBASE     .byte           ;
    L0_HSCROLL_L    .byte           ;
    L0_HSCROLL_H    .byte           ;
    L0_VSCROLL_L    .byte           ;
    L0_VSCROLL_H    .byte           ;
    L1_CONFIG       .byte           ;
    L1_MAPBASE      .byte           ;
    L1_TILEBASE     .byte           ;
    L1_HSCROLL_L    .byte           ;
    L1_HSCROLL_H    .byte           ;
    L1_VSCROLL_L    .byte           ;
    L1_VSCROLL_H    .byte           ;
    AUDIO_CTRL      .byte           ;
    AUDIO_RATE      .byte           ;
    AUDIO_DATA      .byte           ;
    SPI_DATA        .byte           ;
    SPI_CTRL        .byte           ;

    .endstruct

.endscope

.endif ;VERA_INC
