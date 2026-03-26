%include "macros.asm"

; SYSCALLS
; =============================================================================

SYS_WRITE	equ 4 	; unsigned int fd 	const char *buf 	size_t count
SYS_READ	equ 3	; unsigned int fd   char* buf 			size_t count
SYS_EXIT	equ 1

; FILE IO
; =============================================================================

extern file_init					;file_init(file*, desc)
extern file_buffer_reset			;file_buffer_reset(file*)
extern file_buffer_read				;file_buffer_read(file*)
extern file_buffer_flush			;file_buffer_flush(file*)
extern file_peakc					;file_peakc(file*)
extern file_getc					;file_getc(file*)
extern file_putc					;file_putc(file*, char)
extern file_read_line				;file_read_line(file*)
extern file_write 					;file_write(file*, buf, length)
extern file_write_num 				;file_write_num(file*, number)

BUF_SIZE	equ 128
struc file
	.start:	resd 1
	.end:	resd 1
	.desc:	resd 1
	.buf:	resb BUF_SIZE
endstruc


FALLIBLE1 Peak, file_peakc			;Peak(stream, .err)
FALLIBLE1 Get, file_getc			;Get(stream, .err)

FALLIBLE2 Putc, file_putc			;Putc(stream, char, .err)
FALLIBLE2 Wnum, file_write_num		;Wnum(stream, number, .err)

; WL FORTH
; =============================================================================

M_SYM_NAME	equ 32
M_SYM_SLOTS equ M_SYM_NAME / 4
CELL_COUNT	equ 1024

; interpreter messages
FM_ENDDEF	equ 2	; end word definition
FM_BEGDEF   equ 1	; begin word definition

; runtime errors
FE_OVER 	equ -1	; stack overflow
FE_UNDER	equ -2	; stack underflow
FE_IO		equ -3	; IO error

struc fword
	.next:	resd 1
	.fp:	resd 1
	.nl:	resd 1
	.name:	resb 32
endstruc

; UTILITIES
; =============================================================================
extern try_parse_number 			;try_parse_number(buffer, length)
extern expect_token					;expect_token(buf)
extern range						;range(value, lower, upper)
extern is_whitespace			 	;is_whitespace(val)
extern consume_whitespace			;consume_whitespace(stream)
extern consume_non_whitespace		;consume_non_whitespace(stream)
extern print 						;print(s)
extern strncmp						;strncmp(buf_a, buf_b, length)

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
