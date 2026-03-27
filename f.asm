%include "common.asm"

FUNCTION1 Print, print				;Print(buf)

global _start


%macro _pop_cell 1						;_pop_cell underflow
	?call pop_cell, %1
%endmacro

%macro _push_cell 2						;_push_cell val, overflow
	?call1 push_cell, %1, %2
%endmacro

%macro defword 3						;defword name, fp, next
	dd %3 								; next
	dd %2 								; fp

	%strlen __len %1
	dd __len 							; nl
	db %1 								; name + padding
    times (32 - __len) db 0
%endmacro

; TODO
global stdin
global stdout

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
			push esi
			push edi
			push ebx
			sub esp, M_SYM_NAME		; _SLOT(4) = token
			mov [p_cell], 0
.loop:
			?call1 consume_whitespace, stdin, .error
			lea eax, _SLOT(4)
			ExpectToken(stdin, eax, .error)

			lea ecx, _SLOT(4)
			push eax				;length
			push ecx				;buffer
			call try_parse_number
			pop edi					;edi has buffer
			pop esi					;esi has token length

			cmp eax, 0
			jge .number				;edx has number

.operator:
			?call2 find_word, edi, esi, .bad_token

			mov eax, [edx + fword.fp]
			call eax
			cmp eax, 0
			jl .runtime_error

			jmp .reloop

.number:							;edx has number
			_push_cell edx, .stack_overflow
.reloop:
			jmp .loop

.runtime_error:
			cmp eax, FE_OVER
			je .stack_overflow
			cmp eax, FE_UNDER
			je .stack_underflow
			jmp .error

.bad_token:
			Print(s_invalidt)

			?call1 consume_non_whitespace, stdin, .error
			?call3 file_write, stdout, edi, esi, .error
			Putc(stdout, 10, .error)

			jmp .reloop

.stack_overflow:
			Print(s_overflow)
			jmp .error

.stack_underflow:
			Print(s_underflow)
			?call1 consume_non_whitespace, stdin, .error
			jmp .reloop

.error:
			Print(s_error)

.ret:
			lea esp, _SLOT(3)
			pop ebx
			pop edi
			pop esi
			_epilogue


; FORTH
; =============================================================================
		section .text
; Functions:
; push_cell(val)
; pop_cell()
; find_word(buf, length)

; Globals:
; p_cell
; cells
; dictionary

; IN: value to push
; OUT: eax = FE_OVER on overflow
push_cell:									;push_cell(val)
			_prologue
			mov edx, [p_cell]
			cmp edx, CELL_COUNT
			jge .bad

			mov eax, _ARG(0)
			mov [cells + edx * 4], eax
			inc dword [p_cell]
			mov eax, 0
			jmp .ret

.bad:
			mov eax, FE_OVER
.ret:
			_epilogue

; IN: none
; OUT: eax = FE_UNDER on underflow, edx = value on success
pop_cell:									;pop_cell()
			_prologue
			dec dword [p_cell]
			mov ecx, [p_cell]
			cmp ecx, 0
			jl .underflow

			mov edx, [cells + ecx*4]
			mov eax, 0
			jmp .ret
.underflow:
			mov eax, FE_UNDER
			mov dword [p_cell], 0
.ret:
			_epilogue

; IN: none
; OUT: eax = negative on error
print_stack:								;print_stack()
			_prologue
			push ebx
			mov ebx, 0
.loop:
			cmp ebx, [p_cell]
			jge .finish

			lea eax, [cells + 4 * ebx]
			Wnum(stdout, [eax], .error)
			Putc(stdout, ' ', .error)

			inc ebx
			jmp .loop

.finish:
			Putc(stdout, 10, .error)
			mov eax, 0
.error:
.ret:
			lea esp, _SLOT(1)
			pop ebx
			_epilogue

; IN: buf, length
; OUT: eax = negative or 0, edx = fword* on success
; searches dictionary for word with given name
find_word:									;find_word(buf, length)
			_prologue
			push esi

			mov esi, dictionary.root
.loop:
			mov eax, [esi + fword.nl]
			cmp eax, _ARG(1)
			jnz .cont

			push _ARG(1)					;same length
			lea eax, [esi + fword.name]
			push eax
			push _ARG(0)
			call strncmp
			add esp, 12

			test eax, eax
			jnz .cont

			mov eax, 0						;same name = found
			mov edx, esi
			jmp .ret
.cont:	
			mov esi, [esi + fword.next]
			test esi, esi
			jz .error
			jmp .loop

.error:
			mov eax, -1
.ret:

			lea esp, _SLOT(1)
			pop esi
			_epilogue

; helpers for generating binary intrinsics
; after sbintrins, edx has stack left, ecx has stack right
; runtime errors should jump to .ret
											
%macro sbintrins 0							; sbintrins
			_prologue
			_pop_cell .ret
			push edx
			_pop_cell .ret
			pop ecx
%endmacro

%macro ebintrins 0							; ebintrins
			mov eax, 0
.ret:
			_epilogue
%endmacro


intrinsic_add:								;intrinsic_add (n1 n2 -- n1 + n2)
			sbintrins

			add edx, ecx
			_push_cell edx, .ret

			ebintrins

intrinsic_sub:								;intrinsic_sub (n1 n2 -- n1 - n2)
			sbintrins

			sub edx, ecx
			_push_cell edx, .ret

			ebintrins

intrinsic_mul:
			sbintrins

			mul edx, ecx
			_push_cell edx, .ret

			ebintrins

intrinsic_div:
			sbintrins

			mov eax, edx
			mov edx, 0
			idiv ecx						; eax := q, edx := r
			_push_cell eax, .ret

			ebintrins

intrinsic_beg_def:
			_prologue
			mov eax, FM_BEGDEF
			_epilogue

intrinsic_end_def:
			_prologue
			mov eax, FM_ENDDEF
			_epilogue


intrinsic_dot:
			_prologue

			_pop_cell .ret
			Wnum(stdout, edx, .io_err)
			Putc(stdout, 10, .io_err)
			jmp .ret
.io_err:
			mov eax, FE_IO
.ret:
			_epilogue

intrinsic_print_stack:
			_prologue
			?call print_stack, .io_err
			mov eax, 0
			jmp .ret
.io_err:
			mov eax, FE_IO
.ret:
			_epilogue

; DATA
; =============================================================================

; BSS
		section .bss

stdin: 		align 4
			resb file_size

stdout:		align 4
			resb file_size

p_cell:		align 4
			resd 1

cells:		align 4
			resb 4*CELL_COUNT

; DATA
		section .data

s_prompt:		db "> ", 0
s_error: 		db "an error occured", 10, 0
s_rec:			db "received new line", 10, 0
s_overflow		db "stack overflow", 10, 0
s_underflow		db "stack underflow", 10, 0
s_invalidt		db "invalid token: ", 0
s_operator		db "operator", 10, 0
s_number 		db "number", 10, 0

dictionary: 	align 32
.root:
.sub:			defword "-", intrinsic_sub, .add
.add:			defword "+", intrinsic_add, .mul
.mul:			defword "*", intrinsic_mul, .div
.div:			defword "/", intrinsic_div, .dot
.dot:			defword ".", intrinsic_dot, .bword
.bword:			defword ":", intrinsic_beg_def, .eword
.eword:			defword ";", intrinsic_end_def, .dots
.dots:			defword ".s", intrinsic_print_stack, 0


