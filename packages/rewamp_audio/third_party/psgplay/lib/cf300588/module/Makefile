# SPDX-License-Identifier: GPL-2.0

cf300588_module_dir := $(dir $(lastword $(MAKEFILE_LIST)))

CF300588_SOUND_SRC := $(cf300588_module_dir)cf300588-sound.c

ifeq (module/,$(cf300588_module_dir))

CF300588_CFLAGS = $(BASIC_HOST_CFLAGS) $(HOST_CFLAGS)

CF300588_SOUND_OBJ := $(CF300588_SOUND_SRC:%.c=%.o)

CF300588_OBJ := $(CF300588_SOUND_OBJ)

ALL_OBJ += $(CF300588_OBJ)

$(CF300588_OBJ): %.o : %.c
	$(QUIET_CC)$(HOST_CC) $(CF300588_CFLAGS) -c -o $@ $<

else

# Makefile is included in another repository, so add proper include directory.
CF300588_CFLAGS = -I$(dir $(patsubst %/,%,$(dir $(cf300588_module_dir))))include

endif
