; kernel32.asm — simple 32-bit "kernel"
; Assembled to ELF32 object, then linked at 0x00100000 via linker.ld

BITS 32
GLOBAL _start

SECTION .text
_start:
    ; write "ELF32 kernel at 1MiB!" to VGA
    mov edi, 0xB8000
    mov esi, msg
.print:
    lodsb
    test al, al
    jz .halt
    mov ah, 0x0F
    mov [edi], ax
    add edi, 2
    jmp .print

.halt:
    cli
.loop: hlt
      jmp .loop

SECTION .rodata
msg: db "ELF32 kernel at 1MiB!",0
