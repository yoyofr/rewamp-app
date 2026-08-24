// SPDX-License-Identifier: GPL-2.0
/*
 * Copyright (C) 2025 Fredrik Noring
 */

#ifndef CF300588_MODULE_CF300588_SOUND_H
#define CF300588_MODULE_CF300588_SOUND_H

#include "cf300588/types.h"

#define CF300588_SOUND_REGS(r)						\
	r( 0, ctrl,      CTRL,      "Sound DMA control")		\
	r( 1, basehi,	 BASEHI,    "Frame base address high byte")	\
	r( 2, basemi,	 BASEMI,    "Frame base address middle byte")	\
	r( 3, baselo,	 BASELO,    "Frame base address low byte")	\
	r( 4, counterhi, COUNTERHI, "Frame address counter high byte")	\
	r( 5, countermi, COUNTERMI, "Frame address counter middle byte") \
	r( 6, counterlo, COUNTERLO, "Frame address counter low byte")	\
	r( 7, endhi,     ENDHI,     "Frame end address high byte")	\
	r( 8, endmi,     ENDMI,     "Frame end address middle byte")	\
	r( 9, endlo,     ENDLO,     "Frame end address low byte")	\
	r(16, mode,      MODE,      "Sound mode control")

enum cf300588_sound_reg {
#define CF300588_SOUND_REG_ENUM(register_, symbol_, label_, description_) \
	CF300588_SOUND_REG_##label_ = register_,
CF300588_SOUND_REGS(CF300588_SOUND_REG_ENUM)
};

struct cf300588_sound_ctrl {
	CF300588_BITFIELD(uint8_t : 6,
	CF300588_BITFIELD(uint8_t play_repeat : 1,
	CF300588_BITFIELD(uint8_t play : 1,
	;)))
};

struct cf300588_sound_mode {
	CF300588_BITFIELD(uint8_t mono : 1,
	CF300588_BITFIELD(uint8_t : 5,
	CF300588_BITFIELD(uint8_t rate : 2,
	;)))
};

struct cf300588_sound_regs {
	union {
		struct {
			struct cf300588_sound_ctrl ctrl;
			uint8_t basehi;
			uint8_t basemi;
			uint8_t baselo;
			uint8_t counterhi;
			uint8_t countermi;
			uint8_t counterlo;
			uint8_t endhi;
			uint8_t endmi;
			uint8_t endlo;
			struct cf300588_sound_reg_unused {
				uint8_t u8[6];
			} unused;
			struct cf300588_sound_mode mode;
		};
		uint8_t reg[17];
	};
};

struct cf300588_sound_cycle {
	uint64_t c;
	uint64_t d;
};

struct cf300588_sound_sint {
	bool active;
	size_t count;
};

struct cf300588_sound_event {
	struct cf300588_sound_sint sint;
	struct cf300588_sound_cycle cycle;
};

struct cf300588_sound_dma_region {
	uint32_t size;
	uint32_t addr;
};

struct cf300588_sound_dma_map {
	uint32_t size;
	uint32_t addr;
	const void *p;
};

struct cf300588_sound_sample {
	int8_t left;
	int8_t right;
};

struct cf300588_sound_samples {
	size_t size;
	struct cf300588_sound_sample *sample;
};

struct cf300588_sound_module;

struct cf300588_sound_port {
	uint8_t (*rd_da)(struct cf300588_sound_module *module,
		struct cf300588_sound_cycle cycle, uint8_t reg);
	struct cf300588_sound_event (*wr_da)(
		struct cf300588_sound_module *module,
		struct cf300588_sound_cycle cycle, uint8_t reg, uint8_t val);

	struct cf300588_sound_event (*event)(
		struct cf300588_sound_module *module,
		struct cf300588_sound_cycle cycle);

	bool (*wr_ar)(struct cf300588_sound_module *module,
		uint32_t addr, uint32_t size);

	struct cf300588_sound_dma_region (*dma)(
		struct cf300588_sound_module *module);
	size_t (*sample)(struct cf300588_sound_module *module,
		struct cf300588_sound_cycle cycle,
		struct cf300588_sound_samples samples,
		struct cf300588_sound_dma_map data);
};

struct cf300588_sound_module {
	struct cf300588_sound_port port;

	struct cf300588_sound_cycle cycle;

	struct cf300588_sound_state {
		struct cf300588_sound_regs regs;
		struct cf300588_sound_regs hold;

		struct cf300588_sound_state_dma {
			uint32_t base;
			uint32_t counter;
			uint32_t end;
			uint32_t k;
			struct cf300588_sound_sint sint;
			struct cf300588_sound_sample sample;
		} dma;

		struct cf300588_sound_fifo {
			uint8_t index;
			uint8_t size;
			int8_t b[8];
		} fifo;
	} state;

	struct {
		void (*report)(const char *fmt, ...)
			__attribute__((format(printf, 1, 2)));

		bool warned_once;
	} debug;
};

struct cf300588_sound_module cf300588_sound_init(
	struct cf300588_sound_cycle cycle);

static inline struct cf300588_sound_cycle cf300588_sound_cycle_cd(
	uint64_t c, uint64_t d)
{
	return (struct cf300588_sound_cycle) { .c = c, .d = d };
}

#endif /* CF300588_MODULE_CF300588_SOUND_H */
