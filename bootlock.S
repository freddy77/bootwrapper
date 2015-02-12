/*
 * bootlock.S - Implement simple locks
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE.txt file.
 */

	.syntax	unified

	.text

	.global	boot_lock
boot_lock:
	adr	r0, boot_lock_data
	mov	r2, #1
1:
	ldrex	r1, [r0]
	cmp	r1, #0
	strexeq	r1, r2, [r0]
	cmpeq	r1, #0
	bne	1b
	dmb	ish
	bx	lr

	.global	boot_unlock
boot_unlock:
	dmb	ish
	adr	r0, boot_lock_data
	mov	r2, #0
	str	r2, [r0]
	dsb	ishst
	bx	lr

boot_lock_data:
	.long	0

