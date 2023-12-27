;------------------------------------------------------------------------------
;				OS LOADER
; Assumes:
;	- Loaded at 0x0000
;
; Sets SP to 0x7C00
;------------------------------------------------------------------------------

[BITS 16]
[ORG 0x8000]
[map all src/debug/stage2.map]

; CONSTANTS
%define VIDEO_RAM 0xB8000		; Start of 80x25 video memory


; Offset 4 bytes
start:
	mov [drive_number], dl
	; Reset all registers
	cli                             ; Disable all interrupts
	xor eax, eax
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax
	mov sp, 0x7C00	; Reset SP
	cld		; Clear direction flag

	mov si, msg_entry
	call print_string_16

	; Disable cursor blinking
	mov ah, 0x01
	mov cx, 0x2607
	int 0x10

	; Check CPUID availability
	; If CPUID instruction is supported, the 'ID' bit (0x200000) in eflags
	; will be modifiable.
	pushfd			; Store EFLAGs
	pushfd			; Store EFLAGs again. (This will be modified)
	xor dword [esp], 0x00200000 ; Flip the ID flag
	popfd			; Load the modified EFLAGS
	pushfd			; Store it again for inspection
	pop eax
	xor eax, [esp]		; Compare to original EFLAGS
	popfd			; Restore original EFLAGs
	and eax, 0x00200000	; eax = 0 if ID bit cannot be changed, else non-zero
	jz no_cpuid


	; Check if Protected mode available
	mov eax, 0x80000000
	cpuid
	cmp eax, 0x80000000	; Check if functions above 0x80000000 exist
	jbe no_long_mode
	mov eax, 0x80000001	; Extended Processor Signature and Extended Feature Bits
	cpuid
	bt edx, 29		; Test if bit at offset 29 (long mode flag) is on
	jnc no_long_mode	; Exit if not supported


	; Enable A20 line
	call enable_a20
	cmp ax, 0x00
	je a20_disabled

	; Enter long mode
	mov edi, 0xA000		; Place just after Stage2 (0x8000 + 0x2000)
	jmp enter_long_mode


a20_disabled:
	mov si, msg_a20_disabled
	call print_string_16
	jmp halt

; Error printing routines that jump to halt
no_cpuid:
	mov si, msg_no_cpuid
	call print_string_16
	jmp halt


no_long_mode:
	mov si, msg_no_long_mode
	call print_string_16
	jmp halt

; Halts the CPU
halt:
	mov esi, msg_halt
	call print_string_16
	jmp $


; Variables used in REAL MODE
msg_entry 		db 'OS_Loader started', 0x0D, 0x0A, 0x00
msg_no_long_mode 	db 'Long mode not supported', 0x0D,0x0A, 0x00
msg_no_cpuid 		db 'No CPUID',0x0D, 0x0A, 0x00
msg_a20_disabled 	db 'A20 line could not be enabled',0x0D, 0x0A, 0x00
msg_halt		db 'CPU HALT!', 0x0A,0x0D, 0x00
msg_success 		db 'Standing by...',0x0D, 0x0A, 0x00


; 16-bit function to print a sting to the screen
print_string_16:                        ; Output string in SI to screen
        pusha
        mov ah, 0x0E                    ; http://www.ctyme.com/intr/rb-0106.htm
print_string_16_repeat:
        lodsb                           ; Get char from string
        cmp al, 0
        je print_string_16_done         ; If char is zero, end of string
        int 0x10                        ; Otherwise, print it
        jmp print_string_16_repeat
print_string_16_done:
        popa
        ret

; print_number_16
;
; Prints a hex value
;
; input: ax 	= number
hex_prefix 	db '0x' 		; Prefix for the hex_str
hex_str 	db '0000', 0x0D, 0x0A, 0x00 ; Buffer for our hex value
hex   		db '0123456789ABCDEF'
reg16 		dw 0x0000
print_number_16:
	mov di, hex_str
	mov ax, [reg16]
	mov si, hex
	mov cx, 4   ;four places
hexloop:
	rol ax, 4   ;leftmost will
	mov bx, ax   ; become
	and bx, 0x0f   ; rightmost
	mov bl, [si + bx];index into hexstr
	mov [di], bl
	inc di
	dec cx
	jnz hexloop

	mov si, hex_prefix
	call print_string_16
	ret


%include "a20.asm"
%include "longmode.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                  64 BIT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[BITS 64]

; CODE HERE



; print_string
;
; Prints a string in 64 bit mode.
; Color of string is stored in string_color
;
; Input: 	RSI = String to print
;
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

%include "fat.asm"
%include "util.asm"
%include "disk.asm"
;; load kernel to 0x8000
read_fat: ;  ; assume boot off of drive 0
	call hdd_setup ; Don't fucking touch this!!
	
	; load kernel at 0x90000
	mov rdi, 0x90000
	mov rsi, kernel
	call os_fat16_file_read
	jc .read_failed
	jmp 0x90000

	jmp .halt

.read_failed:
	mov rsi, msg_read_failed
	call print_string
.halt:
	
	hlt
	call .halt


; Variables used in LONG MODE (64 bit)
msg_long_mode db 'Long mode entered', 0x00
msg_here db "here", 0x00
kernel db 'kernel.bin'
kernel_formatted times 12 db 0x00
msg_read_failed db "File not found, system halted", 0x00
msg_kernel_loaded db "Loaded kernel", 0x00
drive_number db 0x00
int_str db "      "
fat16_FatStart:			dd 0x00000000
fat16_TotalSectors:		dd 0x00000000
fat16_DataStart:		dd 0x00000000
fat16_RootStart:		dd 0x00000000
fat16_PartitionOffset:		dd 0x00000000
fat16_ReservedSectors:		dw 0x0000
fat16_RootDirEnts:		dw 0x0000
fat16_SectorsPerFat:		dw 0x0000
fat16_BytesPerSector:		dw 0x0000
fat16_SectorsPerCluster:	db 0x00
fat16_Fats:			db 0x00
hdbuffer0: 			equ 0x0000000000070000	; 32768 bytes = 0x70000 -> 0x77FFF
hdbuffer1: 			equ 0x0000000000078000	; 32768 bytes = 0x78000 -> 0x7FFFF
secbuffer0:			equ 0x0000000000080800	; 512 bytes = 0x80800 -> 0x809FF
secbuffer1:			equ 0x0000000000080A00	; 512 bytes = 0x80A00 -> 0x80BFF
os_SystemVariables:	equ 0x0000000000080C00	; Location of System Variables (64 KiB in from 1 MiB)

hd1_maxlba:		equ os_SystemVariables + 40	; 64-bit value since at most it will hold a 48-bit value
hd1_size:		equ os_SystemVariables + 132	; Size in MiB

; Pad to 8190 bytes
; Leave 4 bytes for signature
times 0x1000-4-($-$$) db 0x90
jmp $