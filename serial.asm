section .text

global serial_init
global serial_write_char
global serial_read_char

; ==================
; serial_init
; COM1 at 0x3F8
; ==================
serial_init:
    pusha

    ; Disable interrupts
    mov dx, 0x3F9
    mov al, 0x00
    out dx, al

    ; Enable DLAB (set baud rate divisor)
    mov dx, 0x3FB
    mov al, 0x80
    out dx, al

    ; Set divisor to 3 (38400 baud)
    mov dx, 0x3F8
    mov al, 0x03
    out dx, al
    mov dx, 0x3F9
    mov al, 0x00
    out dx, al

    ; 8 bits, no parity, one stop bit (8N1)
    mov dx, 0x3FB
    mov al, 0x03
    out dx, al

    ; Enable FIFO, clear, 14-byte threshold
    mov dx, 0x3FA
    mov al, 0xC7
    out dx, al

    ; Enable IRQs, RTS/DSR set
    mov dx, 0x3FC
    mov al, 0x0B
    out dx, al

    popa
    ret

; ==================
; serial_write_char
; al = character to write
; ==================
serial_write_char:
    pusha
    mov bl, al
.wait:
    mov dx, 0x3FD
    in al, dx
    test al, 0x20
    jz .wait

    mov dx, 0x3F8
    mov al, bl
    out dx, al

    popa
    ret

; ==================
; serial_read_char
; returns: al = character (0 if none)
; ==================
serial_read_char:
    pusha
    mov dx, 0x3FD
    in al, dx
    test al, 0x01
    jz .empty

    mov dx, 0x3F8
    in al, dx
    mov [.result], al
    popa
    mov al, [.result]
    ret

.empty:
    popa
    mov al, 0
    ret

section .data
.result:
    db 0
