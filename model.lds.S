/*
 * model.lds.S - simple linker script for stand-alone Linux booting
 *
 * Copyright (C) 2011 ARM Limited. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE.txt file.
 */

OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
TARGET(binary)

PHYS_OFFSET = 0xe0100000 - 0x10000; /* upper end of SRAM */


SECTIONS
{

 /DISCARD/ : { *(.ARM.attributes .note .comment) }

 . = PHYS_OFFSET;

 .text : { boot.o; . = ALIGN(0x1000); } = 0

 . = PHYS_OFFSET + 0x8000;
 monitor_start = .;
 .monitor : { monitor.o bootlock.o psci.o; . = ALIGN(0x1000); } = 0

 .data : { *(.data) }
 .bss : { *(.bss) }

}
