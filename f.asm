%include "common.asm"

global _start
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
	?range %1, 'a', 'z', %2
%endmacro

%macro ?printable 2
	?range %1, '!', '~', %2
%endmacro

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
			?call1 expect_token, eax, .error

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
			_print s_invalidt

			?call1 consume_non_whitespace, stdin, .error
			?call3 file_write, stdout, edi, esi, .error
			_putc stdout, 10, .error

			jmp .reloop

.stack_overflow:
			_print s_overflow
			jmp .error

.stack_underflow:
			_print s_underflow
			?call1 consume_non_whitespace, stdin, .error
			jmp .reloop

.error:
			_print s_error

.ret:
			lea esp, _SLOT(3)
			pop ebx
			pop edi
			pop esi
			_epilogue


; UTILITIES
; =============================================================================
		section .text
; Functions:
; try_parse_number(buffer, length)
; expect_token(buf)
; range(value, lower, upper)
; is_whitespace(val)
; consume_whitespace(stream)
; print(s)
; strncmp(buf_a, buf_b, length)

; IN: buffer, length
; OUT: eax = negative on not number, edx = parsed number if success
try_parse_number:
			_prologue
			push esi
			push edi
			mov esi, 0						;result
			mov edi, 0 						;count

.loop:
			cmp edi, _ARG(1)
			jge .finish

			mov eax, _ARG(0)
			add eax, edi

			movzx eax, byte [eax]
			push eax
			?number eax, jz .error
			pop eax

			sub eax, '0'
			imul esi, 10
			add esi, eax

			inc edi
			jmp .loop
.finish:
			mov eax, 0
			mov edx, esi
			jmp .ret

.error:
			mov eax, -1

.ret:
			lea esp, _SLOT(2)
			pop edi
			pop esi
			_epilogue

; IN: pointer to buffer of size M_SYM_NAME
; OUT: eax = token length or negative on error
; reads a token from stdin
expect_token:								;expect_token(buf)
			_prologue
			push ebx
			mov ebx, 0

.loop:
			cmp ebx, M_SYM_NAME
			jge .bad

			_peak stdin, .bad
			?printable eax, jz .finish
			_get stdin, .bad

			mov ecx, _ARG(0)
			mov [ecx + ebx], al

			inc ebx
			jmp .loop
.finish:
			mov eax, ebx
			cmp ebx, 0
			jg .ret

.bad:
			mov eax, -1

.ret:
			lea esp, _SLOT(1)
			pop ebx
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


; IN: val
; OUT: bool
is_whitespace:								;is_whitespace(val)
			_prologue
			mov ecx, _ARG(0)
			mov eax, 1

			cmp ecx, ' '
			je .ret
			cmp ecx, 9	 					;'\t'
			je .ret
			cmp ecx, 10 					;'\n'
			je .ret
			cmp ecx, 11						;'\v'
			je .ret
			cmp ecx, 12 					;'\f'
			je .ret
			cmp ecx, 12 					;'\r'
			je .ret

			mov eax, 0
.ret:
			_epilogue

; IN: stream
; OUT: eax = negative on error
consume_whitespace:							;consume_whitespace(stream)
			_prologue
.loop:
			_peak _ARG(0), .ret
			@call1 is_whitespace, eax
			test eax, eax
			jz .good

			_get _ARG(0), .ret
			jmp .loop
.good:
			mov eax, 0
.ret:
			_epilogue

; IN: stream
; OUT: eax = negative on error
consume_non_whitespace:						;consume_non_whitespace(stream)
			_prologue
.loop:
			_peak _ARG(0), .ret
			@call1 is_whitespace, eax
			test eax, eax
			jnz .good

			_get _ARG(0), .ret
			jmp .loop
.good:
			mov eax, 0
.ret:
			_epilogue


; IN: cstring
; OUT: eax = wrote or negative on error
; prints a null terminated string
print:										;print(cstring)
			_prologue

			push _ARG(0)
			push stdout
			call fprint
			
			_epilogue

; IN: file*, cstring
; OUT: eax = wrote or negative on error
fprint:										;fprint(file*, cstring)
			_prologue
			mov eax, _ARG(1)
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
			push _ARG(0)
			call file_write
			_epilogue

; IN: buf_a, buf_b, length
; OUT: eax = -1 l, 0 eq, 1 g
; compare two strings of given length
strncmp:									;strncmp(buf_a, buf_b, length)
			_prologue
			push esi
			push edi
			push ebx

			mov esi, _ARG(0)
			mov edi, _ARG(1)
			mov ebx, 0

.loop:
			cmp ebx, _ARG(2)
			jge .eq

			mov cl, [esi]
			mov dl, [edi]

			cmp cl, dl
			jl .lt
			jg .gt

			inc esi
			inc edi
			inc ebx
			jmp .loop
			
.gt:
			mov eax, 1
			jmp .ret
.lt:
			mov eax, -1
			jmp .ret
.eq:
			mov eax, 0
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
			_wnum stdout, [eax], .error
			_putc stdout, ' ', .error

			inc ebx
			jmp .loop

.finish:
			_putc stdout, 10, .error
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
			_wnum stdout, edx, .io_err
			_putc stdout, 10, .io_err
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


