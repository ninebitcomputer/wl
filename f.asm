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
			mov eax, SYS_WRITE
			mov ebx, 1
			mov ecx, message
			mov edx, (message.end - message)
			int 0x80

			push 0
			push stdin
			call file_init
			sub esp, 8

			mov eax, SYS_EXIT
			mov ebx, 0
			int 0x80

; IN:  file*, descriptor
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
file_buffer_read:
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

			mov ebx, _ARG(0)
			mov [ebx + file.end], eax
.ret

			lea esp, _SLOT(1)
			pop ebx
			_epilogue


		section .bss

stdin: 		align 4
			resb file_size

		section .data

message: 	db "Hello, World!", 10
.end:
