; SPDX-FileCopyrightText: 2024 Zeal 8-bit Computer <contact@zeal8bit.com>
; SPDX-FileContributor: Originally authored by David Higgins <https://github.com/zoul0813>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "osconfig.asm"
    INCLUDE "vfs_h.asm"
    INCLUDE "errors_h.asm"
    INCLUDE "drivers_h.asm"
    INCLUDE "disks_h.asm"
    INCLUDE "utils_h.asm"
    INCLUDE "strutils_h.asm"
    INCLUDE "fs/fat16_h.asm"

    INCLUDE "log_h.asm"

    SECTION KERNEL_TEXT


;   DEFC's
    DEFC FILENAME_LEN           = 8
    DEFC EXTENSION_LEN          = 3
    DEFC MAX_BUFFER_SIZE        = 32768

    ; File Attributes
    DEFC FILE_ATTR_READONLY     = 0
    DEFC FILE_ATTR_HIDDEN       = 1
    DEFC FILE_ATTR_SYSTEM       = 2
    DEFC FILE_ATTR_VOLUME       = 3
    DEFC FILE_ATTR_DIRECTORY    = 4
    DEFC FILE_ATTR_ARCHIVE      = 5
    ;;;; bits 6-7 reserved

    ; struct_bootSector - FAT16 Boot Sector
    DEFC BOOTSECTOR_START                     = 0x0000  ; of bootSector
    DEFC BOOTSECTOR_BOOTSTRAPJUMP             = 0x0000  ; Code to jump to the bootstrap code.
    DEFC BOOTSECTOR_OEMID                     = 0x0003  ; Oem ID 1 - Name of the formatting OS
    DEFC BOOTSECTOR_BYTESPERSECTOR            = 0x000B  ; Bytes per Sector
    DEFC BOOTSECTOR_SECTORSPERCLUSTER         = 0x000D  ; Sectors per Cluster - Usual there is 512 bytes per sector.
    DEFC BOOTSECTOR_RESERVEDSECTORS           = 0x000E  ; Reserved sectors from the start of the volume.
    DEFC BOOTSECTOR_NUMBEROFFAT               = 0x0010  ; Number of FAT copies - Usual 2 copies are used to prevent data loss.
    DEFC BOOTSECTOR_NUMBEROFROOT              = 0x0011  ; Number of possible root entries - 512 entries are recommended.
    DEFC BOOTSECTOR_SMALLSECTORS              = 0x0013  ; Small number of sectors - Used when volume size is less than 32 Mb.
    DEFC BOOTSECTOR_MEDIADESCRIPTOR           = 0x0015  ; Media Descriptor
    DEFC BOOTSECTOR_SECTORSPERFAT             = 0x0016  ; Sectors per FAT
    DEFC BOOTSECTOR_SECTORSPERTRACK           = 0x0018  ; Sectors per Track
    DEFC BOOTSECTOR_NUMBEROFHEADS             = 0x001A  ; Number of Heads
    DEFC BOOTSECTOR_HIDDENSECTORS             = 0x001C  ; Hidden Sectors
    DEFC BOOTSECTOR_LARGESECTORS              = 0x0020  ; Large number of sectors - Used when volume size is greater than 32 Mb.
    DEFC BOOTSECTOR_DRIVENUMBER               = 0x0024  ; Drive Number - Used by some bootstrap code, fx. MS-DOS.
    DEFC BOOTSECTOR_RESERVED                  = 0x0025  ; Reserved - Is used by Windows NT to decide if it shall check disk integrity.
    DEFC BOOTSECTOR_EXTENDEDBOOTSIGNATURE     = 0x0026  ; Extended Boot Signature - Indicates that the next three fields are available.
    DEFC BOOTSECTOR_VOLUMESERIAL              = 0x0027  ; Volume Serial Number
    DEFC BOOTSECTOR_VOLUMELABEL               = 0x002B  ; Volume Label - Should be the same as in the root directory.
    DEFC BOOTSECTOR_FSTYPE                    = 0x0036  ; File System Type - The string should be 'FAT16 '
    DEFC BOOTSECTOR_BOOTSTRAPCODE             = 0x003E  ; Bootstrap code - May schrink in the future.
    DEFC BOOTSECTOR_BOOTSECTORSIGNATURE       = 0x01FE  ; Boot sector signature - This is the AA55h signature.
    DEFC BOOTSECTOR_END                       = 0x0200  ; of bootSector
    ; /struct_bootSector
;
    ; struct_Disk
fat16_disk_start:                     DS 0, 0xFF                  ; start of disk
fat16_disk_fd:                        DS 1, 0x00                  ; file descriptor
fat16_disk_bytesPerSector:            DS 2, 0x00                  ; bytes per sector
fat16_disk_sectorsPerCluster:         DS 1, 0x00                  ; sectors per cluster
fat16_disk_reservedSectors:           DS 2, 0x00
fat16_disk_numberOfFat:               DS 1, 0x00
fat16_disk_sectorsPerFat:             DS 2, 0x00
fat16_disk_rootSector:                DS 4, 0x00                  ; root sector
fat16_disk_bytesPerCluster:           DS 4, 0x00                  ; bytes per cluster
fat16_disk_end:                       DS 0, 0xFF                  ; end of disk
    ; /struct_Disk
;
    ; struct_directoryEntry
fat16_entry_start:                    DS 0, 0xFF                  ; start of directory entry
fat16_entry_filename:                 DS FILENAME_LEN,  0x00      ; 00h Filename
fat16_entry_extension:                DS EXTENSION_LEN, 0x00      ; 08h Filename Extension
fat16_entry_attributes:               DS 1, 0x00                  ; 0Bh Attribute Byte
fat16_entry_reserved:                 DS 1, 0x00                  ; 0Ch Reserved for Windows NT
fat16_entry_createdMs:                DS 1, 0x00                  ; 0Dh Creation - Millisecond stamp (actual 100th of a second)
fat16_entry_createdTime:              DS 2, 0x00                  ; 0Eh Creation Time
fat16_entry_createdDate:              DS 2, 0x00                  ; 10h Creation Date
fat16_entry_lastAccessDate:           DS 2, 0x00                  ; 12h Last Access Date
fat16_entry_reserved2:                DS 2, 0x00                  ; 14h Reserved for FAT32
fat16_entry_lastWriteTime:            DS 2, 0x00                  ; 16h Last Write Time
fat16_entry_lasrtWriteDate:           DS 2, 0x00                  ; 18h Last Write Date
fat16_entry_startingCluster:          DS 2, 0x00                  ; 1Ah Starting cluster
fat16_entry_filesize:                 DS 4, 0x00                  ; 1Ch File size in bytes
fat16_entry_end:                      DS 0, 0xFF                  ; end of directory entry
    ; /struct_directoryEntry
;
    ; struct_readFile
fat16_file_start:                     DS 0, 0xFF                  ; start of read file
fat16_file_size:                      DS 4, 0x00                  ; size to read
fat16_file_remaining:                 DS 4, 0x00                  ; remaining bytes
fat16_file_total_read:                DS 4, 0x00                  ; read file index
fat16_file_next_cluster:              DS 2, 0x00                  ; next cluster
fat16_file_sector_address:            DS 4, 0x00                  ; sector address
fat16_file_end:                       DS 0, 0xFF                  ; end of read file
    ; /struct_readFile
;
file_buffer:                          DS 0xFF, 0x00                  ; file buffer to read data into

    MACRO ON_ERROR handler
        or a
        jp nz, handler
    ENDM

    MACRO FETCH buffer, sz
        ld a, (fat16_disk_fd) ; disk dev
        ; TODO: read from the current driver
        ; S_READ3(a, buffer, sz)
    ENDM

    MACRO CLEAR_CARRY
        or a
    ENDM



    ; These macros points to code that will be loaded and executed within the buffer
    DEFC RAM_EXE_CODE  = _vfs_work_buffer
    DEFC RAM_EXE_READ  = RAM_EXE_CODE
    DEFC RAM_EXE_WRITE = RAM_EXE_READ + 8
    ; This 3-byte operation buffer will contain either JP RAM_EXE_READ or JP RAM_EXE_WRITE.
    ; It will be populated and used by the algorithm that will perform reads and writes from and to files.
    DEFC RAM_EXE_OPER  = RAM_EXE_WRITE + 8
    ; Same here, this will contain a JP instruction that will be used as a callback when the
    ; next disk page of a file is 0 (used during reads and writes)
    DEFC RAM_EXE_PAGE_0 =  RAM_EXE_OPER + 3

    ; Use this word to save which entry of the last directory was free. This will be filled by
    ; _zos_zealfs_check_next_name. Must be cleaned by the caller.
    DEFC RAM_FREE_ENTRY = RAM_EXE_PAGE_0 + 3  ; Reserve 3 bytes for the previous RAM code
    DEFC RAM_BUFFER     = RAM_FREE_ENTRY + 2 ; Reserve 2 byte for the previous label

    ; Make sure we can still store at least a header in the buffer
    ; ASSERT(24 + ZEALFS_HEADER_SIZE <= VFS_WORK_BUFFER_SIZE)

    ; Used to create self-modifying code in RAM
    DEFC XOR_A    = 0xaf
    DEFC LD_L_A   = 0x6f
    DEFC LD_H_A   = 0x67
    DEFC PUSH_HL  = 0xe5
    DEFC LD_HL    = 0x21
    DEFC JP_NNNN  = 0xc3
    DEFC ARITH_OP = 0xcb
    DEFC RET_OP   = 0xc9

    EXTERN _vfs_work_buffer
    EXTERN zos_date_getdate_kernel

    ; Open a file from a disk. The opened-file structure that must be return on success
    ; can be allocated by calling the function `zos_disk_allocate_opnfile` from the `disk.asm` file.
    ; Parameters:
    ;       B - Flags, can be O_RDWR, O_RDONLY, O_WRONLY, O_NONBLOCK, O_CREAT, O_APPEND, etc...
    ;       HL - Absolute path, without the disk letter (without X:), guaranteed not NULL by caller.
    ;       DE - Driver address, guaranteed not NULL by the caller.
    ; Returns:
    ;       A - ERR_SUCCESS on success, error code else
    ;       HL - Opened-file structure address, passed through all the other calls, until closed
    ; Alters:
    ;       A, BC, DE, HL
    PUBLIC zos_fat16_open
zos_fat16_open:
    ld hl, _unsupported_open
    call zos_log_warning
    ld a, ERR_NOT_IMPLEMENTED
    ret
;


    ; Get the stats of a file from a disk.
    ; This includes the date, the size and the name. More info about the stat structure
    ; in `vfs_h.asm` file.
    ; Parameters:
    ;       BC - Driver address, guaranteed not NULL by the caller.
    ;       HL - Opened file structure address, pointing to the user field.
    ;       DE - Address of the STAT_STRUCT to fill.
    ; Returns:
    ;       A - ERR_SUCCESS on success, error code else
    ; Alters:
    ;       A, BC, DE, HL (Can alter any of the fields)
    PUBLIC zos_fat16_stat
zos_fat16_stat:
    ld hl, _unsupported_stat
    call zos_log_warning
    ld a, ERR_NOT_IMPLEMENTED
    ret
;


    ; Read bytes of an opened file.
    ; At most BC bytes must be read in the buffer pointed by DE.
    ; Upon completion, the actual number of bytes filled in DE must be
    ; returned in BC register. It must be less or equal to the initial
    ; value of BC.
    ; Note: _vfs_work_buffer can be used at our will here
    ; Parameters:
    ;       HL - Address of the opened file. Guaranteed by the caller to be a
    ;            valid opened file. It embeds the offset to read from the file,
    ;            the driver address and the user field (filled above).
    ;            READ-ONLY, MUST NOT BE MODIFIED.
    ;       DE - Buffer to fill with the read bytes. Guaranteed to not be cross page boundaries.
    ;       BC - Size of the buffer passed, maximum size is a page size guaranteed.
    ;            It is also guaranteed to not overflow the file's total size.
    ; Returns:
    ;       A  - 0 on success, error value else
    ;       BC - Number of bytes filled in DE.
    ; Alters:
    ;       A, BC, DE, HL
    PUBLIC zos_fat16_read
zos_fat16_read:
    ld hl, _unsupported_read
    call zos_log_warning
    ld a, ERR_NOT_IMPLEMENTED
    ret
;

    ; Perform a write on an opened file.
    ; Parameters:
    ;       HL - Address of the opened file. Guaranteed by the caller to be a
    ;            valid opened file. It embeds the offset to write to the file,
    ;            the driver address and the user field.
    ;            READ-ONLY, MUST NOT BE MODIFIED.
    ;       DE - Buffer containing the bytes to write to the opened file, the buffer is gauranteed to
    ;            NOT cross page boundary.
    ;       BC - Size of the buffer passed, maximum size is a page size
    ; Returns:
    ;       A  - ERR_SUCCESS on success, error code else
    ;       BC - Number of bytes in DE.
    ; Alters:
    ;       A, BC, DE, HL
    PUBLIC zos_fat16_write
zos_fat16_write:
    ld hl, _unsupported_write
    call zos_log_warning
    ld a, ERR_NOT_IMPLEMENTED
    ret
;


    ; Close an opened file.
    ; Parameters:
    ;       HL - (RW) Address of the user field in the opened file structure
    ;       DE - Driver address
    ; Returns:
    ;       A  - 0 on success, error value else
    ; Alters:
    ;       A, BC, DE, HL
    PUBLIC zos_fat16_close
zos_fat16_close:
    ld hl, _unsupported_close
    call zos_log_warning
    ld a, ERR_NOT_IMPLEMENTED
    ret
;

    ; ====================== Directories related ====================== ;

    ; Open a directory from a disk.
    ; Parameters:
    ;       HL - Absolute path, without the disk letter (without X:), guaranteed not NULL by caller.
    ;       DE - Driver address, guaranteed not NULL by the caller.
    ; Returns:
    ;       A - ERR_SUCCESS on success, error code else
    ;       HL - Opened-dir structure address, passed through all the other calls, until closed
    ; Alters:
    ;       A, BC, DE, HL
    PUBLIC zos_fat16_opendir
zos_fat16_opendir:

    ; call _load_boot_sector

    ; Treat / as a special case
    inc hl
    ld a, (hl)
    or a
    jr z, _zos_fat16_opendir_root


    ld hl, _unsupported_opendir
    call zos_log_warning
    ld a, ERR_NOT_IMPLEMENTED
    ret
;

_zos_fat16_opendir_root:
    ld hl, _unsupported_opendir_root
    call zos_log_warning
    ld a, ERR_NOT_IMPLEMENTED
    ret
;


    ; Read the next entry from the opened directory and store it in the user's buffer.
    ; The given buffer is guaranteed to be big enough to store DISKS_DIR_ENTRY_SIZE bytes.
    ; Parameters:
    ;       HL - Address of the user field in the opened directory structure. This is the same address
    ;            as the one given when opendir was called.
    ;       DE - Buffer to fill with the next entry data. Guaranteed to not be cross page boundaries.
    ;            Guaranteed to be at least DISKS_DIR_ENTRY_SIZE bytes.
    ; Returns:
    ;       A - ERR_SUCCESS on success,
    ;           ERR_NO_MORE_ENTRIES if the end of directory has been reached,
    ;           error code else
    ; Alters:
    ;       A, BC, DE, HL (can alter any)
    PUBLIC zos_fat16_readdir
zos_fat16_readdir:
    ld hl, _unsupported_readdir
    call zos_log_warning
    ld a, ERR_NOT_IMPLEMENTED
    ret
;


    ; Create a directory on a disk.
    ; Parameters:
    ;       HL - Absolute path of the new directory to create, without the
    ;            disk letter (without X:/), guaranteed not NULL by caller.
    ;       DE - Driver address, guaranteed not NULL by the caller.
    ; Returns:
    ;       A - ERR_SUCCESS on success, error code else
    ; Alters:
    ;       A
    PUBLIC zos_fat16_mkdir
zos_fat16_mkdir:
    ld hl, _unsupported_mkdir
    call zos_log_warning
    ld a, ERR_NOT_IMPLEMENTED
    ret
;

    ; Remove a file or a(n empty) directory on the disk.
    ; Parameters:
    ;       HL - Absolute path of the file/dir to remove, without the
    ;            disk letter (without X:), guaranteed not NULL by caller.
    ;       DE - Driver address, guaranteed not NULL by the caller.
    ; Returns:
    ;       A - ERR_SUCCESS on success, error code else
    ; Alters:
    ;       A
    PUBLIC zos_fat16_rm
zos_fat16_rm:
    ld hl, _unsupported_rm
    call zos_log_warning
    ld a, ERR_NOT_IMPLEMENTED
    ret
;

zos_fat16_on_error:
    ld a, ERR_FAILURE
    ret

zos_fat16_driver_end:

    ;======================================================================;
    ;================= P R I V A T E   R O U T I N E S ====================;
    ;======================================================================;

    ; Load the boot sector, populate struct_Disk
        ; Returns:
        ; Alters:
        ;       ???
_load_boot_sector:
    ld bc, 0
    ld de, BOOTSECTOR_BYTESPERSECTOR
    call _seek
    ON_ERROR(zos_fat16_on_error)

    ; read the OEM ID from the Boot Sector and print it out
    FETCH(fat16_disk_bytesPerSector, 2)
    ON_ERROR(zos_fat16_on_error)

    FETCH(fat16_disk_sectorsPerCluster, 1)
    ON_ERROR(zos_fat16_on_error)

    FETCH(fat16_disk_reservedSectors, 2)
    ON_ERROR(zos_fat16_on_error)

    FETCH(fat16_disk_numberOfFat, 1)
    ON_ERROR(zos_fat16_on_error)

    ld a, (fat16_disk_fd)
    ld h, a
    ld bc, 0 ; skip over numberOfRoot, smallSectors, mediaDescriptor
    ld de, 5
    ld a, SEEK_CUR
    ; SEEK() ; TODO: figure out how to seek in the FS driver :)
    ON_ERROR(zos_fat16_on_error)


    FETCH(fat16_disk_sectorsPerFat, 2)
    ON_ERROR(zos_fat16_on_error)

    ; disk->rootSector = reservedSectors + (numberOfFat * sectorsPerFat);
    ; (numberOfFat * sectorsPerFat)
    ld d, 0
    ld a, (fat16_disk_numberOfFat)
    ld e, a
    ld bc, (fat16_disk_sectorsPerFat)
    call _mul16

    ld bc, (fat16_disk_reservedSectors)
    add hl, bc
    ld (fat16_disk_rootSector), hl
    jr nc, @_nocarry
    inc de ; carry over into high bytes
@_nocarry:
    ld (fat16_disk_rootSector+2), de

    ; disk->bytesPerCluster = disk->sectorsPerCluster * disk->bytesPerSector;
    ld bc, (fat16_disk_bytesPerSector)
    ld d, 0
    ld a, (fat16_disk_sectorsPerCluster)
    ld e, a
    call _mul16

    ld (fat16_disk_bytesPerCluster), hl
    ld (fat16_disk_bytesPerCluster+2), de

    ret
;

    ; Seek to location on disk
        ; Returns:
        ;       BCDE - cluster
        ; Alters:
        ;       ????
_seek:
    ld a, (fat16_disk_fd) ; disk dev
    ld h, a
    ld a, SEEK_SET
    ; SEEK() ; TODO: figure out how to seek in the FS driver :)
    ret
;

    ; Get the sector address
        ; Parameters
        ;       HL - cluster
        ; Returns:
        ;       BCDE - address
        ; Alters:
        ;       ????
_get_sector_address:
    ; uint32_t addr = cluster;
    ; HL

    ; addr -= 2;
    ld de, 2
    CLEAR_CARRY
    sbc hl, de ; HL = cluster - 2
    ex de, hl  ; DE = cluster, HL = cluster

    ; addr *= disk->sectorsPerCluster;
    ; DE = cluster
    ld b, 0
    ld a, (fat16_disk_sectorsPerCluster)
    ld c, a ; BC = sectorsPerCluster
    call _mul16 ; DEHL
    ; addr = DEHL

    ; addr += disk->rootSector;
    ;; copy rootSector into sector_address
    ld bc, (fat16_disk_rootSector)
    ld (fat16_file_sector_address), bc
    ld bc, (fat16_disk_rootSector+2)
    ld (fat16_file_sector_address+2), bc
    ; fat16_file_sector_address = fat16_disk_rootSector

    ;; add addr to rootSector
    ld de, (fat16_file_sector_address)
    add hl, de
    ld (fat16_file_sector_address), hl

    ld hl, bc
    ld de, (fat16_file_sector_address + 2)
    adc hl, de
    ld (fat16_file_sector_address + 2), hl

    ; addr += 32;
    ld h, 0
    ld l, 32
    ld de, (fat16_file_sector_address)
    add hl, de
    ld (fat16_file_sector_address), hl

    ld hl, (fat16_file_sector_address + 2)
    ld de, 0
    adc hl, de
    ld (fat16_file_sector_address + 2), hl

    ; addr *= disk->bytesPerSector;
    ; _mul16 fat16_file_sector_address * fat16_disk_bytesPerSector
    ld bc, (fat16_disk_bytesPerSector)
    ld hl, (fat16_file_sector_address) ; in HL already?
    ld de, (fat16_file_sector_address+2) ; in HL already?
    call _mul16x32 ; BC * DEHL


    ; store the 32-bit addr
    ld (fat16_file_sector_address), hl
    ld (fat16_file_sector_address+2), de


    ; return addr;
    ld de, (fat16_file_sector_address)
    ld bc, (fat16_file_sector_address+2)
    ; print the sector address
    ; call hexPrint8 ; BCDE
    ; S_WRITE3(DEV_STDOUT, _msg_address, _msg_address_end - _msg_address)
    ; S_WRITE3(DEV_STDOUT, hex_buffer, 9)

    ret
;

    ; Get root address
        ; Returns
        ;       BCDE - address
        ; Alters:
        ;       ????
_get_root_address:
    ; uint32_t addr = disk->rootSector * disk->bytesPerSector;
    ld bc, (fat16_disk_rootSector)
    ld de, (fat16_disk_bytesPerSector)
    call _mul16
    ; swap things around, _seek wants BCDE

    ; return addr;
    ld bc, de
    ld de, hl

    ret
;

    ; Multiply two 16-bit values, resulting in 32-bit
        ; Parameters:
        ;       BC - first number
        ;       DE - second number
        ; Returns:
        ;       DEHL - BC*DE
        ; Alters:
        ;       A, BC, DE, HL
_mul16:
    ld hl, 0
    ld a, 16
@_loop:
    add hl, hl
    rl e
    rl d
    jp nc, @_next
    add hl, bc
    jp nc, @_next
    inc de
@_next:
    dec a
    jp nz, @_loop
    ret
;

    ; Multiply a 32-bit value with a 16-bit, resulting in 32-bits
        ; Parameters:
        ;       BC - 16-bit value
        ;       DEHL - 32-bit balue
        ; Returns:
        ;       DEHL - BC*DEHL
        ; Alters:
        ;       A, BC, DE, HL
_mul16x32:
    push hl
    push bc
    ; Multiply DE with BC first
    call _mul16
    pop bc
    ; Get former HL in DE. We can alter DE since we only need to keep HL
    pop de
    ; Keep current result (HL) on the stack
    push hl
    call _mul16
    ; Result in DEHL again, add DE and former DE
    pop bc
    ex de, hl
    add hl, bc
    ex de, hl
    ret
;

    ; This routine gets the `read` function of a driver and stores it in the RAM_EXE_READ buffer.
    ; It will in fact store a small routine that does:
    ;       xor a   ; Set A to "FS" mode, i.e., has offset on stack
    ;       push hl
    ;       ld h, a
    ;       ld l, a ; Set HL to 0
    ;       push hl
    ;       jp driver_read_function
    ; As such, HL is the 16-bit offset to read from the driver, can this routine can be called
    ; with `call RAM_EXE_READ`, no need to manually push the return address on the stack.
    ; Parameters:
    ;   DE - Driver address
    ; Returns:
    ;   HL - Address of read function
    ; Alters:
    ;   A, DE, HL
zos_fat16_prepare_driver_read:
    ld hl, PUSH_HL << 8 | XOR_A
    ld (RAM_EXE_READ + 0), hl
    ld hl, LD_L_A << 8 | LD_H_A
    ld (RAM_EXE_READ + 2), hl
    ld hl, JP_NNNN << 8 | PUSH_HL
    ld (RAM_EXE_READ + 4), hl
    ; Retrieve driver (DE) read function address, in HL.
    GET_DRIVER_READ_FROM_DE()
    ld (RAM_EXE_READ + 6), hl
    ret


    ; Same as above, but with write routine
zos_fat16_prepare_driver_write:
    ld hl, PUSH_HL << 8 | XOR_A
    ld (RAM_EXE_WRITE + 0), hl
    ld hl, LD_L_A << 8 | LD_H_A
    ld (RAM_EXE_WRITE + 2), hl
    ld hl, JP_NNNN << 8 | PUSH_HL
    ld (RAM_EXE_WRITE + 4), hl
    ; Retrieve driver (DE) read function address, in HL.
    GET_DRIVER_WRITE_FROM_DE()
    ld (RAM_EXE_WRITE + 6), hl
    ret

    ; Same as above but safe
zos_fat16_prepare_driver_write_safe:
    push hl
    push de
    call zos_fat16_prepare_driver_write
    pop de
    pop hl
    ret




;;; STRINGS
_unsupported_open: DEFM "FAT16: open unsupported\n", 0
_unsupported_stat: DEFM "FAT16: stat unsupported\n", 0
_unsupported_read: DEFM "FAT16: read unsupported\n", 0
_unsupported_write: DEFM "FAT16: write unsupported\n", 0
_unsupported_close: DEFM "FAT16: close unsupported\n", 0
_unsupported_opendir: DEFM "FAT16: opendir unsupported\n", 0
_unsupported_opendir_root: DEFM "FAT16: opendir:root unsupported\n", 0
_unsupported_readdir: DEFM "FAT16: readdir unsupported\n", 0
_unsupported_mkdir: DEFM "FAT16: mkdir unsupported\n", 0
_unsupported_rm: DEFM "FAT16: rm unsupported\n", 0
