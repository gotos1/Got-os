section .text
global kmain
extern serial_init
extern serial_write_char
extern serial_read_char
extern fs_init
extern fs_list
extern fs_create
extern fs_delete
extern fs_find
extern fs_read
extern edit_main

kmain:
    call serial_init
    call fs_init
    mov dword [line_len], 0
    call splash
    mov esi, msg_welcome
    call serial_print

.loop:
    mov esi, msg_prompt
    call serial_print

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

    call execute_command

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
msg_welcome:  db 13, 10, "GOT[os] v0.3 - shell", 13, 10, 0
msg_prompt:   db "> ", 0
msg_unknown:  db "Unknown command. Type 'help'.", 13, 10, 0
msg_shutdown: db "Shutting down...", 13, 10, 0
msg_version:  db "GOT[os] v0.3", 13, 10
              db "Kernel: x86 32-bit", 13, 10
              db "Features:", 13, 10
              db "  shell, filesystem (RAM), editor", 13, 10
              db "  13 commands, CPUID, colors", 13, 10, 0
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
          db "  touch <name>   - create file", 13, 10,0

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
line_len:     resd 1
cpu_vendor:   resb 16

splash_art:
    db 13, 10, 13, 10
    db "     #######   #######  ########", 13, 10
    db "    ##        ##    ##     ##", 13, 10
    db "    ##  ###   ##    ##     ##", 13, 10
    db "    ##    ##  ##    ##     ##", 13, 10
    db "     #######   #######     ##", 13, 10
    db 13, 10
    db "         GOT[os] v0.3", 13, 10
    db "         Booting...", 13, 10
    db 0
