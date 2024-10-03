; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "osconfig.asm"

    IFNDEF FAT16FS_H
    DEFINE FAT16FS_H

    IF CONFIG_KERNEL_ENABLE_FAT16_SUPPORT

    ; Public routines. The descriptions are given in the implementation file.
    EXTERN zos_fat16_open
    EXTERN zos_fat16_stat
    EXTERN zos_fat16_read
    EXTERN zos_fat16_write
    EXTERN zos_fat16_close
    EXTERN zos_fat16_opendir
    EXTERN zos_fat16_readdir
    EXTERN zos_fat16_mkdir
    EXTERN zos_fat16_rm

    DEFC zos_fs_fat16_open    = zos_fat16_open
    DEFC zos_fs_fat16_read    = zos_fat16_read
    DEFC zos_fs_fat16_write   = zos_fat16_write
    DEFC zos_fs_fat16_stat    = zos_fat16_stat
    DEFC zos_fs_fat16_opendir = zos_fat16_opendir
    DEFC zos_fs_fat16_readdir = zos_fat16_readdir
    DEFC zos_fs_fat16_close   = zos_fat16_close
    DEFC zos_fs_fat16_mkdir   = zos_fat16_mkdir
    DEFC zos_fs_fat16_rm      = zos_fat16_rm

    ELSE ; !CONFIG_KERNEL_ENABLE_fat16_SUPPORT

    DEFC zos_fs_fat16_open    = zos_disk_fs_not_supported
    DEFC zos_fs_fat16_read    = zos_disk_fs_not_supported
    DEFC zos_fs_fat16_write   = zos_disk_fs_not_supported
    DEFC zos_fs_fat16_stat    = zos_disk_fs_not_supported
    DEFC zos_fs_fat16_opendir = zos_disk_fs_not_supported
    DEFC zos_fs_fat16_readdir = zos_disk_fs_not_supported
    DEFC zos_fs_fat16_close   = zos_disk_fs_not_supported
    DEFC zos_fs_fat16_mkdir   = zos_disk_fs_not_supported
    DEFC zos_fs_fat16_rm      = zos_disk_fs_not_supported

    ENDIF ; CONFIG_KERNEL_ENABLE_FAT16_SUPPORT


    ENDIF ; FAT16_H
