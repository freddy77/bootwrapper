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
	.section monitor, "x"

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
    	ldr	sp, =_monitor_stack
	push	{r11, r12}

	@
	@ Switch to non-secure mode
	@
	mrc	p15, 0, r12, c1, c1, 0		@ Secure configuration register
	bic	r12, r12, #0x07f
	ldr	r11, =0x131
	orr	r12, r12, r11
	mcr	p15, 0, r12, c1, c1, 0
   
    	@
	@ Read/Write HVBAR
	@
	ldr	r11, =vect_hyp
	mcr	p15, 4, r11, c12, c0, 0
	pop	{r11, r12}
	movs	pc, lr

	.globl d_print
d_print_2:
	push    {r0-r3}
	mov     r3, #0xe4000000
	orr     r3, r3, #0x7000
	b   mouse
cat:
	strb    r1, [r3]
dog:
	ldrb    r2, [r3, #20]
	and     r2, r2, #96	
	teq     r2, #96
	bne     dog
	teq     r1, #10
	moveq   r1, #13
	beq     cat
mouse:
	teq     r0, #0
	ldrbne  r1, [r0], #1
	teqne   r1, #0
	bne     cat
	pop     {r0-r3}
	mov     pc, lr

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

	.ltorg

	/* A bit of stack space for monitor mode */
	.align	12
_monitor_stack:
	.long 0
