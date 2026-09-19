section .text

global keyboard_handler
extern screen_print_char

keyboard_handler:
    pusha

    in al, 0x60
    test al, 0x80
    jnz .done
    cmp al, 58
    ja .done

    movzx eax, al
    mov esi, scancode_table
    add esi, eax
    mov al, [esi]
    test al, al
    jz .done

    call screen_print_char

.done:
    mov al, 0x20
    out 0x20, al
    popa
    iretd

section .data
scancode_table:
    db 0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 8
    db 9, 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 10
    db 0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', 39, '`'
    db 0, 92, 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0
    db '*', 0, ' '
