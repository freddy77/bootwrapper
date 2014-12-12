# Makefile - build a kernel+filesystem image for stand-alone Linux booting
#
# Copyright (C) 2011 ARM Limited. All rights reserved.
#
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE.txt file.


# Include config file (prefer config.mk, fall back to config-default.mk)
MONITOR		= monitor.S
BOOTLOADER	= boot.S

IMAGE		= linux-system.axf
LD_SCRIPT	= model.lds.S


CC		= $(CROSS_COMPILE)gcc
LD		= $(CROSS_COMPILE)ld
CPPFLAGS	+= -march=armv7-a

# These are needed by the underlying kernel make
export CROSS_COMPILE ARCH

all: $(IMAGE)

clean:
	rm -f $(IMAGE) boot.o model.lds monitor.o $(SEMIIMG)

$(IMAGE): boot.o monitor.o model.lds Makefile
	$(LD) -o $@ --script=model.lds
	./objcopy-sh

boot.o: $(BOOTLOADER)
	$(CC) $(CPPFLAGS) -DKCMD='$(KCMD)' -c -o $@ $<

monitor.o: $(MONITOR)
	$(CC) $(CPPFLAGS) -c -o $@ $<

model.lds: $(LD_SCRIPT) Makefile
	$(CC) $(CPPFLAGS) -E -P -C -o $@ $<

# Pass any target we don't know about through to the kernel makefile.
# This is a convenience rule so we can say 'make menuconfig' etc here.
%: force
	$(MAKE) -C @

force: ;

Makefile: ;

.PHONY: all clean config.mk config-default.mk
