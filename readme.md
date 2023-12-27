# JackOS bootloader

Boot Process:
------------

Bootsector: Load binary file names STAGE2 in FAT-16 file system to address 0x7E00 (Directly after bootsector code)

STAGE2: Implemented custom read-only 
