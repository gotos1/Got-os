section .text
global kmain
extern serial_init
extern serial_write_char
extern serial_read_char
extern fs_init
extern disk_init
extern fs_list
extern fs_create
extern fs_delete
extern fs_write
extern fs_rename
extern disk_write_sector
extern disk_read_sector
extern diskfs_format
extern diskfs_save
extern diskfs_load
extern diskfs_delete
extern diskfs_list
extern fs_find
extern fs_read
extern edit_main

kmain:
    call serial_init
    call disk_init
    call fs_init
    mov dword [line_len], 0
    call splash
    mov esi, msg_welcome
    call serial_print

.loop:
    cmp byte [pending_action], 0
    jne .skip_prompt

    mov esi, msg_prompt
    call serial_print

.skip_prompt:

.readline:
    call serial_read_char
    test al, al
    jz .readline

    cmp al, 127
    je .backspace
    cmp al, 8
    je .backspace

    cmp al, 13
    je .enter
    cmp al, 10
    je .enter

    mov ecx, [line_len]
    cmp ecx, 63
    jae .readline

    mov esi, line_buffer
    add esi, ecx
    mov [esi], al
    inc ecx
    mov [line_len], ecx

    call serial_write_char
    jmp .readline

.backspace:
    mov ecx, [line_len]
    test ecx, ecx
    jz .readline
    dec ecx
    mov [line_len], ecx
    mov esi, line_buffer
    add esi, ecx
    mov byte [esi], 0
    mov al, 8
    call serial_write_char
    mov al, ' '
    call serial_write_char
    mov al, 8
    call serial_write_char
    jmp .readline

.enter:
    mov ecx, [line_len]
    mov esi, line_buffer
    add esi, ecx
    mov byte [esi], 0

    mov al, 13
    call serial_write_char
    mov al, 10
    call serial_write_char

       ; Check pending action
    cmp byte [pending_action], 0
    jne .do_pending

    call execute_command
    jmp .after_cmd

.do_pending:
    call handle_pending

.after_cmd:
    mov dword [line_len], 0
    jmp .loop
; ================
splash:
    pusha

    mov esi, ansi_clear
    call serial_print

    mov esi, splash_art
    call serial_print


    mov ecx, 0xFFFFFFF
.delay:
    loop .delay

    popa
    ret

; ================
; parse_number
; esi = string, returns eax = number (or -1)
; ================
parse_number:
    pusha
    xor eax, eax
.loop:
    mov bl, [esi]
    test bl, bl
    jz .done
    cmp bl, ' '
    je .done
    cmp bl, 13
    je .done
    cmp bl, 10
    je .done
    cmp bl, '0'
    jl .error
    cmp bl, '9'
    jg .error
    imul eax, eax, 10
    sub bl, '0'
    movzx ebx, bl
    add eax, ebx
    inc esi
    jmp .loop
.done:
    mov [pn_result], eax
    popa
    mov eax, [pn_result]
    ret
.error:
    popa
    mov eax, -1
    ret

; ================
; print_hex_byte
; al = byte to print as 2 hex digits
; ================
print_hex_byte:
    pusha
    mov bl, al
    shr al, 4
    and al, 0x0F
    call .nibble
    mov al, bl
    and al, 0x0F
    call .nibble
    popa
    ret
.nibble:
    cmp al, 10
    jl .digit
    add al, 'A' - 10
    jmp .out
.digit:
    add al, '0'
.out:
    call serial_write_char
    ret

; ================
serial_print:
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
; handle_pending
; ================
handle_pending:
    pusha

    mov esi, line_buffer
    mov edi, msg_yes
    call strcmp
    test al, al
    jz .cancel

    cmp byte [pending_action], 1
    jne .cancel

    mov esi, pending_name
    call diskfs_delete
    cmp eax, 0
    jl .fail

    mov esi, msg_drm_ok
    call serial_print
    jmp .clear

.fail:
    mov esi, msg_drm_fail
    call serial_print
    jmp .clear

.cancel:
    mov esi, msg_drm_cancel
    call serial_print

.clear:
    mov byte [pending_action], 0
    mov dword [line_len], 0

    popa
    ret


; ================
execute_command:
    pusha

    ; Skip leading spaces
    mov esi, line_buffer
.skip_spaces:
    cmp byte [esi], ' '
    jne .trim_done
    inc esi
    jmp .skip_spaces

.trim_done:
    ; If no spaces, skip the copy
    cmp esi, line_buffer
    je .no_trim

    ; Copy trimmed string back to line_buffer
    mov edi, line_buffer
.copy_trim:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    test al, al
    jnz .copy_trim

.no_trim:
    mov esi, line_buffer
    mov al, [esi]
    test al, al
    jz .done

    mov esi, line_buffer
    mov edi, cmd_help
    call strcmp
    test al, al
    jnz .help

    mov esi, line_buffer
    mov edi, cmd_version
    call strcmp
    test al, al
    jnz .version

    mov esi, line_buffer
    mov edi, cmd_clear
    call strcmp
    test al, al
    jnz .clear

    mov esi, line_buffer
    mov edi, cmd_off
    call strcmp
    test al, al
    jnz .off

    mov esi, line_buffer
    mov edi, cmd_sysinfo
    call strcmp
    test al, al
    jnz .sysinfo

    mov esi, line_buffer
    mov edi, cmd_reboot
    call strcmp
    test al, al
    jnz .reboot

   mov esi, line_buffer
   mov edi, cmd_ls
   call strcmp
   test al, al
   jnz .ls

    mov esi, line_buffer
    mov edi, prefix_echo
    call startswith
    test al, al
    jnz .echo

    mov esi, line_buffer
    mov edi, prefix_color
    call startswith
    test al, al
    jnz .color

    mov esi, line_buffer
    mov edi, cmd_touch
    call startswith
    test al, al
    jnz .touch

    mov esi, line_buffer
    mov edi, cmd_rm
    call startswith
    test al, al
    jnz .rm

    mov esi, line_buffer
    mov edi, cmd_cat
    call startswith
    test al, al
    jnz .cat

    mov esi, line_buffer
    mov edi, cmd_edit
    call startswith
    test al, al
    jnz .edit

    mov esi, line_buffer
    mov edi, cmd_write
    call startswith
    test al, al
    jnz .write

    mov esi, line_buffer
    mov edi, cmd_cp
    call startswith
    test al, al
    jnz .cp

    mov esi, line_buffer
    mov edi, cmd_mv
    call startswith
    test al, al
    jnz .mv

    mov esi, line_buffer
    mov edi, cmd_dformat
    call strcmp
    test al, al
    jnz .dformat

    mov esi, line_buffer
    mov edi, cmd_dread
    call startswith
    test al, al
    jnz .dread

    mov esi, line_buffer
    mov edi, cmd_dsave
    call startswith
    test al, al
    jnz .dsave

    mov esi, line_buffer
    mov edi, cmd_dload
    call startswith
    test al, al
    jnz .dload

    mov esi, line_buffer
    mov edi, cmd_drm
    call startswith
    test al, al
    jnz .drm

    mov esi, line_buffer
    mov edi, cmd_dls
    call strcmp
    test al, al
    jnz .dls

    mov esi, msg_unknown
    call serial_print
    jmp .done

.help:
    mov esi, msg_help
    call serial_print
    jmp .done

.version:
    mov esi, msg_version
    call serial_print
    jmp .done

.sysinfo:
    mov esi, msg_sysinfo
    call serial_print

    xor eax, eax
    cpuid
    mov [cpu_vendor], ebx
    mov [cpu_vendor + 4], edx
    mov [cpu_vendor + 8], ecx
    mov byte [cpu_vendor + 12], 0

    mov esi, msg_cpu
    call serial_print
    mov esi, cpu_vendor
    call serial_print
    mov al, 13
    call serial_write_char
    mov al, 10
    call serial_write_char

    jmp .done

.reboot:
    mov esi, msg_reboot
    call serial_print

    ; ACPI reset
    mov al, 0x06
    out 0xCF9, al

    ; Triple fault fallback
    lidt [null_idt]
    int 0x03

.hang:
    cli
    hlt
    jmp .hang

.ls:
    call fs_list
    jmp .done

.touch:
    mov esi, line_buffer
    add esi, 6          ; skip "touch "
    call fs_create
    cmp eax, 0
    jl .touch_err
    mov esi, msg_touch_ok
    call serial_print
    jmp .done

.touch_err:
    mov esi, msg_touch_fail
    call serial_print
    jmp .done

.rm:
    mov esi, line_buffer
    add esi, 3          ; skip "rm "
    call fs_find
    cmp eax, -1
    je .rm_notfound
    call fs_delete
    cmp eax, 0
    jl .rm_fail
    mov esi, msg_rm_ok
    call serial_print
    jmp .done

.rm_notfound:
    mov esi, msg_rm_notfound
    call serial_print
    jmp .done

.rm_fail:
    mov esi, msg_rm_fail
    call serial_print
    jmp .done

.cat:
    mov esi, line_buffer
    add esi, 4          ; skip "cat "
    call fs_find
    cmp eax, -1
    je .cat_notfound
    call fs_read
    cmp eax, -1
    je .cat_fail
    mov esi, eax
    call serial_print
    mov al, 13
    call serial_write_char
    mov al, 10
    call serial_write_char
    jmp .done

.cat_notfound:
    mov esi, msg_cat_notfound
    call serial_print
    jmp .done

.cat_fail:
    mov esi, msg_cat_fail
    call serial_print
    jmp .done

.edit:
    mov esi, line_buffer
    add esi, 5          ; skip "edit "
    call edit_main
    jmp .done

.write:
    mov esi, line_buffer
    add esi, 6          ; skip "write "

    ; Find space separating filename from text
    mov edi, esi
.find_space:
    mov al, [edi]
    test al, al
    jz .write_usage
    cmp al, ' '
    je .found_space
    inc edi
    jmp .find_space

.found_space:
    mov byte [edi], 0    ; null-terminate filename
    inc edi
    mov ebx, edi         ; ebx = text pointer

    call fs_find
    cmp eax, -1
    je .write_notfound

    mov esi, ebx
    call fs_write
    cmp eax, -1
    jl .write_fail

    mov esi, msg_write_ok
    call serial_print
    jmp .done

.write_usage:
    mov esi, msg_write_usage
    call serial_print
    jmp .done

.write_notfound:
    mov esi, msg_write_notfound
    call serial_print
    jmp .done

.write_fail:
    mov esi, msg_write_fail
    call serial_print
    jmp .done

.cp:
    mov esi, line_buffer
    add esi, 3          ; skip "cp "

    mov edi, esi
.find_space_cp:
    mov al, [edi]
    test al, al
    jz .cp_usage
    cmp al, ' '
    je .found_space_cp
    inc edi
    jmp .find_space_cp

.found_space_cp:
    mov byte [edi], 0
    inc edi
    mov [cp_new_name], edi

    ; Find source
    call fs_find
    cmp eax, -1
    je .cp_notfound

    ; Read source
    call fs_read
    cmp eax, -1
    je .cp_fail
    mov [cp_src_ptr], eax
    mov [cp_src_len], ecx

    ; Create destination
    mov esi, [cp_new_name]
    call fs_create
    cmp eax, 0
    jl .cp_fail

    ; Write content to destination
    mov esi, [cp_src_ptr]
    call fs_write
    cmp eax, -1
    jl .cp_fail

    mov esi, msg_cp_ok
    call serial_print
    jmp .done

.cp_usage:
    mov esi, msg_cp_usage
    call serial_print
    jmp .done

.cp_notfound:
    mov esi, msg_cp_notfound
    call serial_print
    jmp .done

.cp_fail:
    mov esi, msg_cp_fail
    call serial_print
    jmp .done

.dformat:
    call diskfs_format
    mov esi, msg_dformat_ok
    call serial_print
    jmp .done

.dread:
    mov esi, line_buffer
    add esi, 6          ; skip "dread "
    call parse_number
    cmp eax, -1
    je .dread_usage

    mov edi, dread_buffer
    call disk_read_sector

    ; Print hex dump of first 16 bytes
    mov esi, msg_dread_hdr
    call serial_print

    xor ecx, ecx
.dread_loop:
    cmp ecx, 16
    jge .dread_done

    mov al, [dread_buffer + ecx]
    call print_hex_byte

    mov al, ' '
    call serial_write_char

    inc ecx
    jmp .dread_loop

.dread_done:
    mov al, 13
    call serial_write_char
    mov al, 10
    call serial_write_char
    jmp .done

.dread_usage:
    mov esi, msg_dread_usage
    call serial_print
    jmp .done

.dsave:
    mov esi, line_buffer
    add esi, 6          ; skip "dsave "
    call diskfs_save
    cmp eax, 0
    jl .dsave_fail
    mov esi, msg_dsave_ok
    call serial_print
    jmp .done

.dsave_fail:
    mov esi, msg_dsave_fail
    call serial_print
    jmp .done

.dls:
    call diskfs_list
    jmp .done

.drm:
    mov esi, line_buffer
    add esi, 4          ; skip "drm "

    ; Copy name to pending_name
    mov edi, pending_name
    mov ecx, 15
.copy_pn:
    mov al, [esi]
    test al, al
    jz .pn_done
    mov [edi], al
    inc esi
    inc edi
    dec ecx
    jnz .copy_pn
.pn_done:
    mov byte [edi], 0

    ; Set pending
    mov byte [pending_action], 1

    ; Print: Delete 'name'? (yes/no):
    mov esi, msg_drm_ask
    call serial_print
    mov esi, pending_name
    call serial_print
    mov esi, msg_drm_ask2
    call serial_print

    jmp .done

.dload:
    mov esi, line_buffer
    add esi, 6          ; skip "dload "
    call diskfs_load
    cmp eax, 0
    jl .dload_fail
    mov esi, msg_dload_ok
    call serial_print
    jmp .done

.dload_fail:
    mov esi, msg_dload_fail
    call serial_print
    jmp .done

.mv:
    mov esi, line_buffer
    add esi, 3          ; skip "mv "

    mov edi, esi
.find_space_mv:
    mov al, [edi]
    test al, al
    jz .mv_usage
    cmp al, ' '
    je .found_space_mv
    inc edi
    jmp .find_space_mv

.found_space_mv:
    mov byte [edi], 0
    inc edi

    call fs_rename
    cmp eax, 0
    jl .mv_fail

    mov esi, msg_mv_ok
    call serial_print
    jmp .done

.mv_usage:
    mov esi, msg_mv_usage
    call serial_print
    jmp .done

.mv_fail:
    mov esi, msg_mv_fail
    call serial_print
    jmp .done

.clear:
    mov esi, ansi_clear
    call serial_print
    jmp .done

.off:
    mov esi, msg_shutdown
    call serial_print
    mov dx, 0x604
    mov ax, 0x2000
    out dx, ax
    jmp .done

.echo:
    mov esi, line_buffer
    add esi, 5
    call serial_print
    mov al, 13
    call serial_write_char
    mov al, 10
    call serial_write_char
    jmp .done

.color:
    mov esi, line_buffer
    add esi, 6
    mov al, [esi]
    test al, al
    jz .color_bad
    cmp al, '0'
    je .color0
    cmp al, '1'
    je .color1
    cmp al, '2'
    je .color2
    cmp al, '3'
    je .color3
    cmp al, '4'
    je .color4
    cmp al, '5'
    je .color5
    cmp al, '6'
    je .color6
    cmp al, '7'
    je .color7
.color_bad:
    mov esi, msg_color_bad
    call serial_print
    jmp .done

.color0:
    mov esi, ansi_c0
    call serial_print
    jmp .done
.color1:
    mov esi, ansi_c1
    call serial_print
    jmp .done
.color2:
    mov esi, ansi_c2
    call serial_print
    jmp .done
.color3:
    mov esi, ansi_c3
    call serial_print
    jmp .done
.color4:
    mov esi, ansi_c4
    call serial_print
    jmp .done
.color5:
    mov esi, ansi_c5
    call serial_print
    jmp .done
.color6:
    mov esi, ansi_c6
    call serial_print
    jmp .done
.color7:
    mov esi, ansi_c7
    call serial_print

.done:
    popa
    ret

; ================
strcmp:
    pusha
.loop:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .neq
    test al, al
    jz .eq
    inc esi
    inc edi
    jmp .loop
.eq:
    popa
    mov al, 1
    ret
.neq:
    popa
    mov al, 0
    ret

; ================
startswith:
    pusha
.loop:
    mov al, [edi]
    test al, al
    jz .yes
    mov bl, [esi]
    cmp al, bl
    jne .no
    inc esi
    inc edi
    jmp .loop
.yes:
    popa
    mov al, 1
    ret
.no:
    popa
    mov al, 0
    ret

null_idt:
    dw 0
    dd 0

section .data
splash_art:
    db 13, 10, 13, 10
    db "     #######   #######  ########", 13, 10
    db "    ##        ##    ##     ##", 13, 10
    db "    ##  ###   ##    ##     ##", 13, 10
    db "    ##    ##  ##    ##     ##", 13, 10
    db "     #######   #######     ##", 13, 10
    db 13, 10
    db "         GOT[os] v0.4", 13, 10
    db "         Booting...", 13, 10
    db 0
msg_welcome:  db 13, 10, "GOT[os] v0.4 - shell", 13, 10, 0
msg_prompt:   db "> ", 0
msg_unknown:  db "Unknown command. Type 'help'.", 13, 10, 0
msg_shutdown: db "Shutting down...", 13, 10, 0
msg_version:  db "GOT[os] v0.4", 13, 10
              db "Kernel: x86 32-bit", 13, 10
              db "Features:", 13, 10
              db "  shell, RAM filesystem, disk storage", 13, 10
              db "  editor, 22 commands, CPUID, colors", 13, 10, 0
msg_sysinfo:  db "=== System Info ===", 13, 10, 0
msg_cpu:      db "CPU: ", 0
msg_color_bad: db "Use color 0-7", 13, 10, 0
msg_reboot:   db "Rebooting...", 13, 10, 0
msg_touch_ok:   db "File created.", 13, 10, 0
msg_touch_fail: db "Failed (exists or full).", 13, 10, 0
msg_rm_ok:       db "File deleted.", 13, 10, 0
msg_rm_notfound: db "File not found.", 13, 10, 0
msg_rm_fail:     db "Failed to delete.", 13, 10, 0
msg_cat_notfound: db "File not found.", 13, 10, 0
msg_cat_fail:     db "Failed to read.", 13, 10, 0
msg_write_ok:       db "Written.", 13, 10, 0
msg_write_usage:    db "Usage: write <file> <text>", 13, 10, 0
msg_write_notfound: db "File not found. Use touch first.", 13, 10, 0
msg_write_fail:     db "Failed to write.", 13, 10, 0
msg_cp_ok:       db "Copied.", 13, 10, 0
msg_cp_usage:    db "Usage: cp <src> <dst>", 13, 10, 0
msg_cp_notfound: db "Source not found.", 13, 10, 0
msg_cp_fail:     db "Failed to copy.", 13, 10, 0
msg_mv_ok:       db "Renamed.", 13, 10, 0
msg_mv_usage:    db "Usage: mv <old> <new>", 13, 10, 0
msg_mv_fail:     db "Failed to rename.", 13, 10, 0
msg_dformat_ok:  db "Disk formatted.", 13, 10, 0
msg_dread_hdr:   db "Hex: ", 0
msg_dread_usage: db "Usage: dread <sector>", 13, 10, 0
msg_dsave_ok:    db "Saved to disk.", 13, 10, 0
msg_dsave_fail:  db "Failed to save.", 13, 10, 0
msg_dload_ok:    db "Loaded from disk.", 13, 10, 0
msg_dload_fail:  db "File not found on disk.", 13, 10, 0
msg_drm_ask:     db "Delete '", 0
msg_drm_ask2:    db "'? (yes/no): ", 0
msg_drm_ok:      db "Deleted from disk.", 13, 10, 0
msg_drm_fail:    db "Failed to delete.", 13, 10, 0
msg_drm_cancel:  db "Cancelled.", 13, 10, 0
msg_yes:         db "yes", 0
msg_help: db "Commands:", 13, 10
          db "  help           - show this", 13, 10
          db "  version        - show version", 13, 10
          db "  clear          - clear screen", 13, 10
          db "  echo <text>    - print text", 13, 10
          db "  color 0-7      - change color", 13, 10
          db "  sysinfo        - system information", 13, 10
          db "  off system     - shutdown", 13, 10
          db "  reboot         - restart system", 13, 10
          db "  ls             - list files", 13, 10
          db "  rm <name>      - delete file", 13, 10
          db "  cat <name>     - show file content", 13, 10
          db "  edit <name>    - edit file", 13, 10
          db "  touch <name>   - create file", 13, 10
          db "  write <f> <t>  - write text to file", 13, 10
          db "  cp <src> <dst> - copy file", 13, 10
          db "  dformat        - format disk", 13, 10
          db "  dread <sector> - read sector (hex)", 13, 10
          db "  dsave <file>   - save file to disk", 13, 10
          db "  dload <file>   - load file from disk", 13, 10
          db "  mv <old> <new> - rename file", 13, 10
          db "  dls            - list disk files", 13, 10
          db "  drm <file>     - delete file from disk", 13, 10,0

cmd_help:     db "help", 0
cmd_version:  db "version", 0
cmd_clear:    db "clear", 0
cmd_off:      db "off system", 0
cmd_sysinfo:  db "sysinfo", 0
cmd_ls:       db "ls", 0
cmd_touch:    db "touch ", 0
cmd_reboot:   db "reboot", 0
cmd_rm:       db "rm ", 0
cmd_cat:      db "cat ", 0
cmd_edit:     db "edit ", 0
cmd_write:    db "write ", 0
cmd_cp:       db "cp ", 0
cmd_mv:       db "mv ", 0
cmd_dsave:    db "dsave ", 0
cmd_dload:    db "dload ", 0
cmd_dls:      db "dls", 0
cmd_drm:      db "drm ", 0
cmd_dformat:  db "dformat", 0
cmd_dread:    db "dread ", 0

prefix_echo:  db "echo ", 0
prefix_color: db "color ", 0

ansi_clear:   db 27, "[2J", 27, "[H", 0
ansi_c0:      db 27, "[30m", 0
ansi_c1:      db 27, "[31m", 0
ansi_c2:      db 27, "[32m", 0
ansi_c3:      db 27, "[33m", 0
ansi_c4:      db 27, "[34m", 0
ansi_c5:      db 27, "[35m", 0
ansi_c6:      db 27, "[36m", 0
ansi_c7:      db 27, "[37m", 0

section .bss
line_buffer:  resb 64
dread_buffer: resb 512
pending_action: resb 1
pending_name:   resb 16
line_len:     resd 1
cp_new_name:  resd 1
cp_src_ptr:   resd 1
cp_src_len:   resd 1
pn_result:    resd 1
cpu_vendor:   resb 16

