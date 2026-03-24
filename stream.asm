%include "common.asm"
; FILE IO
; =============================================================================
; Functions:
;file_init(file*, desc)
;file_buffer_reset(file*)
;file_buffer_read(file*)
;file_buffer_flush(file*)
;file_peakc(file*)
;file_getc(file*)
;file_putc(file*, char)
;file_read_line(file*)
;file_write(file*, buf, length)
;file_write_num(file*, number)

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

			inc dword [eax + file.end]

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

			_peak _ARG(0), .ret
			mov ecx, _ARG(0)
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

; IN: file*, number
; OUT: eax = error on negative
file_write_num:								; file_write_num (file*, number)
			_prologue
			push esi						; count
			push edi						; remaining

			mov esi, 0
			mov edi, _ARG(1)

			test edi, edi
			jz .zero

			sub esp, 32						; alloc space
.loop:
			cmp edi, 0
			je .print

			cmp esi, 32
			jge .error

			inc esi

			mov edx, 0
			mov eax, edi
			mov ecx, 10
			div ecx							; eax := q, edx ;= r

			mov edi, eax
			add edx, '0'

			lea eax, [esp + 32]				; save from end
			sub eax, esi
			mov [eax], dl
			jmp .loop
			
.zero:
			_putc _ARG(0), '0', .error

			mov eax, 0
			jmp .ret
			; x

.print:
			lea eax, [esp + 32]				; load from end
			sub eax, esi

			push esi						; count
			push eax						; buffer
			push _ARG(0)					; file
			call file_write
			cmp eax, 0
			jl .error

			jmp .ret
			; x
.error:
			mov eax, -1
.ret:
			lea esp, _SLOT(2)
			pop edi
			pop esi
			_epilogue
