// SPDX-License-Identifier: GPL-2.0
/* Copyright (C) 2025 Fredrik Noring */

#ifndef CF68901_MODULE_CF68901_H
#define CF68901_MODULE_CF68901_H

#include "cf68901/types.h"

#define CF68901_REGISTERS(r)						\
	r( 0, gpdr,  GPDR,  "General-purpose I/O data register")	\
	r( 1, aer,   AER,   "Active edge register")			\
	r( 2, ddr,   DDR,   "Data direction register")			\
	r( 3, iera,  IERA,  "Interrupt enable register A")		\
	r( 4, ierb,  IERB,  "Interrupt enable register B")		\
	r( 5, ipra,  IPRA,  "Interrupt pending register A")		\
	r( 6, iprb,  IPRB,  "Interrupt pending register B")		\
	r( 7, isra,  ISRA,  "Interrupt in-service register A")		\
	r( 8, isrb,  ISRB,  "Interrupt in-service register B")		\
	r( 9, imra,  IMRA,  "Interrupt mask register A")		\
	r(10, imrb,  IMRB,  "Interrupt mask register B")		\
	r(11, vr,    VR,    "Vector register")				\
	r(12, tacr,  TACR,  "Timer A control register")			\
	r(13, tbcr,  TBCR,  "Timer B control register")			\
	r(14, tcdcr, TCDCR, "Timers C and D control register")		\
	r(15, tadr,  TADR,  "Timer A data register")			\
	r(16, tbdr,  TBDR,  "Timer B data register")			\
	r(17, tcdr,  TCDR,  "Timer C data register")			\
	r(18, tddr,  TDDR,  "Timer D data register")			\
	r(19, scr,   SCR,   "Synchronous character register")		\
	r(20, ucr,   UCR,   "USART control register")			\
	r(21, rsr,   RSR,   "Receiver status register")			\
	r(22, tsr,   TSR,   "Transmitter status register")		\
	r(23, udr,   UDR,   "USART data register")

enum {
#define CF68901_REG_ENUM(register_, symbol_, label_, description_)	\
	CF68901_REG_##label_ = register_,
CF68901_REGISTERS(CF68901_REG_ENUM)
};

#define CF68901_DEFINE_PORT(type)					\
struct cf68901_##type {							\
	CF68901_BITFIELD(uint8_t gpip7 : 1,				\
	CF68901_BITFIELD(uint8_t gpip6 : 1,				\
	CF68901_BITFIELD(uint8_t gpip5 : 1,				\
	CF68901_BITFIELD(uint8_t gpip4 : 1,				\
	CF68901_BITFIELD(uint8_t gpip3 : 1,				\
	CF68901_BITFIELD(uint8_t gpip2 : 1,				\
	CF68901_BITFIELD(uint8_t gpip1 : 1,				\
	CF68901_BITFIELD(uint8_t gpip0 : 1,				\
	;))))))))							\
}

#define CF68901_DEFINE_IRA(type)					\
struct cf68901_##type {							\
	CF68901_BITFIELD(uint8_t gpip7 : 1,				\
	CF68901_BITFIELD(uint8_t gpip6 : 1,				\
	CF68901_BITFIELD(uint8_t timer_a : 1,				\
	CF68901_BITFIELD(uint8_t rx_buffer_full : 1,			\
	CF68901_BITFIELD(uint8_t rx_error : 1,				\
	CF68901_BITFIELD(uint8_t tx_buffer_empty : 1,			\
	CF68901_BITFIELD(uint8_t tx_error : 1,				\
	CF68901_BITFIELD(uint8_t timer_b : 1,				\
	;))))))))							\
}

#define CF68901_DEFINE_IRB(type)					\
struct cf68901_##type {							\
	CF68901_BITFIELD(uint8_t gpip5 : 1,				\
	CF68901_BITFIELD(uint8_t gpip4 : 1,				\
	CF68901_BITFIELD(uint8_t timer_c : 1,				\
	CF68901_BITFIELD(uint8_t timer_d : 1,				\
	CF68901_BITFIELD(uint8_t gpip3 : 1,				\
	CF68901_BITFIELD(uint8_t gpip2 : 1,				\
	CF68901_BITFIELD(uint8_t gpip1 : 1,				\
	CF68901_BITFIELD(uint8_t gpip0 : 1,				\
	;))))))))							\
}

#define CF68901_CTRL_DIV(div)						\
	div(4)								\
	div(10)								\
	div(16)								\
	div(50)								\
	div(64)								\
	div(100)							\
	div(200)

enum cf68901_ctrl {
	cf68901_ctrl_stop,
#define CF68901_DEFINE_CTRL_DIV_ENUM(div)				\
	cf68901_ctrl_div_##div,
CF68901_CTRL_DIV(CF68901_DEFINE_CTRL_DIV_ENUM)
};

#define CF68901_DEFINE_TABCR(type)					\
struct cf68901_##type {							\
	CF68901_BITFIELD(uint8_t unused : 3,				\
	CF68901_BITFIELD(uint8_t reset : 1,				\
	CF68901_BITFIELD(uint8_t event : 1,				\
	CF68901_BITFIELD(uint8_t ctrl : 3,				\
	;))))								\
}

CF68901_DEFINE_PORT(gpdr);
CF68901_DEFINE_PORT(aer);
CF68901_DEFINE_PORT(ddr);
CF68901_DEFINE_IRA(iera);
CF68901_DEFINE_IRB(ierb);
CF68901_DEFINE_IRA(ipra);
CF68901_DEFINE_IRB(iprb);
CF68901_DEFINE_IRA(isra);
CF68901_DEFINE_IRB(isrb);
CF68901_DEFINE_IRA(imra);
CF68901_DEFINE_IRB(imrb);

struct cf68901_vr {
	CF68901_BITFIELD(uint8_t base : 4,
	CF68901_BITFIELD(uint8_t sei : 1,
	CF68901_BITFIELD(uint8_t unused : 3,
	;)))
};

CF68901_DEFINE_TABCR(tacr);
CF68901_DEFINE_TABCR(tbcr);

struct cf68901_tcdcr {
	CF68901_BITFIELD(uint8_t tc_unused : 1,
	CF68901_BITFIELD(uint8_t tc_ctrl : 3,
	CF68901_BITFIELD(uint8_t td_unused : 1,
	CF68901_BITFIELD(uint8_t td_ctrl : 3,
	;))))
};

struct cf68901_scr {
	CF68901_BITFIELD(uint8_t reset : 1,
	CF68901_BITFIELD(uint8_t data : 7,
	;))
};

struct cf68901_ucr {
	CF68901_BITFIELD(uint8_t clock_mode : 1,
	CF68901_BITFIELD(uint8_t char_length : 2,
	CF68901_BITFIELD(uint8_t format : 2,
	CF68901_BITFIELD(uint8_t parity_enable : 1,
	CF68901_BITFIELD(uint8_t parity : 1,
	CF68901_BITFIELD(uint8_t unused : 1,
	;))))))
};

struct cf68901_rsr {
	CF68901_BITFIELD(uint8_t buffer_full : 1,
	CF68901_BITFIELD(uint8_t overrun_error : 1,
	CF68901_BITFIELD(uint8_t parity_error : 1,
	CF68901_BITFIELD(uint8_t frame_error : 1,
	CF68901_BITFIELD(uint8_t found_search_break_detect: 1,
	CF68901_BITFIELD(uint8_t match_char_in_progress : 1,
	CF68901_BITFIELD(uint8_t synch_strip_enable : 1,
	CF68901_BITFIELD(uint8_t receiver_enable : 1,
	;))))))))
};

enum cf68901_tsr_high_low {
	cf68901_tsr_high_impedance,
	cf68901_tsr_low,
	cf68901_tsr_high,
	cf68901_tsr_loopback_mode
};

struct cf68901_tsr {
	CF68901_BITFIELD(uint8_t buffer_empty : 1,
	CF68901_BITFIELD(uint8_t underrun_error : 1,
	CF68901_BITFIELD(uint8_t auto_turnaround : 1,
	CF68901_BITFIELD(uint8_t end : 1,
	CF68901_BITFIELD(uint8_t brk : 1,
	CF68901_BITFIELD(uint8_t high_low : 2,
	CF68901_BITFIELD(uint8_t transmitter_enable : 1,
	;)))))))
};

#define CF68901_DEFINE_TDR(type)					\
struct cf68901_##type {							\
	uint8_t count;							\
}

CF68901_DEFINE_TDR(tadr);
CF68901_DEFINE_TDR(tbdr);
CF68901_DEFINE_TDR(tcdr);
CF68901_DEFINE_TDR(tddr);

struct cf68901_udr {
	uint8_t data;
};

struct cf68901_regs {
	union {
		struct {
#define CF68901_DEFINE_REG_STRUCT(register_, symbol_, label_, description_) \
			struct cf68901_##symbol_ symbol_;
CF68901_REGISTERS(CF68901_DEFINE_REG_STRUCT)
		};
		uint8_t u8[24];
	};
};

struct cf68901_timer_cycle {
	uint64_t c;
};

struct cf68901_timer_state {
	struct cf68901_timer_cycle timeout;
	struct cf68901_timer_cycle stopped;
	uint32_t prescale;
	uint32_t period;
};

struct cf68901_tabi {
	uint64_t events;
};

struct cf68901_clk {
	uint64_t c;
};

struct cf68901_event {
	bool irq;
	struct cf68901_clk clk;
};

struct cf68901_module;

struct cf68901_port {
	void (*reset_l)(struct cf68901_module *module,
		struct cf68901_clk clk, bool reset_l);

	uint8_t (*rd_da)(struct cf68901_module *module,
		struct cf68901_clk clk, uint8_t reg);
	struct cf68901_event (*wr_da)(struct cf68901_module *module,
		struct cf68901_clk clk, uint8_t reg, uint8_t val);
	uint32_t (*vector)(struct cf68901_module *module);
	struct cf68901_event (*event)(struct cf68901_module *module,
		struct cf68901_clk clk);

	struct cf68901_event (*wr_gpip)(struct cf68901_module *module,
		struct cf68901_clk clk, uint8_t bit, bool level);

	struct cf68901_event (*tai)(struct cf68901_module *module,
		struct cf68901_clk clk, bool level);
	struct cf68901_event (*tbi)(struct cf68901_module *module,
		struct cf68901_clk clk, bool level);

	struct cf68901_port_state {
		bool reset_l;

		uint8_t gpip;
		bool tai;
		bool tbi;

		struct cf68901_event event;
	} state;
};

#define CF68901_INT_ACK_SPURIOUS	0xfffffffe

struct cf68901_module {
	struct cf68901_port port;

	struct cf68901_frequency {
		uint32_t clk;
		uint32_t xtal1;
	} frequency;

	struct cf68901_clk clk;

	struct cf68901_state {
		struct cf68901_regs regs;

		struct cf68901_timer_state timer_a;
		struct cf68901_timer_state timer_b;
		struct cf68901_timer_state timer_c;
		struct cf68901_timer_state timer_d;

		struct cf68901_tabi tai;
		struct cf68901_tabi tbi;
	} state;

	struct {
		void (*report)(const char *fmt, ...)
			__attribute__((format(printf, 1, 2)));

		bool warned_once;
	} debug;
};

struct cf68901_module cf68901_init(uint32_t clk_frequency,
	uint32_t xtal1_frequency);

static inline struct cf68901_clk cf68901_clk_cycle(uint64_t c)
{
	return (struct cf68901_clk) { .c = c };
}

#endif /* CF68901_MODULE_CF68901_H */
