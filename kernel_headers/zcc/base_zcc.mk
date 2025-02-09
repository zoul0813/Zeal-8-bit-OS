#
# SPDX-FileCopyrightText: 2024 Zeal 8-bit Computer <contact@zeal8bit.com>
#
# SPDX-License-Identifier: Apache-2.0
#

# This file is means to be included by programs based on ZCC.
# This will ease writing a Makefile for a new project that is meant to be
# compiled for Zeal 8-bit OS.
# This file can included by adding this line to any Makefile:
#	include $(ZOS_PATH)/kernel_headers/zcc/base_zcc.mk

SHELL ?= /bin/bash

# Directory where source files are and where the binaries will be put
INPUT_DIR ?= src
OUTPUT_DIR ?= bin

# Specify the files to compile and the name of the final binary
SRCS ?= $(wildcard $(INPUT_DIR)/*.c $(INPUT_DIR)/*.asm)
BIN ?= output.bin

# Include directory containing Zeal 8-bit OS header files.
ifndef ZOS_PATH
$(error "Please define ZOS_PATH environment variable. It must point to Zeal 8-bit OS source code path.")
endif

ZOS_INCLUDE=$(ZOS_PATH)/kernel_headers/zcc/include
# Regarding the linking process, we will need to specify the path to the crt0 REL file.
# It contains the boot code for C programs as well as all the C functions performing syscalls.
CRT_PATH=$(ZOS_PATH)/kernel_headers/zcc/src/zos_crt0.asm


# Compiler, linker and flags related variables
ZOS_CC ?= zcc
# ZOS_LD ?= sdldz80

# Specify Z80 as the target, compile without linking, and place all the code in TEXT section
# (_CODE must be replace).
# ZCC_COMPILER = -compiler=sdcc
CFLAGS = +z80 -clib classic $(ZCC_COMPILER) -crt0=$(CRT_PATH) -I$(ZOS_INCLUDE)
EXTRA_SRCS = $(ZOS_PATH)/kernel_headers/zcc/src/zeal8bitos.asm
# # Make sure the whole program is relocated at 0x4000 as request by Zeal 8-bit OS.
# LDFLAGS = -n -mjwx -i -b _HEADER=0x4000 -k $(ZOS_PATH)/kernel_headers/zcc/lib -l z80 $(ZOS_LDFLAGS)


# Generate the intermediate Intel Hex binary name
BIN_HEX=$(patsubst %.bin,%.ihx,$(BIN))
# Generate the rel names for C source files. Only keep the file names, and add output dir prefix.
SRCS_OUT_DIR=$(addprefix $(OUTPUT_DIR)/,$(SRCS))
SRCS_REL=$(patsubst %.c,%.rel,$(SRCS_OUT_DIR))


.PHONY: all clean

all:: clean $(OUTPUT_DIR)
	@bash -c 'echo -e "\x1b[32;1mSuccess, binary generated: $(OUTPUT_DIR)/$(BIN)\x1b[0m"'
	$(ZOS_CC) $(CFLAGS) $(LDFLAGS) -o=$(OUTPUT_DIR)/$(BIN) -m -s --list $(EXTRA_SRCS) $(SRCS)

$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

clean:
	rm -fr ./$(OUTPUT_DIR)