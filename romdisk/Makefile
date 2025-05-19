# Before including the Makefiles, include the configuration one if it exists
-include $(ZOS_PATH)/$(KCONFIG_CONFIG)

# Final binary name
BIN=init.bin
# Source files to assemble

# shell core
SRCS=init.asm parse.asm opt.asm errors.asm uart.asm date.asm misc.asm
# shell commands that always exist
SRCS += cd.asm sleep.asm expr.asm
# extras, coreutils will eventually support these
# ls_main used by dir
SRCS += less.asm xfer.asm ls.asm


# Output directory to place binaries in
BUILDIR=build

# Name of the image file to make
IMG=disk.img
# Files to pack inside the image file
FILES_IN_IMG=$(BUILDIR)/$(BIN) simple.txt
EXTRA_ROMDISK_FILES := $(wildcard $(EXTRA_ROMDISK_FILES))


# If z88dk has been install through snap, the binary may be prefixed with "z88dk"
# So choose any of z88dk-* or z88dk.z88dk-*, as long as one exists
CC=$(shell which z88dk-z80asm z88dk.z88dk-z80asm | head -1)

# On some versions of z88dk, -Oxxx switch does not generate the init_TEXT.bin file,
# it only creates empty init.bin. Generate all the binaries in the current directory
# and move them manually
INCLUDES=-I$(ZOS_PATH)/kernel_headers/z88dk-z80asm -I$(ZOS_PATH)/kernel_headers/z88dk-z80asm/include
LIBS=-L$(ZOS_PATH)/kernel_headers/z88dk-z80asm/lib
ASMFLAGS=$(INCLUDES) $(LIBS) -lstrutils.lib -m -b


ifdef CONFIG_INITBIN_ENABLE_COREUTILS
	ASMFLAGS += -DCONFIG_ENABLE_COREUTILS=1
else
	SRCS += cat.asm mkdir.asm rm.asm cp.asm hexdump.asm echo.asm
endif


.PHONY: all clean

all: clean
	@ ( test -n "$(EXTRA_ROMDISK_FILES)" && \
	    echo "Extra files detected: $(EXTRA_ROMDISK_FILES)" ) || \
	    echo "No extra file to pack into romdisk"
	@mkdir -p $(BUILDIR)
	@echo "CONFIG_ENABLE_COREUTILS=$(CONFIG_INITBIN_ENABLE_COREUTILS)"
	@echo "Creating romdisk"
	$(CC) $(ASMFLAGS) $(SRCS)
	@echo "Moving generated files"
	mv *.o ./$(BUILDIR) && mv *.map ./$(BUILDIR) && mv $(basename $(BIN))*.bin ./$(BUILDIR)
	@# For some reasons, z88dk-z80asm will create an empty `init.bin` file, remove it
	@rm -f $(BUILDIR)/$(BIN) && mv $(BUILDIR)/*_TEXT.bin $(BUILDIR)/$(BIN)

with_image: all
	@echo "Packing the files"
	${ZOS_PATH}/tools/pack.py ${IMG} ${FILES_IN_IMG} ${EXTRA_ROMDISK_FILES}

clean:
	rm -rf build/ $(IMG)
