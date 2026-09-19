section .text

global pic_init
pic_init:
    ; ICW1 - start init
    mov al, 0x11
    out 0x20, al
    out 0xA0, al

    ; ICW2 - remap offsets
    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al

    ; ICW3 - wiring
    mov al, 0x04
    out 0x21, al
    mov al, 0x02
    out 0xA1, al

    ; ICW4 - 8086 mode
    mov al, 0x01
    out 0x21, al
    out 0xA1, al

    ; OCW1 - mask all except IRQ1 (keyboard)
    mov al, 0xFD
    out 0x21, al
    mov al, 0xFF
    out 0xA1, al

    ret

