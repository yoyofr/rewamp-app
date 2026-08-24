// SPDX-License-Identifier: GPL-2.0
/* Copyright (C) 2025 Fredrik Noring */

#ifndef CF2149_MODULE_CF2149_H
#define CF2149_MODULE_CF2149_H

#include "cf2149/types.h"

#define CF2149_REGISTERS(r)						\
	r( 0, plo_a,   PLO_A,   "Period of channel A fine tone")	\
	r( 1, phi_a,   PHI_A,   "Period of channel A rough tone")	\
	r( 2, plo_b,   PLO_B,   "Period of channel B fine tone")	\
	r( 3, phi_b,   PHI_B,   "Period of channel B rough tone")	\
	r( 4, plo_c,   PLO_C,   "Period of channel C fine tone")	\
	r( 5, phi_c,   PHI_C,   "Period of channel C rough tone")	\
	r( 6, noise,   NOISE,   "Period of noise")			\
	r( 7, iomix,   IOMIX,   "I/O port and mixer settings")		\
	r( 8, level_a, LEVEL_A, "Level of channel A")			\
	r( 9, level_b, LEVEL_B, "Level of channel B")			\
	r(10, level_c, LEVEL_C, "Level of channel C")			\
	r(11, plo_env, PLO_ENV, "Period of envelope fine")		\
	r(12, phi_env, PHI_ENV, "Period of envelope rough")		\
	r(13, shape,   SHAPE,   "Shape of envelope")			\
	r(14, io_a,    IO_A,    "Data of I/O port A")			\
	r(15, io_b,    IO_B,    "Data of I/O port B")

enum {
#define CF2149_REG_ENUM(register_, symbol_, label_, description_)	\
	CF2149_REG_##label_ = register_,
CF2149_REGISTERS(CF2149_REG_ENUM)
};

struct cf2149_channel_lo {
	uint8_t period;
};

struct cf2149_channel_hi {
	CF2149_BITFIELD(uint8_t : 4,
	CF2149_BITFIELD(uint8_t period : 4,
	;))
};

struct cf2149_noise {
	CF2149_BITFIELD(uint8_t : 3,
	CF2149_BITFIELD(uint8_t period : 5,
	;))
};

struct cf2149_iomix {
	CF2149_BITFIELD(uint8_t io_b : 1,
	CF2149_BITFIELD(uint8_t io_a : 1,
	CF2149_BITFIELD(uint8_t noise_c : 1,
	CF2149_BITFIELD(uint8_t noise_b : 1,
	CF2149_BITFIELD(uint8_t noise_a : 1,
	CF2149_BITFIELD(uint8_t tone_c : 1,
	CF2149_BITFIELD(uint8_t tone_b : 1,
	CF2149_BITFIELD(uint8_t tone_a : 1,
	;))))))))
};

struct cf2149_level {
	CF2149_BITFIELD(uint8_t : 3,
	CF2149_BITFIELD(uint8_t m : 1,
	CF2149_BITFIELD(uint8_t level : 4,
	;)))
};

struct cf2149_envelope_lo {
	uint8_t period;
};

struct cf2149_envelope_hi {
	uint8_t period;
};

struct cf2149_envelope_shape {
	union {
		CF2149_BITFIELD(uint8_t : 4,
		CF2149_BITFIELD(uint8_t cont : 1,
		CF2149_BITFIELD(uint8_t att : 1,
		CF2149_BITFIELD(uint8_t alt : 1,
		CF2149_BITFIELD(uint8_t hold: 1,
		;)))))
		CF2149_BITFIELD(uint8_t : 4,
		CF2149_BITFIELD(uint8_t ctrl : 4,
		;))
	};
};

struct cf2149_io_a {
	uint8_t data;
};

struct cf2149_io_b {
	uint8_t data;
};

struct cf2149_regs {
	union {
		struct {
			struct cf2149_channel_lo lo_a;
			struct cf2149_channel_hi hi_a;
			struct cf2149_channel_lo lo_b;
			struct cf2149_channel_hi hi_b;
			struct cf2149_channel_lo lo_c;
			struct cf2149_channel_hi hi_c;
			struct cf2149_noise noise;
			struct cf2149_iomix iomix;
			struct cf2149_level level_a;
			struct cf2149_level level_b;
			struct cf2149_level level_c;
			struct cf2149_envelope_lo envelope_lo;
			struct cf2149_envelope_hi envelope_hi;
			struct cf2149_envelope_shape envelope_shape;
			struct cf2149_io_a io_a;
			struct cf2149_io_b io_b;
		};
		uint8_t u8[16];
	};
};

struct cf2149_ac_level {
	union {
		struct { CF2149_BITFIELD(uint8_t u4 : 4, CF2149_BITFIELD(uint8_t : 4, ;)) };
		struct { CF2149_BITFIELD(uint8_t u5 : 5, CF2149_BITFIELD(uint8_t : 3, ;)) };
		struct { CF2149_BITFIELD(uint8_t u6 : 6, CF2149_BITFIELD(uint8_t : 2, ;)) };
		struct { CF2149_BITFIELD(uint8_t u7 : 7, CF2149_BITFIELD(uint8_t : 1, ;)) };
		uint8_t u8;
	};
};

struct cf2149_ac {
	struct cf2149_ac_level lva;
	struct cf2149_ac_level lvb;
	struct cf2149_ac_level lvc;
};

struct cf2149_cycle {
	uint64_t c;
	uint64_t d;
};

/* Bus direction, bus control 2, 1 */
enum {				/* BDIR BC2 BC1 Mode          */
	CF2149_BDC_NACT,	/*   0   0   0  Inactive      */
	CF2149_BDC_ADAR,	/*   0   0   1  Latch address */
	CF2149_BDC_IAB,		/*   0   1   0  Inactive      */
	CF2149_BDC_DTB,		/*   0   1   1  Read from PSG */
	CF2149_BDC_BAR,		/*   1   0   0  Latch address */
	CF2149_BDC_DW,		/*   1   0   1  Inactive      */
	CF2149_BDC_DWS,		/*   1   1   0  Write to PSG  */
	CF2149_BDC_INTAK,	/*   1   1   1  Latch address */
};

struct cf2149_bdc {
	union {
		struct {
			CF2149_BITFIELD(uint8_t : 5,
			CF2149_BITFIELD(uint8_t bdir : 1,
			CF2149_BITFIELD(uint8_t bc2 : 1,
			CF2149_BITFIELD(uint8_t bc1 : 1,
			;))))
		};
		uint8_t u8;
	};
};

struct cf2149_a98 {
	union {
		struct {
			CF2149_BITFIELD(uint8_t : 6,
			CF2149_BITFIELD(uint8_t a9_l : 1,
			CF2149_BITFIELD(uint8_t a8 : 1,
			;)))
		};
		uint8_t u8;
	};
};

enum cf2149_select_mode {
	CF2149_SELECT_MODE_CLKDIV16,
	CF2149_SELECT_MODE_CLKDIV8,
};

struct cf2149_module;

struct cf2149_port {
	void (*reset_l)(struct cf2149_module *module,
		struct cf2149_cycle cycle, bool reset_l);
	void (*select_l)(struct cf2149_module *module,
		struct cf2149_cycle cycle, enum cf2149_select_mode mode);
	void (*bdc)(struct cf2149_module *module,
		struct cf2149_cycle cycle, struct cf2149_bdc bdc);
	void (*a98)(struct cf2149_module *module,
		struct cf2149_cycle cycle, struct cf2149_a98 a98);

	uint8_t (*rd_da)(struct cf2149_module *module,
		struct cf2149_cycle cycle);
	void (*wr_da)(struct cf2149_module *module,
		struct cf2149_cycle cycle, uint8_t da);
	size_t (*rd_ac)(struct cf2149_module *module,
		struct cf2149_cycle cycle,
		struct cf2149_ac *buffer, size_t count);

	struct cf2149_port_state {
		bool reset_l;
		enum cf2149_select_mode select_l;
		struct cf2149_bdc bdc;
		struct cf2149_a98 a98;
	} state;
};

struct cf2149_noise_generator {
	uint32_t p;
	uint32_t lfsr;
};

struct cf2149_module {
	struct cf2149_port port;

	struct cf2149_cycle cycle;

	struct cf2149_state {
		struct cf2149_regs regs;
		uint8_t reg;

		struct {
			struct {
				bool t;
				uint16_t p;
			} a, b, c;
		} tone;

		struct {
			uint32_t p;
			uint32_t wave;
		} env;

		struct cf2149_noise_generator noise;
	} state;

	struct {
		void (*report)(const char *fmt, ...)
			__attribute__((format(printf, 1, 2)));
	} debug;
};

struct cf2149_module cf2149_init(void);

static inline struct cf2149_cycle cf2149_cycle_cd(uint64_t c, uint64_t d)
{
	return (struct cf2149_cycle) { .c = c, .d = d };
}

#endif /* CF2149_MODULE_CF2149_H */
