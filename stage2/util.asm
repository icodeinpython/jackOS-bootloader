[BITS 64]

; -----------------------------------------------------------------------------
; strlen -- Return length of a string
;  IN:	RSI = string location
; OUT:	RCX = length (not including the NULL terminator)
;	All other registers preserved
strlen:
	push rdi
	push rax

	xor ecx, ecx
	xor eax, eax
	mov rdi, rsi
	not rcx
	cld
	repne scasb	; compare byte at RDI to value in AL
	not rcx
	dec rcx

	pop rax
	pop rdi
	ret

; strcpy -- Copy the contents of one string into another
;  IN:	RSI = source
;	RDI = destination
; OUT:	All registers preserved
; Note:	It is up to the programmer to ensure that there is sufficient space in the destination
strcpy:
    push rsi
    push rdi
    push rax
os_string_copy_more:
    lodsb
    stosb
    cmp al, 0
    jne os_string_copy_more

    pop rax
    pop rdi
    pop rsi
    ret

; os_string_uppercase -- Convert zero-terminated string to uppercase
;  IN:	RSI = string location
; OUT:	All registers preserved
os_string_uppercase:
	push rsi

os_string_uppercase_more:
	cmp byte [rsi], 0x00		; Zero-termination of string?
	je os_string_uppercase_done	; If so, quit
	cmp byte [rsi], 97		; In the uppercase A to Z range?
	jl os_string_uppercase_noatoz
	cmp byte [rsi], 122
	jg os_string_uppercase_noatoz
	sub byte [rsi], 0x20		; If so, convert input char to lowercase
	inc rsi
	jmp os_string_uppercase_more

os_string_uppercase_noatoz:
	inc rsi
	jmp os_string_uppercase_more

os_string_uppercase_done:
	pop rsi
	ret

; os_int_to_string -- Convert a binary interger into an string
;  IN:	RAX = binary integer
;	RDI = location to store string
; OUT:	RDI = points to end of string
;	All other registers preserved
; Min return value is 0 and max return value is 18446744073709551615 so your
; string needs to be able to store at least 21 characters (20 for the digits
; and 1 for the string terminator).
; Adapted from http://www.cs.usfca.edu/~cruse/cs210s09/rax2uint.s
os_int_to_string:
	push rdx
	push rcx
	push rbx
	push rax

	mov rbx, 10					; base of the decimal system
	xor ecx, ecx					; number of digits generated
os_int_to_string_next_divide:
	xor edx, edx					; RAX extended to (RDX,RAX)
	div rbx						; divide by the number-base
	push rdx					; save remainder on the stack
	inc rcx						; and count this remainder
	cmp rax, 0					; was the quotient zero?
	jne os_int_to_string_next_divide		; no, do another division

os_int_to_string_next_digit:
	pop rax						; else pop recent remainder
	add al, '0'					; and convert to a numeral
	stosb						; store to memory-buffer
	loop os_int_to_string_next_digit		; again for other remainders
	xor al, al
	stosb						; Store the null terminator at the end of the string

	pop rax
	pop rbx
	pop rcx
	pop rdx
	ret