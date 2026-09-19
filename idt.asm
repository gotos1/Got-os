extern keyboard_handler

section .text

global idt_init
idt_init:
    mov edi, idt
    mov ecx, 256
    xor eax, eax
.clear:
    mov [edi], eax
    add edi, 4
    mov [edi], eax
    add edi, 4
    dec ecx
    jnz .clear

    mov word [idt_ptr], 2047
    mov dword [idt_ptr + 2], idt

    lidt [idt_ptr]

    ; Add keyboard handler (interrupt 33)
    mov eax, keyboard_handler
    mov word [idt + 33*8], ax
    shr eax, 16
    mov word [idt + 33*8 + 6], ax

    ; Set selector, zero, type
    mov word [idt + 33*8 + 2], 0x08
    mov byte [idt + 33*8 + 4], 0
    mov byte [idt + 33*8 + 5], 0x8E

    ret

section .bss
align 16
idt:
    resb 2048

section .data
idt_ptr:
    dw 0
    dd 0
