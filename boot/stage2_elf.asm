; stage2_elf.asm — loaded to 0000:8000 (phys 0x8000) by Stage1
; Parses ELF32 located at KBUF_PHYS, copies PT_LOAD segments to p_paddr, jumps to e_entry.
; Build: nasm -f bin stage2_elf.asm -o stage2.bin
; Keep <= 16 KiB (32 sectors) per stage1 constants.

%define KBUF_PHYS      0x00020000       ; must match stage1 KBUF (0x2000:0)
%define KBUF_SIZE      (256*512)        ; must match stage1 KERNEL_SECT

BITS 16
ORG 0x8000

start16:
    ; clear screen
    mov ax,0x0003
    int 0x10

    ; print status (real mode)
    mov si,msg16
.pr:
    lodsb
    or al,al
    jz .a20
    mov ah,0x0E
    mov bh,0
    mov bl,0x0A
    int 0x10
    jmp .pr

.a20:
    ; enable A20 (port 0x92)
    in  al,0x92
    or  al,00000010b
    out 0x92,al

    ; GDT
    cli
    lgdt [gdt_ptr]

    ; enter protected mode
    mov eax,cr0
    or  eax,1
    mov cr0,eax
    jmp 0x08:pm_entry

; ---------------- 32-bit ----------------
BITS 32
pm_entry:
    mov ax,0x10
    mov ds,ax
    mov es,ax
    mov fs,ax
    mov gs,ax
    mov ss,ax
    mov esp,0x0090000

    ; Parse ELF header at KBUF_PHYS
    mov esi,KBUF_PHYS
    ; check magic 0x7F 'E''L''F'
    cmp dword [esi],0x464C457F
    jne elf_fail
    ; class = 1 (32-bit)
    cmp byte [esi+4],1
    jne elf_fail
    ; machine = 3 (EM_386)
    cmp word [esi+18],3
    jne elf_fail

    ; e_entry, e_phoff, e_phentsize, e_phnum
    mov eax,[esi+24]           ; e_entry
    mov ebx,[esi+28]           ; e_phoff
    movzx ecx,word [esi+42]    ; e_phentsize
    movzx edx,word [esi+44]    ; e_phnum
    mov edi,eax                ; save entry in EDI
    add ebx,esi                ; EBX = phdr base

    ; iterate program headers
    xor eax,eax                ; i = 0
load_loop:
    cmp eax,edx
    jge ph_done
    mov ebp,ebx
    add ebp,eax
    imul ebp,ecx               ; EBX + i*entsz

    ; p_type == 1 (PT_LOAD)?
    cmp dword [ebx + eax*1], 0 ; (we used another calc; use EBX=phbase)
    ; Recompute cleanly:
    mov ebp,ebx
    mov ecx,[esi+28]           ; phoff (restore)
    add ebp,ecx                ; wrong; instead redo indexing:

    ; ---- simpler approach: recompute PH pointer properly ----
    mov ebp,ebx                ; phdr base = EBX
    mov ecx, [esi+28]          ; (not needed)
    ; PH = phdr_base + i*e_phentsize
    mov ecx, [esi+28]          ; (dead) keep EBX as base, use ECX as tmp
    mov ebp, ebx
    mov ecx, eax
    mov dx,  [esi+42]          ; e_phentsize (16-bit)
    movzx edx, dx
    imul ecx, edx
    add ebp, ecx               ; EBP = phdr_i

    ; p_type
    cmp dword [ebp+0], 1
    jne next_ph

    ; read fields
    mov esi, [ebp+4]           ; p_offset
    mov edi, [ebp+12]          ; p_paddr (prefer p_paddr)
    test edi,edi
    jnz have_paddr
    mov edi, [ebp+8]           ; else p_vaddr
have_paddr:
    mov ecx, [ebp+16]          ; p_filesz
    mov edx, [ebp+20]          ; p_memsz
    ; src = KBUF_PHYS + p_offset
    add esi, KBUF_PHYS

    ; copy filesz bytes -> paddr
    push ecx
    mov esi, esi
    mov edi, edi
    rep movsb                  ; copy ECX bytes
    pop ecx

    ; zero the tail if memsz > filesz
    cmp edx, ecx
    jbe next_ph
    sub edx, ecx
    xor eax, eax
    mov ecx, edx
.zero_bss:
    mov [edi], al
    inc edi
    loop .zero_bss

next_ph:
    inc eax
    jmp load_loop

ph_done:
    ; jump to kernel entry
    jmp dword 0x08:EDI         ; CS already flat; kernel must expect flat pmode

elf_fail:
    ; print a tiny error (write directly to VGA)
    mov edi,0xB8000
    mov eax,0x4F214F20         ; " !O"ish placeholder
    mov [edi],eax
.hang: hlt
      jmp .hang

; ---------------- Data & GDT ----------------
BITS 16
msg16: db "Stage2: A20+GDT -> 32-bit; loading ELF32 kernel...",0

align 8
gdt:
    dq 0x0000000000000000       ; null
    dq 0x00CF9A000000FFFF       ; 0x08 code
    dq 0x00CF92000000FFFF       ; 0x10 data
gdt_ptr:
    dw gdt_end - gdt - 1
    dd gdt
gdt_end: