# SPDX-License-Identifier: GPL-2.0

cf68901_module_dir := $(dir $(lastword $(MAKEFILE_LIST)))

CF68901_SRC := $(cf68901_module_dir)cf68901.c

ifeq (module/,$(cf68901_module_dir))

CF68901_CFLAGS = $(BASIC_HOST_CFLAGS) $(HOST_CFLAGS)

CF68901_OBJ := $(CF68901_SRC:%.c=%.o)

ALL_OBJ += $(CF68901_OBJ)

$(CF68901_OBJ): %.o : %.c
	$(QUIET_CC)$(HOST_CC) $(CF68901_CFLAGS) -c -o $@ $<

else

# Makefile is included in another repository, so add proper include directory.
CF68901_CFLAGS = -I$(dir $(patsubst %/,%,$(dir $(cf68901_module_dir))))include

endif
