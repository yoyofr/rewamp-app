// SPDX-License-Identifier: GPL-2.0

#ifndef INTERNAL_ASSERT_H
#define INTERNAL_ASSERT_H

#include <stdbool.h>

#include "internal/build-assert.h"
#include "internal/print.h"

/* Macro definitions from the Linux kernel. */

#define BUG_ON(expr)							\
	do {								\
		if (expr)						\
			pr_bug(__FILE__, __LINE__, __func__, #expr);	\
	} while (0)

#define BUG()								\
	do {								\
		pr_bug(__FILE__, __LINE__, __func__, "fatal error");	\
	} while (0)

#define WARN(...)							\
	do {								\
		pr_bug_warn(__FILE__, __LINE__, __func__, __VA_ARGS__);	\
	} while (0)

#define WARN_ONCE(...)						\
	do {								\
		static bool warned__;					\
		if (!warned__)						\
			WARN(__VA_ARGS__);					\
		warned__ = true;					\
	} while (0)

#endif /* INTERNAL_ASSERT_H */
