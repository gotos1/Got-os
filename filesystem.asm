; Filesystem constants
FS_MAX_FILES   equ 8
FS_NAME_LEN    equ 16
FS_CONTENT_LEN equ 256

section .text
extern serial_write_char

global fs_init
global fs_find
global fs_create
global fs_write
global fs_read
global fs_delete
global fs_rename
global fs_list

; ================
; fs_init
; Clear all files
; ================
fs_init:
    pusha

    ; clear names (8 * 16 = 128 bytes)
    mov edi, fs_names
    mov ecx, FS_MAX_FILES * FS_NAME_LEN / 4
    xor eax, eax
.clr_names:
    mov [edi], eax
    add edi, 4
    dec ecx
    jnz .clr_names

    ; clear in_use flags (8 bytes)
    mov edi, fs_inuse
    mov ecx, FS_MAX_FILES / 4
    xor eax, eax
.clr_inuse:
    mov [edi], eax
    add edi, 4
    dec ecx
    jnz .clr_inuse

    ; clear sizes (8 * 2 = 16 bytes)
    mov edi, fs_sizes
    mov ecx, FS_MAX_FILES * 2 / 4
    xor eax, eax
.clr_sizes:
    mov [edi], eax
    add edi, 4
    dec ecx
    jnz .clr_sizes

    popa
    ret

; ================
; fs_create
; esi = name (null-terminated)
; returns: eax = index (0..7) or -1 if full
; ================
fs_create:
    pusha

    ; First check if already exists
    call fs_find
    cmp eax, -1
    jne .exists

    ; Find free slot
    xor ebx, ebx
.find_slot:
    cmp ebx, FS_MAX_FILES
    jge .full

    cmp byte [fs_inuse + ebx], 0
    je .found_slot

    inc ebx
    jmp .find_slot

.found_slot:
    ; Mark as in-use
    mov byte [fs_inuse + ebx], 1

    ; Clear size
    mov word [fs_sizes + ebx*2], 0

    ; Copy name: fs_names + ebx*16
    mov eax, ebx
    shl eax, 4
    mov edi, fs_names
    add edi, eax

    mov ecx, FS_NAME_LEN - 1
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

    mov [fs_result], ebx
    popa
    mov eax, [fs_result]
    ret

.exists:
    popa
    mov eax, -1
    ret

.full:
    popa
    mov eax, -2
    ret

; ================
; fs_write
; eax = file index
; esi = content (null-terminated)
; returns: eax = bytes written, or -1 on error
; ================
fs_write:
    pusha

    mov [fs_index_save], eax

    cmp eax, FS_MAX_FILES
    jge .error

    cmp byte [fs_inuse + eax], 0
    je .error

    ; compute content address: fs_contents + eax*256
    mov ebx, eax
    shl ebx, 8
    mov edi, fs_contents
    add edi, ebx

    ; copy content (max 255 bytes)
    xor ecx, ecx
.copy:
    cmp ecx, FS_CONTENT_LEN - 1
    jge .done_copy
    mov al, [esi]
    test al, al
    jz .done_copy
    mov [edi], al
    inc esi
    inc edi
    inc ecx
    jmp .copy

.done_copy:
    mov byte [edi], 0

    ; update size
    mov ebx, [fs_index_save]
    mov word [fs_sizes + ebx*2], cx

    mov [fs_bytes_saved], ecx

    popa
    mov eax, [fs_bytes_saved]
    ret

.error:
    popa
    mov eax, -1
    ret

; ================
; fs_read
; eax = file index
; returns: eax = pointer to content, or -1 on error
;          ecx = size
; ================
fs_read:
    pusha

    cmp eax, FS_MAX_FILES
    jge .error

    cmp byte [fs_inuse + eax], 0
    je .error

    ; compute content address: fs_contents + eax*256
    mov ebx, eax
    shl ebx, 8
    mov edi, fs_contents
    add edi, ebx

    ; get size
    movzx ecx, word [fs_sizes + eax*2]

    mov [fs_result], edi
    mov [fs_size_out], ecx

    popa
    mov eax, [fs_result]
    mov ecx, [fs_size_out]
    ret

.error:
    popa
    mov eax, -1
    xor ecx, ecx
    ret

; ================
; fs_delete
; eax = file index
; returns: eax = 0 on success, -1 on error
; ================
fs_delete:
    pusha

    mov [fs_index_save], eax

    cmp eax, FS_MAX_FILES
    jge .error

    cmp byte [fs_inuse + eax], 0
    je .error

    ; mark as not in use
    mov byte [fs_inuse + eax], 0

    ; clear size
    mov word [fs_sizes + eax*2], 0

    ; clear name (16 bytes)
    mov ebx, eax
    shl ebx, 4
    mov edi, fs_names
    add edi, ebx
    mov ecx, 4
    xor eax, eax
.clr_name:
    mov [edi], eax
    add edi, 4
    dec ecx
    jnz .clr_name

    popa
    mov eax, 0
    ret

.error:
    popa
    mov eax, -1
    ret

; ================
; fs_list
; Print all files in the filesystem
; ================
fs_list:
    pusha

    xor ebx, ebx
    xor ecx, ecx

.loop:
    cmp ebx, FS_MAX_FILES
    jge .done

    cmp byte [fs_inuse + ebx], 0
    je .next

    ; Compute name address: fs_names + ebx*16
    mov eax, ebx
    shl eax, 4
    mov esi, fs_names
    add esi, eax

    ; Print name
.print:
    mov al, [esi]
    test al, al
    jz .end_name
    call serial_write_char
    inc esi
    jmp .print

.end_name:
    ; Print newline
    mov al, 13
    call serial_write_char
    mov al, 10
    call serial_write_char

    inc ecx

.next:
    inc ebx
    jmp .loop

.done:
    test ecx, ecx
    jnz .exit

    mov esi, msg_no_files
    call print_local

.exit:
    popa
    ret

; Helper to print string via serial
print_local:
    pusha
.pl:
    mov al, [esi]
    test al, al
    jz .done
    call serial_write_char
    inc esi
    jmp .pl
.done:
    popa
    ret

; ================
; fs_rename
; esi = old name
; edi = new name
; returns: eax = 0 on success, -1 on error
; ================
fs_rename:
    pusha

    mov [fs_rename_new], edi

    ; Find old file
    call fs_find
    cmp eax, -1
    je .error

    mov [fs_index_save], eax

    ; Check new name doesn't already exist
    mov esi, [fs_rename_new]
    call fs_find
    cmp eax, -1
    jne .error

    ; Get name address: fs_names + index*16
    mov eax, [fs_index_save]
    shl eax, 4
    mov edi, fs_names
    add edi, eax

    ; Copy new name
    mov esi, [fs_rename_new]
    mov ecx, 15
.copy:
    mov al, [esi]
    test al, al
    jz .done
    mov [edi], al
    inc esi
    inc edi
    dec ecx
    jnz .copy
.done:
    mov byte [edi], 0

    popa
    mov eax, 0
    ret

.error:
    popa
    mov eax, -1
    ret

; ================
; fs_find
; esi = name (null-terminated)
; returns: eax = index (0..7) or -1 if not found
; ================
fs_find:
    pusha
    xor ebx, ebx
.loop:
    cmp ebx, FS_MAX_FILES
    jge .not_found

    cmp byte [fs_inuse + ebx], 0
    je .next

    ; compute address of name: fs_names + ebx*16
    mov eax, ebx
    shl eax, 4
    mov edi, fs_names
    add edi, eax

    ; inline string compare
    push esi
    push edi
.cmp:
    mov al, [esi]
    mov dl, [edi]
    cmp al, dl
    jne .neq
    test al, al
    jz .eq
    inc esi
    inc edi
    jmp .cmp
.eq:
    pop edi
    pop esi
    mov [fs_result], ebx
    popa
    mov eax, [fs_result]
    ret
.neq:
    pop edi
    pop esi

.next:
    inc ebx
    jmp .loop

.not_found:
    popa
    mov eax, -1
    ret

section .data
fs_result: dd 0
msg_no_files: db "(no files)", 13, 10, 0
fs_index_save:   dd 0
fs_bytes_saved:  dd 0
fs_rename_new:   dd 0
fs_size_out:     dd 0

section .bss
fs_names:    resb FS_MAX_FILES * FS_NAME_LEN
fs_inuse:    resb FS_MAX_FILES
fs_sizes:    resw FS_MAX_FILES
fs_contents: resb FS_MAX_FILES * FS_CONTENT_LEN
