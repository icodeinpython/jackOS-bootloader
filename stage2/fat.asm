; =============================================================================
; BareMetal -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2008-2010 Return Infinity -- see LICENSE.TXT
;
; FAT16 Functions
; =============================================================================

align 16
db 'DEBUG: FAT16    '
align 16

hdd_setup:
; Read first sector (MBR) into memory
	xor rax, rax
	mov rdi, secbuffer0
	push rdi
	mov rcx, 1
	call readsectors
	pop rdi

	cmp byte [0x000000000000F030], 0x01	; Did we boot from a MBR drive
	jne hdd_setup_no_mbr			; If not then we already have the correct sector

; Grab the partition offset value for the first partition
	mov eax, [rdi+0x01C6]
	mov [fat16_PartitionOffset], eax

; Read the first sector of the first partition
	mov rdi, secbuffer0
	push rdi
	mov rcx, 1
	call readsectors
	pop rdi

hdd_setup_no_mbr:
; Get the values we need to start using fat16
	mov ax, [rdi+0x0b]
	mov [fat16_BytesPerSector], ax		; This will probably be 512
	mov al, [rdi+0x0d]
	mov [fat16_SectorsPerCluster], al	; This will be 128 or less (Max cluster size is 64KiB)
	mov ax, [rdi+0x0e]
	mov [fat16_ReservedSectors], ax
	mov [fat16_FatStart], eax
	mov al, [rdi+0x10]
	mov [fat16_Fats], al			; This will probably be 2
	mov ax, [rdi+0x11]
	mov [fat16_RootDirEnts], ax
	mov ax, [rdi+0x16]
	mov [fat16_SectorsPerFat], ax

; Find out how many sectors are on the disk
	xor eax, eax
	mov ax, [rdi+0x13]
	cmp ax, 0x0000
	jne lessthan65536sectors
	mov eax, [rdi+0x20]
lessthan65536sectors:
	mov [fat16_TotalSectors], eax

; Calculate the size of the drive in MiB
	xor rax, rax
	mov eax, [fat16_TotalSectors]
	mov [hd1_maxlba], rax
	shr rax, 11 ; rax = rax * 512 / 1048576
	mov [hd1_size], eax ; in mebibytes

; Calculate FAT16 info
	xor rax, rax
	xor rbx, rbx
	mov ax, [fat16_SectorsPerFat]
	shl ax, 1	; quick multiply by two
	add ax, [fat16_ReservedSectors]
	mov [fat16_RootStart], eax
	mov bx, [fat16_RootDirEnts]
	shr ebx, 4	; bx = (bx * 32) / 512
	add ebx, eax	; BX now holds the datastart sector number
	mov [fat16_DataStart], ebx

ret


; -----------------------------------------------------------------------------
; os_fat16_read_cluster -- Read a cluster from the FAT16 partition
; IN:	AX  = Cluster # to read
;	RDI = Memory location to store at least 32KB
; OUT:	AX  = Next cluster in chain (0xFFFF if this was the last)
;	RDI = Points one byte after the last byte read
os_fat16_read_cluster:
	push rsi
	push rdx
	push rcx
	push rbx

	and rax, 0x000000000000FFFF		; Clear the top 48 bits
	mov rbx, rax				; Save the cluster number to be used later

	cmp ax, 2				; If less than 2 then bail out...
	jl near os_fat16_read_cluster_bailout	; as clusters start at 2

; Calculate the LBA address --- startingsector = (cluster-2) * clustersize + data_start
	xor rcx, rcx	
	mov cl, byte [fat16_SectorsPerCluster]
	push rcx				; Save the number of sectors per cluster
	sub ax, 2
	imul cx					; EAX now holds starting sector
	add eax, dword [fat16_DataStart]	; EAX now holds the sector where our cluster starts
	add eax, [fat16_PartitionOffset]	; Add the offset to the partition

	pop rcx					; Restore the number of sectors per cluster
	call readsectors			; Read one cluster of sectors

; Calculate the next cluster
; Psuedo-code
; tint1 = Cluster / 256  <- Dump the remainder
; sector_to_read = tint1 + ReservedSectors
; tint2 = (Cluster - (tint1 * 256)) * 2
	push rdi
	mov rdi, secbuffer1			; Read to this temporary buffer
	mov rsi, rdi				; Copy buffer address to RSI
	push rbx				; Save the original cluster value
	shr rbx, 8				; Divide the cluster value by 256. Keep no remainder
	movzx ax, [fat16_ReservedSectors]	; First sector of the first FAT
	add eax, [fat16_PartitionOffset]	; Add the offset to the partition
	add rax, rbx				; Add the sector offset
	mov rcx, 1
	call readsectors
	pop rax					; Get our original cluster value back
	shl rbx, 8				; Quick multiply by 256 (RBX was the sector offset in the FAT)
	sub rax, rbx				; RAX is now pointed to the offset within the sector
	shl rax, 1				; Quickly multiply by 2 (since entries are 16-bit)
	add rsi, rax
	lodsw					; AX now holds the next cluster
	pop rdi

	jmp os_fat16_read_cluster_end

os_fat16_read_cluster_bailout:
	xor ax, ax

os_fat16_read_cluster_end:
	pop rbx
	pop rcx
	pop rdx
	pop rsi
ret
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; os_fat16_find_file -- Search for a file name and return the starting cluster
; IN:	RSI = Pointer to file name, must be in 'FILENAMEEXT' format
; OUT:	AX  = Staring cluster
;	Carry set if not found. If carry is set then ignore value in AX
os_fat16_find_file:
	push rsi
	push rdi
	push rdx
	push rcx
	push rbx

	clc				; Clear carry
	xor rax, rax
	mov eax, [fat16_RootStart]	; eax points to the first sector of the root
	add eax, [fat16_PartitionOffset]	; Add the offset to the partition
	mov rdx, rax			; Save the sector value

os_fat16_find_file_read_sector:
	mov rdi, hdbuffer1
	push rdi
	mov rcx, 1
	call readsectors
	pop rdi
	mov rbx, 16			; Each record is 32 bytes. 512 (bytes per sector) / 32 = 16

os_fat16_find_file_next_entry:
	cmp byte [rdi], 0x00		; end of records
	je os_fat16_find_file_notfound
	
	mov rcx, 11
	push rsi
	repe cmpsb
	pop rsi
	mov ax, [rdi+15]		; AX now holds the starting cluster # of the file we just looked at
	jz os_fat16_find_file_done	; The file was found. Note that rdi now is at dirent+11

	add rdi, byte 0x20
	and rdi, byte -0x20
	dec rbx
	cmp rbx, 0
	jne os_fat16_find_file_next_entry

; At this point we have read though one sector of file names. We have not found the file we are looking for and have not reached the end of the table. Load the next sector.

	add rdx, 1
	mov rax, rdx
	jmp os_fat16_find_file_read_sector

os_fat16_find_file_notfound:
	stc				; Set carry
	xor rax, rax

os_fat16_find_file_done:
	cmp ax, 0x0000			; BUG HERE
	jne wut				; Carry is not being set properly in this function
	stc
wut:
	pop rbx
	pop rcx
	pop rdx
	pop rdi
	pop rsi
ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_fat16_get_file_list -- Generate a list of files on disk
; IN:	RDI = location to store list
; OUT:	RDI = pointer to end of list
os_fat16_get_file_list:
	push rsi
	push rdi
	push rcx
	push rbx
	push rax

	push rsi
	mov rsi, dir_title_string
	call strlen
	call strcpy			; Copy the header
	add rdi, rcx
	pop rsi

	xor rbx, rbx
	mov ebx, [fat16_RootStart]		; ebx points to the first sector of the root
	add ebx, [fat16_PartitionOffset]	; Add the offset to the partition

	jmp os_fat16_get_file_list_read_sector

os_fat16_get_file_list_next_sector:
	add rbx, 1

os_fat16_get_file_list_read_sector:
	push rdi
	mov rdi, hdbuffer1
	mov rsi, rdi
	mov rcx, 1
	mov rax, rbx	
	call readsectors
	pop rdi

	; RDI = location of string
	; RSI = buffer that contains the cluster

	; start reading
os_fat16_get_file_list_read:
	cmp rsi, hdbuffer1+512
	je os_fat16_get_file_list_next_sector
	cmp byte [rsi], 0x00		; end of records
	je os_fat16_get_file_list_done
	cmp byte [rsi], 0xE5		; unused record
	je os_fat16_get_file_list_skip

	mov al, [rsi + 8]		; Grab the attribute byte
	bt ax, 5			; check if bit 3 is set (volume label)
	jc os_fat16_get_file_list_skip	; if so skip the entry
	mov al, [rsi + 11]		; Grab the attribute byte
	cmp al, 0x0F			; Check if it is a LFN entry
	je os_fat16_get_file_list_skip	; if so skip the entry

	; copy the string
	xor rcx, rcx
	xor rax, rax
os_fat16_get_file_list_copy:
	mov al, [rsi+rcx]
	stosb				; Store to RDI
	inc rcx
	cmp rcx, 8
	jne os_fat16_get_file_list_copy

	mov al, ' '			; Store a space as the separtator
	stosb

	mov al, [rsi+8]
	stosb
	mov al, [rsi+9]
	stosb
	mov al, [rsi+10]
	stosb

	mov al, ' '			; Store a space as the separtator
	stosb

	mov eax, [rsi+0x1C]
	call os_int_to_string
	dec rdi
	mov al, 13
	stosb

os_fat16_get_file_list_skip:
	add rsi, 32
	jmp os_fat16_get_file_list_read

os_fat16_get_file_list_done:
	mov al, 0x00
	stosb

	pop rax
	pop rbx
	pop rcx
	pop rdi
	pop rsi
ret

dir_title_string: db "Name     Ext Size", 13, "====================", 13, 0
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_fat16_file_read -- Read a file from disk into memory
; IN:	RSI = Address of filename string
;	RDI = Memory location where file will be loaded to
; OUT:	Carry clear on success, set if file was not found or error occured
os_fat16_file_read:
	push rsi
	push rdi
	push rax

; Convert the file name to FAT format
	push rdi			; Save the memory address
	mov rdi, os_fat16_file_read_string
	call os_fat16_filename_convert	; Convert the filename to the proper FAT format
	xchg rsi, rdi
	pop rdi				; Grab the memory address
	jc os_fat16_file_read_done	; If Carry is set then the filename could not be converted

; Check to see if the file exists
	call os_fat16_find_file		; Fuction will return the starting cluster value in AX or carry set if not found
	jc os_fat16_file_read_done	; If Carry is clear then the file exists. AX is set to the starting cluster

os_fat16_file_read_read:
	call os_fat16_read_cluster	; Store cluster in memory. AX is set to the next cluster
	cmp ax, 0xFFFF			; 0xFFFF is the FAT end of file marker
	jne os_fat16_file_read_read	; Are there more clusters? If so then read again.. if not fall through
	push rsi
	mov rsi, msg_here
	call print_string
	pop rsi
	clc				; Clear Carry

os_fat16_file_read_done:
	pop rax
	pop rdi
	pop rsi
ret

	os_fat16_file_read_string	times 13 db 0
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; os_fat16_filename_convert -- Change 'test.er' into 'TEST    ER ' as per FAT16
; IN:	RSI = filename string
;	RDI = location to store converted string (carry set if invalid)
; OUT:	All registers preserved
; NOTE:	Must have room for 12 bytes. 11 for the name and 1 for the NULL
;	Need fix for short extensions!
os_fat16_filename_convert:
	push rsi
	push rdi
	push rdx
	push rcx
	push rbx
	push rax

	mov rbx, rdi				; Save the string destination address
	call strlen
	cmp rcx, 12				; Bigger than name + dot + extension?
	jg os_fat16_filename_convert_failure	; Fail if so
	cmp rcx, 0
	je os_fat16_filename_convert_failure	; Similarly, fail if zero-char string

	mov rdx, rcx			; Store string length for now
	xor rcx, rcx
os_fat16_filename_convert_copy_loop:
	lodsb
	cmp al, '.'
	je os_fat16_filename_convert_extension_found
	stosb
	inc rcx
	cmp rcx, rdx
	jg os_fat16_filename_convert_failure	; No extension found = wrong
	jmp os_fat16_filename_convert_copy_loop

os_fat16_filename_convert_failure:
	stc					; Set carry for failure
	jmp os_fat16_filename_convert_done

os_fat16_filename_convert_extension_found:
	cmp rcx, 0
	je os_fat16_filename_convert_failure	; Fail if extension dot is first char
	cmp rcx, 8
	je os_fat16_filename_convert_do_extension	; Skip spaces if first bit is 8 chars

	mov al, ' '
os_fat16_filename_convert_add_spaces:
	stosb
	inc rcx
	cmp rcx, 8
	jl os_fat16_filename_convert_add_spaces

os_fat16_filename_convert_do_extension:				; FIX THIS for cases where ext is less than 3 chars
	lodsb
	stosb
	lodsb
	stosb
	lodsb
	stosb
	mov byte [rdi], 0		; Zero-terminate filename
	clc				; Clear carry for success
	mov rsi, rbx			; Get the start address of the desitination string
	call os_string_uppercase	; Set it all to uppercase

os_fat16_filename_convert_done:
	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rdi
	pop rsi
ret
; -----------------------------------------------------------------------------


; =============================================================================
; EOF