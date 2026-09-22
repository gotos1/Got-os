section .text

global diskfs_format
global diskfs_save
global diskfs_load
global diskfs_delete
global diskfs_list
extern serial_write_char
extern disk_write_sector
extern disk_read_sector
extern fs_find
extern fs_read
extern fs_create
extern fs_write

; ================
; diskfs_format
; Format the disk: write superblock + clear file table
; ================
diskfs_format:
    pusha

    ; ---- Zero out buffer ----
    mov edi, diskfs_buffer
    mov ecx, 128
    xor eax, eax
.zero1:
    mov [edi], eax
    add edi, 4
    dec ecx
    jnz .zero1

    ; ---- Write magic "GOTD" (0x474F5444) ----
    mov dword [diskfs_buffer], 0x474F5444

    ; ---- Write sector 0 ----
    xor eax, eax
    mov esi, diskfs_buffer
    call disk_write_sector

    ; ---- Zero out buffer again ----
    mov edi, diskfs_buffer
    mov ecx, 128
    xor eax, eax
.zero2:
    mov [edi], eax
    add edi, 4
    dec ecx
    jnz .zero2

    ; ---- Write sector 1 (empty file table) ----
    mov eax, 1
    mov esi, diskfs_buffer
    call disk_write_sector

    ; ---- Zero out sectors 2-17 (file content) ----
    mov ebx, 2
.zero_content:
    cmp ebx, 18
    jge .done_content

    mov eax, ebx
    mov esi, diskfs_buffer
    call disk_write_sector

    inc ebx
    jmp .zero_content
.done_content:

    popa
    ret

; ================
; diskfs_save
; esi = filename (in RAM fs)
; returns: eax = 0 on success, -1 on error
; ================
diskfs_save:
    pusha

    mov [diskfs_name], esi

    ; ---- Read sector 1 (file table) into buffer ----
    mov eax, 1
    mov edi, diskfs_buffer
    call disk_read_sector

    ; ---- Find empty slot (16 entries × 32 bytes) ----
    xor ecx, ecx
.find_slot:
    cmp ecx, 16
    jge .error

    ; Entry offset = ecx * 32
    mov eax, ecx
    shl eax, 5
    ; Check byte at offset +24 (in_use flag)
    cmp byte [diskfs_buffer + eax + 24], 0
    je .found_slot

    inc ecx
    jmp .find_slot

.found_slot:
    mov [diskfs_slot], ecx
    jmp .save_data

.error:
    popa
    mov eax, -1
    ret

.save_data:
    ; ---- Find file in RAM fs ----
    mov esi, [diskfs_name]
    call fs_find
    cmp eax, -1
    je .error

    ; ---- Read file content ----
    call fs_read
    cmp eax, -1
    je .error

    mov [diskfs_src], eax
    mov [diskfs_len], ecx

    ; ---- Copy name into file table entry ----
    mov ecx, [diskfs_slot]
    mov eax, ecx
    shl eax, 5
    lea edi, [diskfs_buffer + eax]

    mov esi, [diskfs_name]
    mov ecx, 16
.copy_name_ds:
    mov al, [esi]
    test al, al
    jz .name_done_ds
    mov [edi], al
    inc esi
    inc edi
    dec ecx
    jnz .copy_name_ds
.name_done_ds:
    mov byte [edi], 0

    ; ---- Write file table back to sector 1 ----
    mov eax, 1
    mov esi, diskfs_buffer
    call disk_write_sector

    ; ---- Copy content to diskfs_content (zero it first) ----
    mov edi, diskfs_content
    mov ecx, 128
    xor eax, eax
.zero_content_ds:
    mov [edi], eax
    add edi, 4
    dec ecx
    jnz .zero_content_ds

    mov esi, [diskfs_src]
    mov edi, diskfs_content
    mov ecx, [diskfs_len]
    test ecx, ecx
    jz .content_done_ds
.copy_content_ds:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    dec ecx
    jnz .copy_content_ds
.content_done_ds:

    ; ---- Write content to sector 2 + slot ----
    mov eax, [diskfs_slot]
    add eax, 2
    mov esi, diskfs_content
    call disk_write_sector

    ; ---- Update in_use flag and size in file table ----
    mov eax, 1
    mov edi, diskfs_buffer
    call disk_read_sector

    mov ecx, [diskfs_slot]
    mov eax, ecx
    shl eax, 5
    mov byte [diskfs_buffer + eax + 24], 1     ; in_use
    mov ecx, [diskfs_len]
    mov word [diskfs_buffer + eax + 16], cx    ; size

    mov eax, 1
    mov esi, diskfs_buffer
    call disk_write_sector

    popa
    mov eax, 0
    ret

; ================
; diskfs_load
; esi = filename
; returns: eax = 0 on success, -1 on error
; ================
diskfs_load:
    pusha

    mov [diskfs_name], esi

    ; ---- Read sector 1 (file table) ----
    mov eax, 1
    mov edi, diskfs_buffer
    call disk_read_sector

    ; ---- Search for filename ----
    xor ecx, ecx
.search_loop:
    cmp ecx, 16
    jge .error

    ; Entry offset = ecx * 32
    mov eax, ecx
    shl eax, 5

    ; Check in_use flag (offset 24)
    cmp byte [diskfs_buffer + eax + 24], 0
    je .search_next

    ; Compare name
    lea edi, [diskfs_buffer + eax]
    mov esi, [diskfs_name]
.cmp_name:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .search_next
    test al, al
    jz .found
    inc esi
    inc edi
    jmp .cmp_name

.search_next:
    inc ecx
    jmp .search_loop

.found:
    mov [diskfs_slot], ecx

    ; ---- Read content from sector 2 + slot ----
    mov eax, ecx
    add eax, 2
    mov edi, diskfs_content
    call disk_read_sector

    ; ---- Create file in RAM fs ----
    mov esi, [diskfs_name]
    call fs_create
    cmp eax, 0
    jl .error

    ; ---- Write content to RAM fs ----
    mov esi, diskfs_content
    call fs_write
    cmp eax, -1
    jl .error

    popa
    mov eax, 0
    ret

.error:
    popa
    mov eax, -1
    ret

; ================
; diskfs_delete
; esi = filename
; returns: eax = 0 on success, -1 on error
; ================
diskfs_delete:
    pusha

    mov [diskfs_name], esi

    ; ---- Read sector 1 (file table) ----
    mov eax, 1
    mov edi, diskfs_buffer
    call disk_read_sector

    ; ---- Search for filename ----
    xor ecx, ecx
.search_loop_del:
    cmp ecx, 16
    jge .error_del

    ; Entry offset = ecx * 32
    mov eax, ecx
    shl eax, 5

    ; Check in_use flag (offset 24)
    cmp byte [diskfs_buffer + eax + 24], 0
    je .search_next_del

    ; Compare name
    lea edi, [diskfs_buffer + eax]
    mov esi, [diskfs_name]
.cmp_name_del:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .search_next_del
    test al, al
    jz .found_del
    inc esi
    inc edi
    jmp .cmp_name_del

.search_next_del:
    inc ecx
    jmp .search_loop_del

.found_del:
    ; ---- Mark as free ----
    mov eax, ecx
    shl eax, 5

    ; Clear in_use
    mov byte [diskfs_buffer + eax + 24], 0

    ; Clear size
    mov word [diskfs_buffer + eax + 16], 0

    ; Clear name (16 bytes)
    lea edi, [diskfs_buffer + eax]
    mov ecx, 4
    xor eax, eax
.clr_name_del:
    mov [edi], eax
    add edi, 4
    dec ecx
    jnz .clr_name_del

    ; ---- Write file table back ----
    mov eax, 1
    mov esi, diskfs_buffer
    call disk_write_sector

    popa
    mov eax, 0
    ret

.error_del:
    popa
    mov eax, -1
    ret

; ================
; diskfs_list
; Print all files on disk
; ================
diskfs_list:
    pusha

    ; ---- Read sector 1 (file table) ----
    mov eax, 1
    mov edi, diskfs_buffer
    call disk_read_sector

    ; ---- Iterate 16 entries ----
    xor ecx, ecx
    xor edx, edx         ; count of files
.list_loop:
    cmp ecx, 16
    jge .list_done

    mov eax, ecx
    shl eax, 5

    ; Check in_use
    cmp byte [diskfs_buffer + eax + 24], 0
    je .list_next

    ; Print name
    lea esi, [diskfs_buffer + eax]
.print_name:
    mov al, [esi]
    test al, al
    jz .name_end
    call serial_write_char
    inc esi
    jmp .print_name
.name_end:
    mov al, 13
    call serial_write_char
    mov al, 10
    call serial_write_char
    inc edx

.list_next:
    inc ecx
    jmp .list_loop

.list_done:
    test edx, edx
    jnz .list_exit
    mov esi, msg_disk_empty
    call print_local_list

.list_exit:
    popa
    ret

print_local_list:
    pusha
.pl:
    mov al, [esi]
    test al, al
    jz .pl_done
    call serial_write_char
    inc esi
    jmp .pl
.pl_done:
    popa
    ret

section .bss
diskfs_buffer: resb 512
diskfs_content: resb 512
diskfs_name:   resd 1
diskfs_slot:   resd 1
diskfs_src:    resd 1
diskfs_len:    resd 1


section .data
msg_disk_empty: db "(disk empty)", 13, 10, 0
