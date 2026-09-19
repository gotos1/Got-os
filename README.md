# Got-os
A minimal x86 operating system written from scratch in pure assembly. No Linux. No Unix. No GNU. Just code and curiosity. Shell, RAM filesystem, and text editor included. Built on a phone. 🐐
# System Requirements

## Minimum

- **CPU:** x86 (i386, 32-bit) — Intel Pentium or newer
- **RAM:** 32 MB
- **Storage:** 1.44 MB (floppy) or CD-ROM / USB
- **Display:** VGA-compatible (text mode 80×25)
- **Input:** Serial terminal (COM1, 38400 baud, 8N1)
- **Bootloader:** Multiboot 1 compliant (Limine included)

## Recommended

- **CPU:** Intel Core i3 (1st gen) or newer
- **RAM:** 128 MB or more
- **Storage:** Any bootable medium (CD-ROM, USB, HDD)
- **Display:** Any VGA-compatible monitor
- **Input:** Serial terminal or Serial-over-USB

## Tested On

- **QEMU** (i386 emulation) — full support
- **Real hardware** — x86 PCs with BIOS
- **Development environment:** Termux on Android (ARM)

## Notes

- Kernel size: ~15 KB
- No GPU required (text mode only)
- No disk driver yet (RAM filesystem only)
- No network support yet
- Boots in under 1 second on modern hardware
