SYS_WRITE	equ 4
SYS_EXIT	equ 1

			global _start

		section .text
_start:
			mov eax, SYS_WRITE
			; unsigned int fd 	const char *buf 	size_t count
			mov ebx, 1
			mov ecx, message
			mov edx, (message.end - message)
			int 0x80

			mov eax, SYS_EXIT
			mov ebx, 0
			int 0x80

		section .data

message: 	db "Hello, World!", 10
.end:
