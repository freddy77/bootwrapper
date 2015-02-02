/*
 * monitor.S - simple monitor code to switch to NS state before executing kernel
 *
 * Copyright (C) 2011 Columbia University. All rights reserved.
 * 		      Christoffer Dall <cdall@cs.columbia.edu>
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE.txt file.
 */

	.syntax	unified
    	.arch_extension sec	
    	.arch_extension virt

	.text

.macro print, str
#ifdef DEBUG
	adr	r0, str_\@
	adr	lr, end_print_\@
	b	d_print_2
str_\@:
	.asciz "\str"
	.align 2
end_print_\@:
#endif
.endm


_start:
	.set	stack, _start + 0x8000
	.set	text_start, _start - 0x8000

	b	.
	b	.
	b	monitor_init
	b	.
	b	.
	b	.
	b	.
	b	.

	.align 5
#if 0
vect_hyp:
	nop
	nop
	nop
	nop
	nop
	b	set_hvbar
	nop
	nop
#else
vect_hyp:
	b   set_hvbar
	b   set_hvbar
	b   set_hvbar
	b   set_hvbar
	b   set_hvbar
	b   set_hvbar
	b   set_hvbar
	b   set_hvbar
#endif
set_hvbar:
	@ Check if called from SVC
	mrs	r12, spsr
	and	r12, r12, 0x1f
	cmp	r12, 0x13
	bne	1f

	@ SVC, copy SP and LR from SVC mode before returning
	mrs	sp, SP_svc
	mrs	lr, LR_svc
	mrs	r12, cpsr
	orr	r12, r12, #0x1c0	@ Set A, I and F.
	msr	spsr_cxsf, r12

	@ If we got the entry from PSCI use these information
	@ r0 == context, r1 == entry
	cmp	r1, #0
	msrne	ELR_hyp, r1
1:
	eret

	@
	@ Secure Monitor Call
	@
monitor_init:
	@ Set a stack different for every processor
	adrl	sp, stack
	mrc	p15, 0, r0, c0, c0, 5		@ MPIDR (ARMv7 only)
	bfi	r0, r0, 10, 2
	and	r0, r0, 0xf00
	sub	sp, sp, r0

	@ Write new monitor
	adr	r0, monitor_final
	mcr	p15, 0, r0, c12, c0, 1		@ Monitor vector base address
	isb

	push	{r2,r3,r12,lr}

	@
	@ Switch to non-secure mode
	@
	mrc	p15, 0, r12, c1, c1, 0		@ Secure configuration register
	bic	r12, r12, #0x07f
	orr	r12, r12, #0x130
	orr	r12, r12, #0x1
	mcr	p15, 0, r12, c1, c1, 0
   
#ifdef DEBUG
	bl	dump_regs
#endif

    	@
	@ Write HVBAR
	@
	adr	r0, vect_hyp
	mcr	p15, 4, r0, c12, c0, 0

	@ Clear HSCTLR
	ldr	r0, =#0x30c50878
	mcr	p15, 4, r0, c1, c0, 0		@ HSCTLR

	@ Invalidate the old TLBs
	isb
	mcr	p15, 4, r0, c8, c7, 0	@ TLBIALLH
	dsb	ish

	@ Load context and entry for this cpu
	@ on exit r0 == context, r1 == entry
	bl	hip04_cpu_starting

	pop	{r2,r3,r12,lr}
	movs	pc, lr

	.align 5
monitor_final:
	b	.
	b	.
	b	monitor_psci
	b	.
	b	.
	b	.
	b	.
	b	.

monitor_psci:
	@ Push lr to restore
	@ Push ip as C routines corrupt but we must save it (SMC ABI)
	@ Do not save extra arguments (r4-r6) as we don't need them currently
	push	{ip,lr}
	bl	psci
	pop	{ip,lr}
	eret

	.global get_text_start
get_text_start:
	adrl	r0, text_start
	bx	lr
	.ltorg

#ifdef DEBUG
	@ Print r0 character to serial, destroy r0
	.global serial_out
serial_out:
	push	{r1,lr}
	mov     r1, #0xe4000000
	orr     r1, r1, #0x7000
	strb    r0, [r1]
1:
	ldrb    r0, [r1, #20]
	and     r0, r0, #96
	teq     r0, #96
	bne     1b
	pop	{r1,pc}

	@ Call xprintf but safe/restore all registers
	.globl d_print_2
d_print_2:
	push    {r0-r3,ip,lr}
	bl	xprintf
	pop    {r0-r3,ip,pc}

dump_reg:
	adr	r0, dump_reg_str
	b	d_print_2

dump_reg_str:
	.asciz	"%s %x\n"
	.align 2

dump_regs:

.macro dump_reg a, b, c, d, name
	mrc	p15, \b, r2, c\a, c\c, \d
	adr	r1, str_\@
	adr	lr, end_print_\@
	b	dump_reg
str_\@:
	.asciz "\name"
	.align 2
end_print_\@:
.endm

	push	{lr}

	dump_reg	0, 0,0,0, MIDR
	dump_reg	0, 0,0,1, CTR
	dump_reg	0, 0,0,2, TCMTR
	dump_reg	0, 0,0,3, TLBTR
	dump_reg	0, 0,0,4, MIDR
	dump_reg	0, 0,0,5, MPIDR
	dump_reg	0, 0,0,6, REVIDR
	dump_reg	0, 0,1,0, ID_PFR0
	dump_reg	0, 0,1,1, ID_PFR1
	dump_reg	0, 0,1,2, ID_DFR0
	dump_reg	0, 0,1,3, ID_AFR0
	dump_reg	0, 0,1,4, ID_MMFR0
	dump_reg	0, 0,1,5, ID_MMFR1
	dump_reg	0, 0,1,6, ID_MMFR2
	dump_reg	0, 0,1,7, ID_MMFR3
	dump_reg	0, 0,2,0, ID_ISAR0
	dump_reg	0, 0,2,1, ID_ISAR1
	dump_reg	0, 0,2,2, ID_ISAR2
	dump_reg	0, 0,2,3, ID_ISAR3
	dump_reg	0, 0,2,4, ID_ISAR4
	dump_reg	0, 0,2,5, ID_ISAR5
	dump_reg	0, 1,0,0, CCSIDR
	dump_reg	0, 1,0,1, CLIDR
	dump_reg	0, 1,0,7, AIDR
	dump_reg	0, 2,0,0, CSSELR
	dump_reg	0, 4,0,0, VPIDR
	dump_reg	0, 4,0,5, VMPIDR

	dump_reg	1, 0,0,0, SCTLR
	dump_reg	1, 0,0,1, ACTLR
	dump_reg	1, 0,0,2, CPACR
	dump_reg	1, 0,1,0, SCR
	dump_reg	1, 0,1,1, SDER
	dump_reg	1, 0,1,2, NSACR
	dump_reg	1, 4,0,0, HSCTLR
	dump_reg	1, 4,0,1, HACTLR
	dump_reg	1, 4,1,0, HCR
	dump_reg	1, 4,1,1, HDCR
	dump_reg	1, 4,1,2, HCPTR
	dump_reg	1, 4,1,3, HSTR
	dump_reg	1, 4,1,7, HACR

	dump_reg	2, 0,0,0, TTBR0
	dump_reg	2, 0,0,1, TTBR1
	dump_reg	2, 0,0,2, TTBCR
	dump_reg	2, 4,0,2, HTCR
	dump_reg	2, 4,1,2, VTCR

	dump_reg	3, 0,0,0, DACR

	dump_reg	5, 0,0,0, DFSR
	dump_reg	5, 0,0,1, IFSR
	dump_reg	5, 0,1,0, ADFSR
	dump_reg	5, 0,1,1, AIFSR
	dump_reg	5, 4,1,0, HADFSR
	dump_reg	5, 4,1,1, HAIFSR
	dump_reg	5, 4,2,0, HSR

	dump_reg	6, 0,0,0, DFAR
	dump_reg	6, 0,0,2, IFAR
	dump_reg	6, 4,0,0, HDFAR
	dump_reg	6, 4,0,2, HIFAR
	dump_reg	6, 4,0,4, HPFAR

#if 0
	dump_reg	7, 0,0,4, NOP
	dump_reg	7, 0,1,0, ICIALLUIS
	dump_reg	7, 0,1,6, BPIALLIS
	dump_reg	7, 0,4,0, PAR
	dump_reg	7, 0,5,0, ICIALLU
	dump_reg	7, 0,5,1, ICIMVAU
	dump_reg	7, 0,5,4, CP15ISB
	dump_reg	7, 0,5,6, BPIALL
	dump_reg	7, 0,5,7, BPIMVA
	dump_reg	7, 0,6,1, DCIMVAC
	dump_reg	7, 0,6,2, DCISW
	dump_reg	7, 0,8,0, ATS1CPR
	dump_reg	7, 0,8,1, ATS1CPW
	dump_reg	7, 0,8,2, ATS1CUR
	dump_reg	7, 0,8,3, ATS1CUW
	dump_reg	7, 0,8,4, ATS12NSOPR
	dump_reg	7, 0,8,5, ATS12NSOPW
	dump_reg	7, 0,8,6, ATS12NSOUR
	dump_reg	7, 0,8,7, ATS12NSOUW
	dump_reg	7, 0,10,1, DCCMVAC
	dump_reg	7, 0,10,2, DCCSW
	dump_reg	7, 0,10,4, CP15DSB
	dump_reg	7, 0,10,5, CP15DMB
	dump_reg	7, 0,11,1, DCCMVAU
	dump_reg	7, 0,13,1, NOP
	dump_reg	7, 0,14,1, DCCIMVAC
	dump_reg	7, 0,14,2, DCCISW
	dump_reg	7, 4,8,0, ATS1HR
	dump_reg	7, 4,8,1, ATS1HW
#endif

	dump_reg	9, 1,0,2, L2CTLR
	dump_reg	9, 1,0,3, L2ECTLR

	dump_reg	10, 0,2,0, MAIR0
	dump_reg	10, 0,2,1, MAIR1
	dump_reg	10, 0,3,0, AMAIR0
	dump_reg	10, 0,3,1, AMAIR1
	dump_reg	10, 4,2,0, HMAIR0
	dump_reg	10, 4,2,1, HMAIR1
	dump_reg	10, 4,3,0, HAMAIR0
	dump_reg	10, 4,3,1, HAMAIR1

	dump_reg	12, 0,0,0, VBAR
	dump_reg	12, 0,0,1, MVBAR
	dump_reg	12, 0,1,0, ISR
	dump_reg	12, 4,0,0, HVBAR

	dump_reg	13, 0,0,0, FCSEIDR
	dump_reg	13, 0,0,1, CONTEXTIDR
	dump_reg	13, 0,0,2, TPIDRURW
	dump_reg	13, 0,0,3, TPIDRURO
	dump_reg	13, 0,0,4, TPIDRPRW
	dump_reg	13, 4,0,2, HTPIDR

	pop	{pc}
#endif

	.align 2
	.ltorg

