// SPDX-License-Identifier: GPL-2.0

#ifndef CF68901_TEST_SUITE_H
#define CF68901_TEST_SUITE_H

#include <stddef.h>

#include "cf68901/types.h"
#include "cf68901/module/cf68901.h"

#define CF68901_TEST_PROTOTYPE						\
	const char *test(void (*report)(const char *fmt, ...))
CF68901_TEST_PROTOTYPE;

#define CF68901_TEST_REGS(a)						\
	a(IERA)								\
	a(IMRA)								\
	a(VR)								\
	a(TACR)								\
	a(TADR)

#define CF68901_TEST_ASSIGNS(a)						\
	a(CLK)								\
	a(XTAL1)							\
	a(RESET_L)							\
	CF68901_TEST_REGS(a)

#define CF68901_TEST_ASSERTS(a)						\
	a(IRQ_L)							\
	a(TADR)

#endif /* CF68901_TEST_SUITE_H */
