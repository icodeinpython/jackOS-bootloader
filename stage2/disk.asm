; NOTE:	These functions use LBA28. Maximum visible drive size is 128GiB
;	LBA48 would be needed to access sectors over 128GiB (up to 128PiB)
;	These functions are hard coded to access the Primary Master HDD


; -----------------------------------------------------------------------------
; readsectors -- Read sectors on the hard drive
; IN:	RAX = starting sector to read
;	RCX = number of sectors to read (1 - 256)
;	RDI = memory location to store sectors
; OUT:	RAX = RAX + number of sectors that were read
;	RCX = number of sectors that were read (0 on error)
;	RDI = RDI + (number of sectors * 512)
;	All other registers preserved
readsectors:
	push rdx
	push rcx
	push rax

	push rcx		; Save RCX for use in the read loop
	cmp rcx, 256
	jg readsectors_fail	; Over 256? Fail!
	jne readsectors_skip	; Not 256? No need to modify CL
	xor rcx, rcx		; 0 translates to 256
readsectors_skip:
	
	push rax		; Save RAX since we are about to overwrite it
	mov dx, 0x01F2		; 0x01F2 - Sector count Port 7:0
	mov al, cl		; Read CL sectors
	out dx, al
	pop rax			; Restore RAX which is our sector number
	inc dx			; 0x01F3 - LBA Low Port 7:0
	out dx, al
	inc dx			; 0x01F4 - LBA Mid Port 15:8
	shr rax, 8
	out dx, al
	inc dx			; 0x01F5 - LBA High Port 23:16
	shr rax, 8
	out dx, al
	inc dx			; 0x01F6 - Device Port. Bit 6 set for LBA mode, Bit 4 for device (0 = master, 1 = slave), Bits 3-0 for LBA "Extra High" (27:24)
	shr rax, 8
	and al, 00001111b 	; Clear bits 4-7 just to be safe
	or al, 01000000b	; Turn bit 6 on since we want to use LBA addressing, leave device at 0 (master)
	out dx, al
	inc dx			; 0x01F7 - Command Port
	mov al, 0x20		; Read sector(s). 0x24 if LBA48
	out dx, al

readsectors_wait:		; VERIFY THIS
	in al, dx
	test al, 8		; This means the sector buffer requires servicing.
	jz readsectors_wait	; Don't continue until the sector buffer is ready.
	pop rcx
	shl rcx, 8		; Multiply RCX by 256 to get the amount of words that will be read
	mov dx, 0x01F0		; Data port - data comes in and out of here.
	rep insw		; Read data to the address starting at RDI

	pop rax
	add rax, rcx
	pop rcx
	pop rdx
ret

readsectors_fail:
	pop rcx
	pop rax
	pop rcx
	pop rdx
	xor rcx, rcx		; Set RCX to 0 since nothing was read
ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF