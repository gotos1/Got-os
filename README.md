# GOT[os]

> A minimal x86 operating system written from scratch in pure assembly.

No Linux. No Unix. No GNU. Just code and curiosity.
Shell, RAM filesystem, and text editor included. Built on a phone. 🐐
---
## Credits

### GOT[os]
Copyright (c) 2026 Abdulbasit Boukhald (عبدالباسط بوخالد).
Licensed under the **MIT License** — see [LICENSE](LICENSE).

### Limine Bootloader
Copyright (c) Limine Bootloader Team.
Licensed under the **BSD 2-Clause License**.
https://github.com/limine-bootloader/limine

---

## About

GOT[os] is a hobby operating system written entirely from zero in x86
32-bit assembly. Every line of code is original.

Named after the goat (GOT = Goat), a personal symbol of childhood.

---
## Features

- **Boot:** Multiboot-compliant, boots via Limine
- **Shell:** 22+ built-in commands
- **Filesystem:** RAM-based (create, read, write, delete)
- **Disk Storage:** Persistent ATA PIO driver with custom filesystem
- **Editor:** Built-in text editor (`edit`)
- **Hardware:** VGA, Serial I/O, PIC, IDT
- **Reboot:** ACPI + Triple Fault
- **Terminal:** Full I/O via COM1
- **Persistence:** Files survive reboot via `dsave` / `dload`

---
## Commands

### RAM Filesystem
| Command | Description |
|---|---|
| `ls` | List files in RAM |
| `touch <name>` | Create empty file |
| `write <f> <t>` | Write text to file |
| `cat <name>` | Show file content |
| `rm <name>` | Delete file |
| `cp <src> <dst>` | Copy file |
| `mv <old> <new>` | Rename file |
| `edit <name>` | Edit file interactively |

### Disk Storage
| Command | Description |
|---|---|
| `dformat` | Format disk |
| `dsave <file>` | Save file to disk |
| `dload <file>` | Load file from disk |
| `dls` | List files on disk |
| `drm <file>` | Delete file from disk (with confirmation) |
| `dread <sector>` | Read sector (hex dump) |

### System
| Command | Description |
|---|---|
| `help` | Show all commands |
| `version` | Show system version |
| `clear` | Clear screen |
| `echo <text>` | Print text |
| `color 0-7` | Change color |
| `sysinfo` | CPU information |
| `reboot` | Restart system |
| `off system` | Shutdown |

---
## System Requirements

- **CPU:** x86 (i386, 32-bit)
- **RAM:** 32 MB
- **Display:** VGA text mode
- **Input:** Serial terminal (COM1, 38400 baud)
- **Storage:** ATA-compatible disk (optional, for persistent files)
- **Bootloader:** Multiboot 1 (Limine)
---
## Roadmap

- [x] v0.1 — Bootable kernel
- [x] v0.2 — Shell + Serial keyboard
- [x] v0.3 — RAM filesystem + editor
- [x] v0.4 — Persistent disk storage (ATA PIO)
- [ ] v0.5 — Directories + more text tools
- [ ] v1.0 — Stable release

---
## Build

```bash
# Clone
git clone <repo-url>
cd got-os

# Install Limine
git clone https://github.com/limine-bootloader/limine.git --branch=v7.x --depth=1
cd limine && ./bootstrap && ./configure --enable-bios --enable-bios-cd && make && cd ..

# Build kernel
make

# Build ISO
mkdir -p iso/boot/limine
cp kernel.elf iso/boot/
cp limine/bin/limine-bios-cd.bin iso/boot/limine/
cp limine/bin/limine-bios.sys iso/boot/limine/
cp limine/bin/limine iso/boot/limine/

cat > iso/boot/limine/limine.cfg << EOF
TIMEOUT=0
:GOT[os]
    PROTOCOL=multiboot1
    KERNEL_PATH=boot:///boot/kernel.elf
EOF

xorriso -as mkisofs -b boot/limine/limine-bios-cd.bin \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    --protective-msdos-label iso -o gotos.iso

# Run
qemu-system-i386 -cdrom gotos.iso -m 128 -serial mon:stdio -nographic
