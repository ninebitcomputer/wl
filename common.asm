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

%macro _peak 2							;_peak stream error
	?call1 file_peakc, %1, %2
%endmacro

%macro _peak 3
	?call1 file_peakc, %1, %2, %3		;_peak stream error recover
%endmacro

%macro _get 2							;_get stream error
	?call1 file_getc, %1, %2
%endmacro

%macro _print 1
	@call1 print, %1
%endmacro

%macro _putc 3							;_putc stream, char, error
	?call2 file_putc, %1, %2, %3
%endmacro

%macro _wnum 3							;_wnum stream, num, error
	?call2 file_write_num, %1, %2, %3
%endmacro

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
