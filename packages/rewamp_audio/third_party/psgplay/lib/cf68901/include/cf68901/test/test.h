// SPDX-License-Identifier: GPL-2.0

#ifndef CF68901_TEST_TEST_H
#define CF68901_TEST_TEST_H

#include <inttypes.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

#include "cf68901/macro.h"
#include "cf68901/test/suite.h"

#define TEST_INIT							\
	struct cf68901_module module = { };				\
	struct cf68901_event event = { };				\
	struct cf68901_clk clk = { };					\
	uint32_t clk_frequency = 4000000;	/* Default */		\
	uint32_t xtal1_frequency = 2457600;	/* Default */		\
	bool irq = false

#define ERROR(...)							\
({									\
	fprintf(stderr, __VA_ARGS__);					\
	exit(EXIT_FAILURE);						\
})

#define cycle(n)							\
({									\
	const uint64_t c = clk.c + (n);					\
									\
	while (clk.c < c) {						\
		clk.c = event.clk.c > 0 &&				\
			event.clk.c < c ? event.clk.c : c;		\
		if (event.clk.c > 0 && event.clk.c <= clk.c)		\
			EVENT(&event, &irq, event = module.port.event(&module, clk)); \
		if (event.clk.c > 0 && event.clk.c < clk.c)		\
			ERROR("CLK event in the past\n");		\
	}								\
})

#if defined(HAVE_TRACE)
#define TRACE_A(line, op, cmd, ...)					\
({									\
	printf("%s:%-4s %8" PRIu64 " %-20s irq %d ->",			\
		source, #line ":",					\
		clk.c, #cmd #op #__VA_ARGS__, event.irq);		\
})
#define TRACE_B(line, op, ...)						\
({									\
	printf(" irq %d event %" PRIu64 "\n", event.irq, event.clk.c); \
})
#else
#define TRACE_A(line, op, ...)
#define TRACE_B(line, op, ...)
#endif

#define assign(line, signal, value)					\
	TRACE_A(line, =, signal, value);				\
	assign_##signal(&module, &event, &irq, clk, value);		\
	TRACE_B(line, =)
#define assert(line, signal, value)					\
	TRACE_A(line, !, signal, value);				\
	assert_##signal(&module, &event, &irq, clk, value, line);	\
	TRACE_B(line, !)

#define EVENT(event, irq_, ...)						\
({									\
	__VA_ARGS__;							\
	if ((event)->irq)						\
		*(irq_) = true;						\
})

#define assign_CLK(module, event, irq, clk, frequency)			\
({									\
	clk_frequency = (frequency);					\
	EVENT(event, irq, *(module) = cf68901_init(clk_frequency, xtal1_frequency)); \
	(module)->debug.report = report;				\
})

#define assign_XTAL1(module, event, irq, clk, frequency)		\
({									\
	xtal1_frequency = (frequency);					\
	EVENT(event, irq, *(module) = cf68901_init(clk_frequency, xtal1_frequency)); \
	(module)->debug.report = report;				\
})

static inline void assign_RESET_L(					\
	struct cf68901_module *module, struct cf68901_event *event,	\
	bool *irq, struct cf68901_clk clk, bool reset_l)		\
{									\
	EVENT(event, irq, module->port.reset_l(module, clk, reset_l));	\
}

static inline void assign_TAI(						\
	struct cf68901_module *module, struct cf68901_event *event,	\
	bool *irq, struct cf68901_clk clk, bool level)			\
{									\
	EVENT(event, irq, *event = module->port.tai(module, clk, level)); \
}

static inline void assign_TBI(						\
	struct cf68901_module *module, struct cf68901_event *event,	\
	bool *irq, struct cf68901_clk clk, bool level)			\
{									\
	EVENT(event, irq, *event = module->port.tbi(module, clk, level)); \
}

#define CF68901_DEFINE_ASSIGN(signal)					\
static inline void assign_##signal(					\
	struct cf68901_module *module, struct cf68901_event *event,	\
	bool *irq, struct cf68901_clk clk, uint8_t data)		\
{									\
	EVENT(event, irq, *event = module->port.wr_da(module,		\
		clk, CF68901_REG_##signal, data));			\
}

#define assert_IRQ_L(module, event, irq, clk, value, line)		\
({									\
	const bool assert = *(irq) == !(value);				\
	if (!assert) {							\
		static char str[1024];					\
		snprintf(str, sizeof(str),				\
			"%s:%d: error: assert: %08" PRIu64 ": IRQ_L!%d", \
			source, line, clk.c, value);			\
		return str;						\
	}								\
})

#define assert_VECTOR(module, event, irq, clk, value, line)		\
({									\
	if (!(*irq))							\
		ERROR("%s:%d: IRQ not asserted\n", source, line);	\
	*irq = false;							\
	const bool assert = (module)->port.vector(module) == (value);	\
	if (!assert) {							\
		static char str[1024];					\
		snprintf(str, sizeof(str),				\
			"%s:%d: error: assert: %08" PRIu64 ": IRQ_L!%d", \
			source, line, clk.c, value);			\
		return str;						\
	}								\
})

#define assert_TADR(module, event, irq, clk, value, line)		\
({									\
	const bool assert = (module)->					\
		port.rd_da(module, clk, CF68901_REG_TADR) == (value);	\
	if (!assert) {							\
		static char str[1024];					\
		snprintf(str, sizeof(str),				\
			"%s:%d: error: assert: %08" PRIu64 ": TADR!%d", \
			source, line, clk.c, value);			\
		return str;						\
	}								\
})

CF68901_TEST_REGS(CF68901_DEFINE_ASSIGN)

#endif /* CF68901_TEST_TEST_H */
