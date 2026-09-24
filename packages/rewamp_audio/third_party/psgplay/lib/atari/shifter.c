// SPDX-License-Identifier: GPL-2.0
/*
 * Copyright (C) 2019 Fredrik Noring
 */

#include <stdio.h>
#include <string.h>

#include "toslibc/asm/machine.h"

#include "atari/device.h"
#include "atari/shifter.h"

static char *shifter_register_name(uint32_t reg)
{
	switch (reg) {
#define SHIFTER_REG_NAME(register_, symbol_, label_, description_)	\
	case register_: return #symbol_;
SHIFTER_REGISTERS(SHIFTER_REG_NAME)
	default:
		return "";
	}
}

static uint8_t shifter_rd_u8(struct machine *machine, const struct device *device,
	uint32_t dev_address)
{
	/*
	 * REWAMP: the sync-mode register must read back as PAL.
	 *
	 * $ff820a bit 1 selects the video frequency: 1 = 50 Hz (PAL),
	 * 0 = 60 Hz.  Returning 0 for every read told every SNDH driver
	 * that probes it that this is a 60 Hz machine.  Grazey/PHF's SID
	 * conversions do exactly that -- "Docklands_Sid.sndh" runs
	 * `btst #1,$ff820a.w` (absolute short, so a byte scan for
	 * 00 ff 82 0a never finds it) and, believing 60 Hz, skips one
	 * song advance in six to compensate: measured 41.56 note
	 * changes/s against AtariAudio's 50.00/s -- the whole tune ran
	 * at 5/6 speed, pitches intact.  50 * 5/6 = 41.67.
	 *
	 * The emulated machine is a PAL ST everywhere else in this tree
	 * (ATARI_STE_PAL_MCLK just below), so answer PAL here too.
	 * AtariAudio hardcodes the same answer (r = 2 for $ff820a).
	 */
	if (dev_address == 0x0a)
		return 0x02;	/* 50 Hz field rate, internal sync */

	return 0;	/* FIXME */
}

static uint16_t shifter_rd_u16(struct machine *machine, const struct device *device,
	uint32_t dev_address)
{
	/* REWAMP: byte registers mirrored into word reads (see rd_u8). */
	return (shifter_rd_u8(machine, device, dev_address) << 8) |
		shifter_rd_u8(machine, device, dev_address + 1);
}

static void shifter_wr_u8(struct machine *machine, const struct device *device,
	uint32_t dev_address, uint8_t data)
{
	/* FIXME */
}

static void shifter_wr_u16(struct machine *machine, const struct device *device,
	uint32_t dev_address, uint16_t data)
{
	/* FIXME */
}

static size_t shifter_id_u16(struct machine *machine,
	const struct device *device, uint32_t dev_address, char *buf, size_t size)
{
	snprintf(buf, size, "wr %s", shifter_register_name(dev_address / 2));	/* FIXME */

	return strlen(buf);
}

static size_t shifter_id_u8(struct machine *machine,
	const struct device *device, uint32_t dev_address, char *buf, size_t size)
{
	snprintf(buf, size, "wr %s", shifter_register_name(dev_address / 2));	/* FIXME */

	return strlen(buf);
}

static void shifter_event(struct machine *machine, const struct device *device,
	const struct device_cycle mfp_cycle)
{
}

static void shifter_reset(struct machine *machine, const struct device *device)
{
}

const struct device shifter_device = {
	.name = "shifter",
	.clk = {
		.frequency = ATARI_STE_PAL_MCLK,
		.divisor = 1
	},
	.bus = {
		.address = 0xff8200,
		.size = 512,
	},
	.reset = shifter_reset,
	.event = shifter_event,
	.rd_u8  = shifter_rd_u8,
	.rd_u16 = shifter_rd_u16,
	.wr_u8  = shifter_wr_u8,
	.wr_u16 = shifter_wr_u16,
	.id_u8  = shifter_id_u8,
	.id_u16 = shifter_id_u16,
};
