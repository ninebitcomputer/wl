global _start

SYS_WRITE	equ 4 	; unsigned int fd 	const char *buf 	size_t count
SYS_READ	equ 3	; unsigned int fd   char* buf 			size_t count
SYS_EXIT	equ 1
BUF_SIZE	equ 4096

struc file
	.start:	resd 1
	.end:	resd 1
	.desc:	resd 1
	.buf:	resb BUF_SIZE
endstruc

%macro _prologue 0
	push ebp
	mov ebp, esp
%endmacro

%macro _epilogue 0
	leave
	ret
%endmacro

%define _arg(n) ebp + 8 + 4*(n)
%define _ARG(n) [_arg(n)]

%define _slot(n) ebp - 4*(n)
%define _SLOT(n) [_slot(n)]

		section .text
_start:
			push message,
			call print
			sub esp, 8

			push 0
			push stdin
			call file_init
			sub esp, 8

			call main

			mov eax, SYS_EXIT
			mov ebx, 0
			int 0x80

main:
			_prologue
			_epilogue

; IN: null terminated string
; OUT: none
; prints a null terminated string
print:
			_prologue
			push ebx

			mov eax, _ARG(0)
			mov edx, 0
.loop:
			mov cl, [eax + edx]
			cmp cl, 0
			je .syscall

			add edx, 1
			jmp .loop
			
.syscall:
			mov eax, SYS_WRITE
			mov ebx, 1
			mov ecx, _ARG(0)
			int 0x80
		
			lea esp, _SLOT(1)
			pop ebx
			_epilogue

; IN: file*, descriptor
; OUT: none
; Resets buffer and writes file descriptor
file_init:
			_prologue
			push _ARG(0)
			call file_buffer_reset

			mov eax, _ARG(0)			;file
			mov ecx, _ARG(1)			;fd

			mov [eax + file.desc], ecx
			_epilogue
; IN:  file*
; OUT: None
; Resets buffer
file_buffer_reset:
			_prologue

			mov eax, _ARG(0)			;file
			mov [eax + file.start], 0
			mov [eax + file.end], 0

			_epilogue

; IN:  file*
; OUT: bytes read or error (<0)
; Reads in as much as possible from a stream, deletes previous data
file_refill_buffer:
			_prologue
			push ebx

			push _ARG(0)
			call file_buffer_reset

			pop eax						;file
			mov edx, BUF_SIZE
			lea ecx, [eax + file.buf]
			mov ebx, [eax + file.desc]
			mov eax, SYS_READ
			int 0x80

			cmp eax, 0					; bytes read or negative
			jl .ret
.save:
			lea edx, [eax + 1]
			mov ebx, _ARG(0)
			mov [ebx + file.end], edx	; end is exclusive
.ret:
			lea esp, _SLOT(1)
			pop ebx
			_epilogue

; IN: file*, buffer, capacity
; OUT: bytes read or error
file_read_line:
			_prologue
			push esi					; file
			push edi					; count

			mov esi, _ARG(0)
			mov edi, 0
.loop:
			cmp edi, _ARG(2)			; count, capacity
			jge .ret

			; check if buffer empty
			mov eax, [esi + file.start]
			mov ecx, [esi + file.end]
			cmp eax, ecx
			jl .load

.refill:
			push _ARG(0)
			call file_refill_buffer
			cmp eax, 0
			jge .load
.bad:
			mov edi, eax
			jmp .ret

.load:
			; grab next char
			lea edx, [esi + file.buf]
			mov ecx, [esi + file.start]
			mov al, [edx + ecx]
			add ecx, 1
			mov [esi + file.start], ecx

			; save char
			mov ecx, _ARG(1)
			mov [ecx + edi], al
			add edi, 1

			; ret on newline
			cmp al, 10
			je .ret

			jmp .loop
.ret:
			mov eax, edi
			lea esp, _SLOT(2)
			pop edi
			pop esi
			_epilogue


		section .bss

stdin: 		align 4
			resb file_size

		section .data

message: 	db "This is the epilogue", 10, 0
.end:
