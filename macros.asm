%macro _prologue 0
	push ebp
	mov ebp, esp
%endmacro

%macro _epilogue 0
	leave
	ret
%endmacro

%macro ?call 2							;@call function error
	call %1
	cmp eax, 0
	jl %2
%endmacro


%macro @call1 2							;@call1 function input
	push %2
	call %1
	add esp, 4
%endmacro

%macro @call1 3							;@call1 function input recover
	push %2								;arguments gets popped into recover
	call %1								;do not recover into return register
	pop %3
%endmacro

%macro ?call1 3							;?call1 func, arg1, error
	@call1 %1, %2
	cmp eax, 0
	jl %3
%endmacro

%macro ?call1 4							;?call1 func, arg1, error, recover
	@call1 %1, %2, %4
	cmp eax, 0
	jl %3
%endmacro

%macro ?call2 4							;_call2 func, arg1, arg2, error
	push %3
	push %2
	call %1
	add esp, 8
	cmp eax, 0
	jl %4
%endmacro


%define _arg(n) ebp + 8 + 4*(n)
%define _ARG(n) [_arg(n)]

%define _slot(n) ebp - 4*(n)
%define _SLOT(n) [_slot(n)]
