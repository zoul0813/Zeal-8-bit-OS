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


_not_compatible: DEFM "CompactFlash: unsupported\n", 0

    DEFC FILENAME_LEN           = 8
    DEFC EXTENSION_LEN          = 3
    DEFC MAX_BUFFER_SIZE        = 32768

    ; File Attributes
    DEFC FILE_ATTR_READONLY     = 0x01
    DEFC FILE_ATTR_HIDDEN       = 0x02
    DEFC FILE_ATTR_SYSTEM       = 0x04
    DEFC FILE_ATTR_VOLUME       = 0x08
    DEFC FILE_ATTR_DIRECTORY    = 0x10
    DEFC FILE_ATTR_ARCHIVE      = 0x20

    ; FAT16 Boot Sector
    DEFVARS 0 {
        fat16_bootstrapJump             DS.B 3      ; 0000h Code to jump to the bootstrap code.
        fat16_oemId                     DS.B 8      ; 0003h Oem ID 1 - Name of the formatting OS
        fat16_bytesPerSector            DS.B 2      ; 000Bh Bytes per Sector
        fat16_sectorsPerCluster         DS.B 1      ; 000Dh Sectors per Cluster - Usual there is 512 bytes per sector.
        fat16_reservedSectors           DS.B 2      ; 000Eh Reserved sectors from the start of the volume.
        fat16_numberOfFat               DS.B 1      ; 0010h Number of FAT copies - Usual 2 copies are used to prevent data loss.
        fat16_numberOfRoot              DS.B 2      ; 0011h Number of possible root entries - 512 entries are recommended.
        fat16_smallSectors              DS.B 2      ; 0013h Small number of sectors - Used when volume size is less than 32 Mb.
        fat16_mediaDescriptor           DS.B 1      ; 0015h Media Descriptor
        fat16_sectorsPerFat             DS.B 2      ; 0016h Sectors per FAT
        fat16_sectorsPerTrack           DS.B 2      ; 0018h Sectors per Track
        fat16_numberOfHeads             DS.B 2      ; 001Ah Number of Heads
        fat16_hiddenSectors             DS.B 4      ; 001Ch Hidden Sectors
        fat16_largeSectors              DS.B 4      ; 0020h Large number of sectors - Used when volume size is greater than 32 Mb.
        fat16_driveNumber               DS.B 1      ; 0024h Drive Number - Used by some bootstrap code, fx. MS-DOS.
        fat16_reserved                  DS.B 1      ; 0025h Reserved - Is used by Windows NT to decide if it shall check disk integrity.
        fat16_extendedBootSignature     DS.B 1      ; 0026h Extended Boot Signature - Indicates that the next three fields are available.
        fat16_volumeSerial              DS.B 4      ; 0027h Volume Serial Number
        fat16_volumeLabel               DS.B 11     ; 002Bh Volume Label - Should be the same as in the root directory.
        fat16_fsType                    DS.B 8      ; 0036h File System Type - The string should be 'FAT16 '
        fat16_bootstrapCode             DS.B 448    ; 003Eh Bootstrap code - May schrink in the future.
        fat16_bootSectorSignature       DS.B 2      ; 01FEh Boot sector signature - This is the AA55h signature.
        fat16_bootSector_end            DS.B 0      ; end of bootSector
    }

    DEFC FAT16_BOOTSECTOR_SIZE = fat16_bootSector_end
    ASSERT(FAT16_BOOTSECTOR_SIZE == 512)

    DEFVARS 0 {
        fat16_disk_rootSector                DS.Q 1      ; root sector
        fat16_disk_sectorsPerCluster         DS.Q 1      ; sectors per cluster
        fat16_disk_bytesPerSector            DS.Q 1      ; bytes per sector
        fat16_disk_bytesPerCluster           DS.Q 1      ; bytes per cluster
        fat16_disk_end                       DS.B 0      ; end of disk
    }

    DEFC FAT16_DISK_SIZE = fat16_disk_end
    ASSERT(FAT16_DISK_SIZE == 16)

    ; FAT16 DirectoryEntry
    DEFVARS 0 {
        fat16_entry_filename            DS.B FILENAME_LEN       ; 00h Filename
        fat16_entry_extension           DS.B EXTENSION_LEN      ; 08h Filename Extension
        fat16_entry_attributes          DS.B 1                  ; 0Bh Attribute Byte
        fat16_entry_reserved            DS.B 1                  ; 0Ch Reserved for Windows NT
        fat16_entry_createdMs           DS.B 1                  ; 0Dh Creation - Millisecond stamp (actual 100th of a second)
        fat16_entry_createdTime         DS.B 2                  ; 0Eh Creation Time
        fat16_entry_createdDate         DS.B 2                  ; 10h Creation Date
        fat16_entry_lastAccessDate      DS.B 2                  ; 12h Last Access Date
        fat16_entry_reserved2           DS.B 2                  ; 14h Reserved for FAT32
        fat16_entry_lastWriteTime       DS.B 2                  ; 16h Last Write Time
        fat16_entry_lasrtWriteDate      DS.B 2                  ; 18h Last Write Date
        fat16_entry_startingCluster     DS.B 2                  ; 1Ah Starting cluster
        fat16_entry_filesize            DS.B 4                  ; 1Ch File size in bytes
        fat16_dirEntry_end              DS.B 0                  ; end of directory entry
    }

    DEFC FAT16_DIRENTRY_SIZE = fat16_dirEntry_end
    ASSERT(FAT16_DIRENTRY_SIZE == 32)

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
    ld a, ERR_NOT_IMPLEMENTED
    ret


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
    ld a, ERR_NOT_IMPLEMENTED
    ret


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
    ld a, ERR_NOT_IMPLEMENTED
    ret


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
    ld a, ERR_NOT_IMPLEMENTED
    ret


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
    ld a, ERR_NOT_IMPLEMENTED
    ret

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
    ; Treat / as a special case
    inc hl
    ld a, (hl)
    or a
    jr z, _zos_fat16_opendir_root


    ld hl, _not_compatible
    call zos_log_info
    ld a, ERR_NOT_IMPLEMENTED
    ret
_zos_fat16_opendir_root:
    ld hl, _not_compatible
    call zos_log_warning
    ld a, ERR_NOT_IMPLEMENTED
    ret

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
    ld a, ERR_NOT_IMPLEMENTED
    ret


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
    ld a, ERR_NOT_IMPLEMENTED
    ret


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
    ld a, ERR_NOT_IMPLEMENTED
    ret


zos_fat16_driver_end:

; Private

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