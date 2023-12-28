#include "elf.h"
#include "stdint.h"
#include "stdbool.h"

bool is_elf(const uint32_t* buff) {
    return ((buff[0] == 0x7F) && (buff[1] == 'E') && (buff[2] == 'L') && (buff[3] == 'F'));
}

uint64_t load_elf(const uint32_t* buff) {
    const Elf64_Ehdr* hdr = (const Elf64_Ehdr*)buff;
    Elf64_Half n_program_header = hdr->e_phnum;
    const Elf64_Phdr* program_header_table = (const Elf64_Phdr*)(((uint64_t)buff) + hdr->e_phoff);
    Elf64_Addr entry_point = hdr->e_entry;
    Elf64_Addr entry_point_physical = entry_point;
    for (Elf64_Half i = 0; i < n_program_header; i++) {
        Elf64_Phdr program_header = program_header_table[i];
        if (program_header.p_type == 1) {
            char* dest_ptr = (char*)program_header.p_paddr;
            char* src_ptr = (char*)buff + program_header.p_offset;

            if (entry_point >= program_header.p_vaddr && entry_point < program_header.p_vaddr + program_header.p_memsz) {
                if (program_header.p_paddr > program_header.p_vaddr) {
                    entry_point_physical = entry_point + (program_header.p_paddr - program_header.p_vaddr);
                } else {
                    entry_point_physical = entry_point - (program_header.p_vaddr - program_header.p_paddr);
                }
            }

            for (Elf64_Word j = 0; j < program_header.p_memsz; j++) {
                if (j < program_header.p_filesz) {
                    dest_ptr[j] = src_ptr[j];
                } else {
                    dest_ptr[j] = 0;
                }
            }
        }
    }

    return entry_point_physical;
}