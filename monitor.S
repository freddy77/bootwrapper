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

_start:
	.set	stack, _start + 0x8000
	.set	text_start, _start - 0x8000

	.word 0
	.word 0
	b	1f
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0

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
#if 0
    	ldr     r0, =output5
    	bl  d_print_2
#endif
	mrs	r12, cpsr
	orr	r12, r12, #0x1c0	@ Set A, I and F.
	msr	spsr_cxsf, r12
	eret

	@
	@ Secure Monitor Call
	@
1:
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

	push	{r11, r12}

	@
	@ Switch to non-secure mode
	@
	mrc	p15, 0, r12, c1, c1, 0		@ Secure configuration register
	bic	r12, r12, #0x07f
	orr	r12, r12, #0x130
	orr	r12, r12, #0x1
	mcr	p15, 0, r12, c1, c1, 0
   
    	@
	@ Write HVBAR
	@
	adr	r11, vect_hyp
	mcr	p15, 4, r11, c12, c0, 0
	pop	{r11, r12}
	movs	pc, lr

	.align 5
monitor_final:
	.word 0
	.word 0
	b	monitor_psci
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0

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

output1:
	.asciz "1\n"
output2:
	.asciz "2\n"
output3:
	.asciz "3\n"
output4:
	.asciz "4\n"
output5:
	.asciz "5\n"
output6:
	.asciz "6\n"
#endif

	.align 2
	.ltorg

