section .text
global disk_read_sector

global disk_init
extern serial_write_char
global disk_write_sector

; ================
; disk_init
; Just detect if an ATA drive exists.
; Prints 'D' if found, 'N' if not.
; ================
disk_init:
    pusha

    ; Soft reset (SRST bit)
    mov dx, 0x1F7
    mov al, 0x04
    out dx, al

    ; Wait a bit
    mov ecx, 10000
.wait:
    in al, dx
    dec ecx
    jnz .wait

    ; Read status
    in al, dx
    cmp al, 0xFF
    je .done

    ; Save disk presence flag
    mov byte [disk_present], 1

.done:
    popa
    ret

; ================
; disk_read_sector
; eax = LBA (sector number)
; edi = buffer (512 bytes)
; ================
disk_read_sector:
    pusha

    mov [disk_lba], eax
    mov [disk_buf], edi

    ; Wait for BSY=0
    mov dx, 0x1F7
.wait1:
    in al, dx
    test al, 0x80
    jnz .wait1

    ; Select master drive, LBA mode
    mov dx, 0x1F6
    mov al, 0xE0
    out dx, al

    ; Features = 0
    mov dx, 0x1F1
    xor al, al
    out dx, al

    ; Sector count = 1
    mov dx, 0x1F2
    mov al, 1
    out dx, al

    ; LBA bits 0-7
    mov eax, [disk_lba]
    mov dx, 0x1F3
    out dx, al

    ; LBA bits 8-15
    shr eax, 8
    mov dx, 0x1F4
    out dx, al

    ; LBA bits 16-23
    shr eax, 8
    mov dx, 0x1F5
    out dx, al

    ; LBA bits 24-27 + drive bits
    shr eax, 8
    and al, 0x0F
    or al, 0xE0
    mov dx, 0x1F6
    out dx, al

    ; Send READ command
    mov dx, 0x1F7
    mov al, 0x20
    out dx, al

    ; Wait for DRQ=1 and BSY=0
    mov ecx, 1000000
.wait2:
    in al, dx
    test al, 0x80
    jnz .wait2_cont
    test al, 0x08
    jnz .wait2_ok
.wait2_cont:
    dec ecx
    jnz .wait2
    jmp .read_done

.wait2_ok:
    ; Read 256 words (512 bytes)
    mov edi, [disk_buf]
    mov ecx, 256
    mov dx, 0x1F0
.read_loop:
    in ax, dx
    mov [edi], ax
    add edi, 2
    dec ecx
    jnz .read_loop

.read_done:
    popa
    ret

; ================
; disk_write_sector
; eax = LBA
; esi = buffer (512 bytes)
; ================
disk_write_sector:
    pusha

    mov [disk_lba], eax
    mov [disk_buf], esi

    ; Wait for BSY=0
    mov dx, 0x1F7
.wait_w1:
    in al, dx
    test al, 0x80
    jnz .wait_w1

    ; Select master, LBA
    mov dx, 0x1F6
    mov al, 0xE0
    out dx, al

    ; Features = 0
    mov dx, 0x1F1
    xor al, al
    out dx, al

    ; Sector count = 1
    mov dx, 0x1F2
    mov al, 1
    out dx, al

    ; LBA 0-7
    mov eax, [disk_lba]
    mov dx, 0x1F3
    out dx, al

    ; LBA 8-15
    shr eax, 8
    mov dx, 0x1F4
    out dx, al

    ; LBA 16-23
    shr eax, 8
    mov dx, 0x1F5
    out dx, al

    ; LBA 24-27
    shr eax, 8
    and al, 0x0F
    or al, 0xE0
    mov dx, 0x1F6
    out dx, al

    ; WRITE command
    mov dx, 0x1F7
    mov al, 0x30
    out dx, al

    ; Wait for DRQ=1
    mov ecx, 1000000
.wait_w2:
    in al, dx
    test al, 0x80
    jnz .wait_w2_cont
    test al, 0x08
    jnz .wait_w2_ok
.wait_w2_cont:
    dec ecx
    jnz .wait_w2
    jmp .write_done

.wait_w2_ok:
    ; Write 256 words
    mov esi, [disk_buf]
    mov ecx, 256
    mov dx, 0x1F0
.write_loop:
    mov ax, [esi]
    out dx, ax
    add esi, 2
    dec ecx
    jnz .write_loop

.write_done:
    popa
    ret


section .data
disk_lba: dd 0
disk_buf: dd 0

section .bss
test_buffer: resb 512
disk_present: resb 1
