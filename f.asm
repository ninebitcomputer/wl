%include "macros.asm"

global _start

SYS_WRITE	equ 4 	; unsigned int fd 	const char *buf 	size_t count
SYS_READ	equ 3	; unsigned int fd   char* buf 			size_t count
SYS_EXIT	equ 1

BUF_SIZE	equ 128
LB_SIZE		equ 64

CELL_COUNT	equ 512

struc file
	.start:	resd 1
	.end:	resd 1
	.desc:	resd 1
	.buf:	resb BUF_SIZE
endstruc

%macro ?range 4							;_range val low behavior
	push %3
	push %2
	push %1
	call range
	add esp, 12
	test eax, eax
	%4
%endmacro

%macro ?number 2
	?range %1, '0', '9', %2
%endmacro

%macro ?lowercase 2
	_range %1, 'a', 'z', %2
%endmacro

%macro _peak 2							;_peak stream error
	?call1 file_peakc, %1, %2
%endmacro

%macro _peak 3
	?call1 file_peakc, %1, %2, %3		;_peak stream error recover
%endmacro

%macro _get 2
	?call1 file_getc, %1, %2
%endmacro

%macro _print 1
	@call1 print, %1
%endmacro

; INTERPRETER/main
; =============================================================================

		section .text
_start:
			push 0
			push stdin
			call file_init
			add esp, 8

			push 1
			push stdout
			call file_init
			add esp, 8

			call main

			mov eax, SYS_EXIT
			mov ebx, 0
			int 0x80

main:
			_prologue

.loop:
			_print s_prompt
			push LB_SIZE - 1
			push line_buf
			push stdin
			call file_read_line
			add esp, 12

			cmp eax, 0
			jge .process

			_print s_error
			jmp .ret
.process:
			mov [line_buf + eax], 0
			_print line_buf
			jmp .loop

.ret:
			_epilogue


; UTILITIES
; =============================================================================
		section .text
; Functions:
; expect_number()
; range(value, lower, upper)

; IN: None
; OUT: eax = parsed number or negative on fail
expect_number:								;expect_number
			_prologue
			push esi
			push edi
			mov esi, 0						;count
			mov edi, 0						;total

.loop:
			_peak stdin, .bad
			?number eax, jz .save

			_get stdin, .bad
			sub eax, '0'

			inc esi
			imul edi, 10
			add edi, eax

			jmp .loop


.save:
			mov eax, edi
			test esi, esi
			; if no chars were parsed this isn't a number
			jnz .ret
.bad:
			mov eax, -1

.ret:
			lea esp, _SLOT(2)
			pop edi
			pop esi
			_epilogue

; IN: val, low, high
; OUT: bool
range:										;range(val, low, high)
			_prologue
			mov eax, 1
			mov edx, _ARG(0)

			cmp dl, _ARG(1)
			jl .fail

			cmp dl, _ARG(2)
			jg .fail

			jmp .ret
.fail:
			mov eax, 0
.ret:
			_epilogue

; IN: char 
; OUT: eax bool
is_number:									;is_number(char)
			_prologue
			mov eax, 1
			mov edx, _ARG(0)

			cmp dl, '0'
			jl .fail
			cmp dl, '9'
			jg .fail
			jmp .ret
.fail:
			mov eax, 0
.ret:
			_epilogue

; IN: null terminated string
; OUT: none
; prints a null terminated string
print:										;print()
			_prologue

			mov eax, _ARG(0)
			mov edx, 0
.loop:
			mov cl, [eax + edx]
			cmp cl, 0
			je .write

			add edx, 1
			jmp .loop

.write:
			push edx
			push eax
			push stdout
			call file_write
			
			_epilogue

; FILE IO
; =============================================================================
; Functions:
; file_init(file*, desc)
; file_buffer_reset(file*)
; file_buffer_read(file*)
; file_buffer_flush(file*)
; file_peakc(file*)
; file_getc(file*)
; file_read_line(file*)

		section .text


; IN: file*, descriptor
; OUT: none
; Resets buffer and writes file descriptor
file_init:									;file_init(file*, descriptor)
			_prologue
			@call1 file_buffer_reset, _ARG(0), eax
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
; Reads in as much as possible from a stream
; deletes previous data
file_buffer_read:							;file_buffer_read(file*)
			_prologue
			push ebx

			@call1 file_buffer_reset, _ARG(0), eax

			mov edx, BUF_SIZE
			lea ecx, [eax + file.buf]
			mov ebx, [eax + file.desc]
			mov eax, SYS_READ
			int 0x80

			cmp eax, 0						; bytes read or negative
			jl .ret
.save:
			mov ebx, _ARG(0)
			mov [ebx + file.end], eax
.ret:
			lea esp, _SLOT(1)
			pop ebx
			_epilogue

; IN: file*
; OUT: bytes written or error (<0)
; write out the contents of a file's buffer
file_buffer_flush:							;file_buffer_flush(file*)
			_prologue
			push ebx

			mov eax, _ARG(0)
			mov ebx, [eax + file.desc]		;fd

			mov ecx, [eax + file.start]
			mov edx, [eax + file.end]
			sub edx, ecx					;count

			lea ecx, [eax + file.buf]
			add ecx, [eax + file.start]		;buf

			mov eax, SYS_WRITE
			int 0x80

			push eax
			@call1 file_buffer_reset, _ARG(0)
			pop eax
.ret:
			lea esp, _SLOT(1)
			pop ebx
			_epilogue

; IN: file*, char
; OUT: eax, 0 or error
file_putc:									;file_putc(file*, char)
			_prologue
			mov eax, _ARG(0)

			mov ecx, [eax + file.end]
			cmp ecx, BUF_SIZE
			jl .save						;if file.end is at end, flush

			?call1 file_buffer_flush, eax, .ret
.save:
			mov eax, _ARG(0)
			lea ecx, [eax + file.buf]
			add ecx, [eax + file.end]
			mov dl, _ARG(1)
			mov [ecx], dl

			inc [eax + file.end]

			cmp [eax + file.end], BUF_SIZE
			jge .flush

			cmp dl, 10
			je .flush

			jmp .good
.flush:
			?call1 file_buffer_flush, eax, .ret
.good:
			mov eax, 0
.ret:
			_epilogue

; IN: file*, buf, length
; OUT: 0 on success, negative on error
; //TODO this could just be a syscall
file_write:									;file_write(file*, buf, length)
			_prologue
			push edi
			push esi

			mov edi, _ARG(1)				;ptr
			mov esi, 0						;idx
.loop:
			cmp esi, _ARG(2)
			jge .good

			movzx eax, byte [edi + esi]
			push eax
			push _ARG(0)
			call file_putc

			cmp eax, 0
			jl .ret

			inc esi
			jmp .loop

.good:
			mov eax, 0
.ret:
			lea esp, _SLOT(2)
			pop esi
			pop edi
			_epilogue

; IN: file*
; OUT: eax
file_peakc:									;file_peakc(file*)
			_prologue

			mov eax, _ARG(0)
			mov ecx, [eax + file.start]
			cmp ecx, [eax + file.end]

			jl .readc

			?call1 file_buffer_read, _ARG(0), .ret
.readc:
			mov eax, _ARG(0)
			mov ecx, [eax + file.start]
			lea edx, [eax + file.buf]
			movzx eax, byte [edx + ecx] 
.ret:
			_epilogue

; IN: file*
; OUT: eax
file_getc:									;file_getc(file*)
			_prologue

			_peak _ARG(0), .ret, ecx
			inc dword [ecx + file.start]
			
.ret:
			_epilogue

; IN: file*, buffer, capacity
; OUT: bytes read or error
file_read_line:								;file_read_line(file*, buffer, cap)
			_prologue
			push edi						; count

			mov edi, 0
.loop:
			cmp edi, _ARG(2)				; count, capacity
			jge .ret

			?call1 file_getc, _ARG(0), .ret

			mov ecx, _ARG(1)				; save char
			mov [ecx + edi], al
			inc edi

			cmp al, 10						; ret on newline
			je .ret_edi
			jmp .loop
.ret_edi:
			mov eax, edi
.ret:
			lea esp, _SLOT(1)
			pop edi
			_epilogue

; DATA
; =============================================================================

; BSS
		section .bss

stdin: 		align 4
			resb file_size

stdout:		align 4
			resb file_size

cells:		align 4
			resb 4*CELL_COUNT

line_buf: 	resb LB_SIZE

; DATA
		section .data

s_prompt:		db "> ", 0
s_error: 		db "an error occured", 10, 0
s_rec:			db "received new line", 10, 0
