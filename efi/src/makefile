ARCH  = x86_64
CC    = ${ARCH}-elf-gcc

BUILD_DIR  := ../build

EFI_INC_DIR = ../gnu-efi/inc
INCLUDE_DIRS := ${EFI_INC_DIR}    \
	${EFI_INC_DIR}/${ARCH}          \
	${EFI_INC_DIR}/protocol         \
	../include

INCLUDE_FLAG  = $(foreach d, $(INCLUDE_DIRS), -I$d)

CFLAGS := ${INCLUDE_FLAG} -ffreestanding -fno-common -fno-stack-protector -fpic -fshort-wchar -Wall -Wextra -Wmissing-prototypes -Wstrict-prototypes -mno-red-zone -DEFI_FUNCTION_WRAPPER

LIB := /usr/lib
EFI_LIB := /usr/lib
EFI_CRT_OBJS := $(EFI_LIB)/crt0-efi-${ARCH}.o
EFI_LDS      := ${EFI_LIB}/elf_${ARCH}_efi.lds
LDFLAGS		 := -nostdlib -znocombreloc -T ${EFI_LDS} -shared -Bsymbolic -L ${EFI_LIB} -L ${LIB} ${EFI_CRT_OBJS}

C_SOURCES := ${SRC_DIR}/elf.c    \
	${SRC_DIR}/error.c             \
	${SRC_DIR}/fs.c                \
	${SRC_DIR}/graphics.c          \
	${SRC_DIR}/loader.c            \
	${SRC_DIR}/main.c              \
	${SRC_DIR}/serial.c

AS_SOURCES :=

C_SOURCES := elf.c    	 \
	error.c             \
	fs.c                \
	graphics.c          \
	loader.c            \
	main.c              \
	serial.c

OBJECTS := ${C_SOURCES:.c=.o}

BINARY_ELF := ${BUILD_DIR}/bootx64.so
BINARY_EFI := ${BUILD_DIR}/bootx64.efi

.PHONY: all clean emu

all: ${BINARY_EFI}

${BINARY_EFI}: ${BINARY_ELF}
	objcopy -j .text          \
		-j .sdata               \
		-j .data                \
		-j .dynamic             \
		-j .dynsym              \
		-j .rel                 \
		-j .rela                \
		-j .reloc               \
		--target=efi-app-${ARCH} $^ $@

${BINARY_ELF}: ${OBJECTS} ${BUILD_DIR}
	ld ${LDFLAGS} ${OBJECTS} -o $@ -lefi -lgnuefi

%.o: %.c
	${CC} ${CFLAGS} -o $@ -c $<

%.o: %.S
	${CC} ${CFLAGS} -o $@ -c $<

${BUILD_DIR}:
	mkdir -p ${BUILD_DIR}

clean:
	rm -f ${OBJECTS}
	rm -f ${BINARY_ELF}
	rm -f ${BINARY_EFI}
	rm -rf ${BUILD_DIR}