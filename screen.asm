section .text

global screen_clear
global screen_print_char
global screen_newline
global screen_scroll
global screen_print_string

; ==================
; screen_clear
; ==================
screen_clear:
    pusha
    mov edi, 0xB8000
    mov ecx, 80 * 25
    mov ax, 0x0F20
.loop:
    mov [edi], ax
    add edi, 2
    dec ecx
    jnz .loop
    mov dword [cursor_pos], 0xB8000
    popa
    ret

; ==================
; screen_scroll
; ==================
screen_scroll:
    pusha
    ; Copy lines 1-24 to lines 0-23
    mov esi, 0xB8000 + 160
    mov edi, 0xB8000
    mov ecx, 80 * 24 * 2 / 4
.loop:
    mov eax, [esi]
    mov [edi], eax
    add esi, 4
    add edi, 4
    dec ecx
    jnz .loop

    ; Clear last line
    mov ecx, 80 * 2 / 4
    mov eax, 0x0F200F20
.clr:
    mov [edi], eax
    add edi, 4
    dec ecx
    jnz .clr

    ; Move cursor up one line
    mov eax, [cursor_pos]
    sub eax, 160
    mov [cursor_pos], eax

    popa
    ret

; ==================
; screen_newline
; ==================
screen_newline:
    pusha
    mov eax, [cursor_pos]
    ; Compute current column
    mov ebx, eax
    sub ebx, 0xB8000
    ; ebx = offset in bytes
    ; divide by 2 -> char index
    shr ebx, 1
    ; 80 chars per row
    mov edx, 0
    mov ecx, 80
    mov eax, ebx
    div ecx
    ; eax = row, edx = column
    inc eax
    ; new cursor = row*80*2 + 0
    imul eax, 160
    add eax, 0xB8000

    ; Check if beyond screen
    mov ebx, 0xB8000 + 80 * 25 * 2
    cmp eax, ebx
    jl .ok
    call screen_scroll
    jmp .done
.ok:
    mov [cursor_pos], eax
.done:
    popa
    ret

; ==================
; screen_print_char
; al = character
; ==================
screen_print_char:
    pusha
    mov bl, al
    mov edi, [cursor_pos]

    cmp bl, 10
    je .newline
    cmp bl, 13
    je .newline

    mov ah, 0x0F
    mov al, bl
    mov [edi], ax
    add edi, 2
    mov [cursor_pos], edi

    ; Check if past last column
    mov eax, edi
    sub eax, 0xB8000
    mov edx, 0
    mov ecx, 160
    div ecx
    cmp edx, 0
    jne .done
    ; We're at column 0 -> newline
    call screen_newline
    jmp .done

.newline:
    call screen_newline

.done:
    popa
    ret

; ==================
; screen_print_string
; esi = pointer to null-terminated string
; ==================
screen_print_string:
    pusha
.next:
    mov al, [esi]
    test al, al
    jz .done
    call screen_print_char
    inc esi
    jmp .next
.done:
    popa
    ret

section .data
global cursor_pos
cursor_pos:
    dd 0xB8000


