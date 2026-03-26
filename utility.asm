%include "common.asm"

;TODO
extern stdout
extern stdin

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

			Peak(stdin, .bad)
			?printable eax, jz .finish
			Get(stdin, .bad)

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
			Peak(_ARG(0), .ret)
			@call1 is_whitespace, eax
			test eax, eax
			jz .good

			Get(_ARG(0), .ret)
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
			Peak(_ARG(0), .ret)
			@call1 is_whitespace, eax
			test eax, eax
			jnz .good

			Get(_ARG(0), .ret)
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

