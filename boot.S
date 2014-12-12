/*
 * boot.S - simple register setup code for stand-alone Linux booting
 *
 * Copyright (C) 2011 ARM Limited. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE.txt file.
 */

	.syntax	unified
	.arch_extension sec
	.arch_extension virt
	.text

	.globl	_start
_start:
#if 0
	ldr	r0, =kernel_entry
	ldr	r0, [r0]
	bx	r0				@ jump to the kernel
#endif

	ldr	sp, =stack

	@
	@ Program architected timer frequency
	@
	mrc	p15, 0, r0, c0, c1, 1		@ CPUID_EXT_PFR1
	lsr	r0, r0, #16
	and	r0, r0, #1			@ Check generic timer support
	beq	1f
	ldr	r0, =50000000			@ 50MHz timer frequency
	mcr	p15, 0, r0, c14, c0, 0		@ CNTFRQ
1:
	@
	@ CPU initialisation
	@
	mrc	p15, 0, r4, c0, c0, 5		@ MPIDR (ARMv7 only)
	and	r4, r4, #15			@ CPU number

	@ TZPC registers (What's this?)
	LDR     r0, =0xe3b00804
	LDR     r1, [r0]
   	LDR     r2, =0x00FFFFFF
	ORR     r1, r1, r2
	STR     r1, [r0]

	@
	@ Hypervisor / TrustZone initialization
	@

	@ Set all interrupts to be non-secure
	ldr	r0, =0xe0c01000			@ Dist GIC base
	ldr	r1, [r0, #0x04]			@ Type Register
	cmp	r4, #0
	andeq	r1, r1, #0x1f
	movne	r1, #0
	add	r2, r0, #0x080			@ Security Register 0
	mvn 	r3, #0
2:	str	r3, [r2]
	sub	r1, r1, #1
	add	r2, r2, #4			@ Next security register
	cmp	r1, #-1
	bne	2b


	@ Set GIC priority mask bit [7] = 1
	ldr	r0, =0xe0c02000			@ CPU GIC base
	mov	r1, #0x80
	str	r1, [r0, #0x4]			@ GIC ICCPMR
	mov r1, #0x3
	str	r1, [r0]			@ GIC ctlr

	@ Set NSACR to allow coprocessor access from non-secure
	mrc	p15, 0, r0, c1, c1, 2
	ldr	r1, =0x43fff
	orr	r0, r0, r1
	mcr	p15, 0, r0, c1, c1, 2
    
	@ Change to NS-mode
	ldr	r0, =monitor_start
	mcr	p15, 0, r0, c12, c0, 1		@ Monitor vector base address
	isb
	
	smc	#0				@ Change to NS-mode, set HVBAR
	hvc	#0				@ Enter HYP mode

	@ Check CPU nr again
	mrc	p15, 0, r0, c0, c0, 5		@ MPIDR (ARMv7 only)
	bfc	r0, #24, #8			@ CPU number, taking multicluster into account
	cmp	r0, #0				@ primary CPU?
	beq	2f

	@
	@ Secondary CPUs (following the RealView SMP booting protocol)
	@

	ldr	r0, =0xe0000108			@ P650 SRAM addr,for smp

1:
    	ldr	r1, [r0]
	cmp	r1, #0
	beq	1b

 	mov	pc, r1				@ branch to the given address

2:

run_kernel:
	@
	@ Get Kernel cmdline from UEFI
	@
	ldr	r0, =efi_cmd
	ldr	r1, =0xf1200060	@ cmdline addr at norflash
	mov	r2, #0x100
loop:
	ldr	r3, [r1], #4
	str	r3, [r0], #4
	subs	r2, r2,	#4
	bne	loop

	@
	@ Kernel parameters
	@
	ldr	r0, =kernel_entry
	ldr	lr, [r0]
	mov	r0, #0
	@ldr	r1, =2272			@ P650 ID (not clear)
	ldr	r2, =atags
	bx	lr				@ jump to the kernel


	.global	d_hex8
d_hex8:
	@ hex number should be stored in r1
	push	{r0, r1, r2, r6, r7, lr}
	mov	r6, #8
	mov	r7, #0
5:
	mov	r3, r1, lsr #28
	subs	r2, r3, #0xa
	addmi	r3, r3, #0x30
	addpl	r3, r3, #0x57
	subs	r6, r6, #1
	strb	r3, [r0, r7]
	add	r7, r7, #1
	mov	r1, r1, lsl #4
	bne	5b
	bl	d_print
	pop	{r0, r1, r2, r6, r7, pc}

  .globl d_print
d_print:
        push  	{r0-r3}
        mov   	r3, #0xe4000000
        orr     r3, r3, #0x7000
        b  	mouse
cat:
        strb    r1, [r3]
dog:
        ldrb    r2, [r3, #20]
        and 	r2, r2, #96
        teq 	r2, #96
        bne  	dog
        teq 	r1, #10
        moveq   r1, #13
        beq   	cat
mouse:
        teq 	r0, #0
        ldrbne  r1, [r0], #1
        teqne   r1, #0
        bne   	cat
        POP     {r0-r3}
        mov     pc, lr
	
	@
	@ Data
	@

	.org	0x500
	@ Static ATAGS for when kernel/etc are compiled into the ELF file
atags:
	@ ATAG_CORE
	.long	2
	.long	0x54410001

	@ ATAG_CMDLINE
	.long	(1f - .) >> 2
	.long	0x54410009
        /* Get kernel boot command line from UEFI*/
efi_cmd:
	.space	0x100
	.align	2
1:

	@ ATAG_NONE
	.long	0
	.long	0x00000000

output0:
    .long  0
    .long  0
    .long  0
    .long  0
    .long  0
    .long  0
    .long  0
    .long  0
    .long  0
    #.asciz "00000000\n"
output1:
	.asciz "one\n"
output2:
	.asciz "two\n"
output3:
	.asciz "three\n"
.align 11
kernel_entry:
    /* Gets written by the parent EFI blob */
    .long 0
.align 12
stack:
    .long 0
