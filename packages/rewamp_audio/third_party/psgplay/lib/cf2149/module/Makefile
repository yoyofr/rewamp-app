# SPDX-License-Identifier: GPL-2.0

cf2149_module_dir := $(dir $(lastword $(MAKEFILE_LIST)))

CF2149_SRC := $(cf2149_module_dir)cf2149.c

ifeq (module/,$(cf2149_module_dir))

CF2149_CFLAGS = $(BASIC_HOST_CFLAGS) $(HOST_CFLAGS)

CF2149_OBJ := $(CF2149_SRC:%.c=%.o)

ALL_OBJ += $(CF2149_OBJ)

$(CF2149_OBJ): %.o : %.c
	$(QUIET_CC)$(HOST_CC) $(CF2149_CFLAGS) -c -o $@ $<

else

# Makefile is included in another repository, so add proper include directory.
CF2149_CFLAGS = -I$(dir $(patsubst %/,%,$(dir $(cf2149_module_dir))))include

endif
