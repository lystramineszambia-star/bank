; stage1.asm — BIOS boot sector
; Loads stage2 from LBA 1..32 to 0000:8000, and kernel blob from LBA 33.. into 2000:0000
; Build: nasm -f bin stage1.asm -o stage1.bin

BITS 16
ORG 0x7C00

%define STAGE2_SEG     0x0000
%define STAGE2_OFF     0x8000
%define STAGE2_LBA     1
%define STAGE2_SECT    32              ; stage2 <= 16KiB

%define KBUF_SEG       0x2000          ; phys 0x20000
%define KBUF_OFF       0x0000
%define KERNEL_LBA     (STAGE2_LBA + STAGE2_SECT) ; 33
%define KERNEL_SECT    256             ; 128 KiB max ELF size in this demo

start:
    cli
    xor ax,ax
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov sp,0x7C00
    sti

    ; message
    mov si,msg
.p:
    lodsb
    or al,al
    jz .check
    mov ah,0x0E
    mov bh,0
    mov bl,0x07
    int 0x10
    jmp .p

.check:
    ; INT13h extensions?
    mov ah,0x41
    mov bx,0x55AA
    mov dl,0x80
    int 0x13
    jc  .fail
    cmp bx,0xAA55
    jne .fail

    ; --- load stage2 ---
    mov si,dap
    mov byte [si],0x10
    mov byte [si+1],0
    mov word [si+2],STAGE2_SECT
    mov word [si+4],STAGE2_OFF
    mov word [si+6],STAGE2_SEG
    mov word [si+8],  STAGE2_LBA & 0xFFFF
    mov word [si+10], (STAGE2_LBA >> 16) & 0xFFFF
    mov dword [si+12],0

    mov ah,0x42
    mov dl,0x80
    mov si,dap
    int 0x13
    jc  .fail

    ; --- load kernel blob ---
    mov si,dap
    mov word [si+2],KERNEL_SECT
    mov word [si+4],KBUF_OFF
    mov word [si+6],KBUF_SEG
    mov word [si+8],  KERNEL_LBA & 0xFFFF
    mov word [si+10], (KERNEL_LBA >> 16) & 0xFFFF
    mov dword [si+12],0

    mov ah,0x42
    mov dl,0x80
    mov si,dap
    int 0x13
    jc  .fail

    ; jump to stage2
    jmp STAGE2_SEG:STAGE2_OFF

.fail:
    mov si,err
.pe:
    lodsb
    or al,al
    jz  $
    mov ah,0x0E
    mov bh,0
    mov bl,0x0C
    int 0x10
    jmp .pe

msg: db "Stage1: load Stage2 & kernel blob...",0
err: db "Stage1: disk read error.",0
dap: times 16 db 0

times 510-($-$$) db 0
dw 0xAA55
