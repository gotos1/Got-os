section .text

global edit_main
extern fs_find
extern fs_create
extern fs_read
extern fs_write
extern serial_read_char
extern serial_write_char

; ================
; edit_print
; esi = string
; ================
edit_print:
    pusha
.next:
    mov al, [esi]
    test al, al
    jz .done
    call serial_write_char
    inc esi
    jmp .next
.done:
    popa
    ret

; ================
; edit_main
; esi = filename (null-terminated)
; ================
edit_main:
    pusha

    ; Save filename (max 15 chars)
    mov edi, edit_name
    mov ecx, 15
.copy_name:
    mov al, [esi]
    test al, al
    jz .name_done
    mov [edi], al
    inc esi
    inc edi
    dec ecx
    jnz .copy_name
.name_done:
    mov byte [edi], 0

    ; Try to find the file
    mov esi, edit_name
    call fs_find
    cmp eax, -1
    je .create_new

    ; File exists - save index, read content
    mov [edit_file_index], eax
    call fs_read
    cmp eax, -1
    je .create_new

    ; Copy content to edit_buffer
    mov esi, eax
    mov edi, edit_buffer
    mov [edit_len], ecx
    test ecx, ecx
    jz .after_load
.copy_content:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    dec ecx
    jnz .copy_content
.after_load:
    mov byte [edi], 0
    jmp .show_header

.create_new:
    mov esi, edit_name
    call fs_create
    cmp eax, 0
    jl .err_create
    mov [edit_file_index], eax
    mov dword [edit_len], 0
    mov byte [edit_buffer], 0
    jmp .show_header

.err_create:
    mov esi, msg_err_create
    call edit_print
    popa
    ret

.show_header:
    mov esi, msg_header_1
    call edit_print
    mov esi, edit_name
    call edit_print
    mov esi, msg_header_2
    call edit_print

    ; Print existing content
    mov esi, edit_buffer
    call edit_print

    ; newline before user input
    mov al, 13
    call serial_write_char
    mov al, 10
    call serial_write_char

; ================
.edit_loop:
    call serial_read_char
    test al, al
    jz .edit_loop

    cmp al, 17              ; Ctrl+Q
    je .save_and_exit

    cmp al, 19              ; Ctrl+S
    je .do_save

    cmp al, 13
    je .do_newline
    cmp al, 10
    je .do_newline

    cmp al, 127
    je .do_backspace
    cmp al, 8
    je .do_backspace

    ; Regular char
    mov ecx, [edit_len]
    cmp ecx, 2046
    jae .edit_loop

    mov edi, edit_buffer
    add edi, ecx
    mov [edi], al
    inc ecx
    mov [edit_len], ecx
    mov byte [edi + 1], 0

    call serial_write_char
    jmp .edit_loop

.do_newline:
    mov ecx, [edit_len]
    cmp ecx, 2045
    jae .edit_loop

    mov edi, edit_buffer
    add edi, ecx
    mov byte [edi], 13
    inc ecx
    mov byte [edi + 1], 10
    inc ecx
    mov byte [edi + 2], 0
    mov [edit_len], ecx

    mov al, 13
    call serial_write_char
    mov al, 10
    call serial_write_char
    jmp .edit_loop

.do_backspace:
    mov ecx, [edit_len]
    test ecx, ecx
    jz .edit_loop
    dec ecx
    mov [edit_len], ecx
    mov edi, edit_buffer
    add edi, ecx
    mov byte [edi], 0

    mov al, 8
    call serial_write_char
    mov al, ' '
    call serial_write_char
    mov al, 8
    call serial_write_char
    jmp .edit_loop

.do_save:
    call edit_save
    mov esi, msg_saved
    call edit_print
    jmp .edit_loop

.save_and_exit:
    call edit_save
    mov esi, msg_exited
    call edit_print
    popa
    ret

; ================
; edit_save
; ================
edit_save:
    pusha
    mov eax, [edit_file_index]
    mov esi, edit_buffer
    call fs_write
    popa
    ret

section .data
msg_header_1: db 13, 10, "--- Editing: ", 0
msg_header_2: db " ---", 13, 10, "(Ctrl+S = save, Ctrl+Q = quit)", 13, 10, 0
msg_saved:    db 13, 10, "[Saved]", 13, 10, 0
msg_exited:   db 13, 10, "[Exited edit mode]", 13, 10, 0
msg_err_create: db "Error creating file.", 13, 10, 0

section .bss
edit_buffer:     resb 2048
edit_len:        resd 1
edit_file_index: resd 1
edit_name:       resb 16
