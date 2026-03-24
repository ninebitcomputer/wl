; SYSCALLS
; =============================================================================

SYS_WRITE	equ 4 	; unsigned int fd 	const char *buf 	size_t count
SYS_READ	equ 3	; unsigned int fd   char* buf 			size_t count
SYS_EXIT	equ 1

; FILE IO
; =============================================================================

global file_init					;(file*, desc)
global file_buffer_reset			;(file*)
global file_buffer_read				;(file*)
global file_buffer_flush			;(file*)
global file_peakc					;(file*)
global file_getc					;(file*)
global file_read_line				;(file*)

BUF_SIZE	equ 128
struc file
	.start:	resd 1
	.end:	resd 1
	.desc:	resd 1
	.buf:	resb BUF_SIZE
endstruc

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
