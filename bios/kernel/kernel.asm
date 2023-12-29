[BITS 64]

%define VIDEO_RAM 0xB8000		; Start of 80x25 video memory

section .text

init:
    jmp start

x_pos db 0x00
y_pos db 0x00
string_color db 0x0A		; Green color
print_string:
	push rdi
	push rax
	push rbx

	mov ah, byte [string_color]
.loop:
	lodsb			; Loads a byte from [RSI] into AL
	cmp al, 0x00
	je exit

	; Write character
	call print_character
	jmp .loop

exit:
	; Update cursor
	mov byte [x_pos], 0x00	; Set to start of line
	add byte [y_pos], 0x01	; Move down one line

	mov bl, 80
	cmp bl, byte [y_pos]		; If on end of screen, reset
	jne .exit

	mov byte [y_pos], 0x00
.exit:
	pop rbx
	pop rax
	pop rdi
	ret

print_character:
	push rcx
	push rbx

	mov cx, ax		; Save character and attribute

	; Calculate memory to write to
	movzx ax, byte [y_pos]
	mov dx, 160		; 80 * 2
	mul dx
	movzx bx, byte [x_pos]
	shl bx, 1		; Multiply by 2 to skip attrib

	mov edi, 0x00
	add di, ax		; Add rows
	add di, bx		; add columns
	add edi, VIDEO_RAM


	mov ax, cx		; Restore character and attribute
	stosw			; Write word to DI
	add byte [x_pos], 0x01	; Move cursor to left

	pop rbx
	pop rcx
	ret

; clear_screen
;
; Blanks out a screen
clear_screen:
	push rax
	push rcx
	push rdi

	mov rdi, VIDEO_RAM
	mov rcx, 80*25
	mov rax, 0x0A20		; 4 "green" Space characters
	rep stosw

	pop rdi
	pop rcx
	pop rax
	ret

start:
    mov rsi, msg_welcome
    call print_string
.halt:
    hlt
    jmp .halt


[section .rodata]
msg_welcome db "Hello elf world!"