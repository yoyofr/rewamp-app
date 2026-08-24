// SPDX-License-Identifier: GPL-2.0

#ifndef CF300588_MODULE_ASSERT_H
#define CF300588_MODULE_ASSERT_H

#include "cf300588/assert.h"

#define pr_rep(module, ...)						\
	do {								\
		if ((module)->debug.report) {				\
			((module)->debug.report(__VA_ARGS__));		\
		}							\
	} while (0)

#define MODULE_SOH	"\001"		/* ASCII start of header */

#define MODULE_EMERG	MODULE_SOH "0"	/* System is unusable */
#define MODULE_ALERT	MODULE_SOH "1"	/* Action must be taken immediately */
#define MODULE_CRIT	MODULE_SOH "2"	/* Critical conditions */
#define MODULE_ERR	MODULE_SOH "3"	/* Error conditions */
#define MODULE_WARNING	MODULE_SOH "4"	/* Warning conditions */
#define MODULE_NOTICE	MODULE_SOH "5"	/* Normal but significant condition */
#define MODULE_INFO	MODULE_SOH "6"	/* Informational */
#define MODULE_DEBUG	MODULE_SOH "7"	/* Debug-level messages */

#define MODULE_DEFAULT	MODULE_SOH "d"	/* The default module loglevel */

/* Maintain compiler format checking with disabled debugging statements. */
#define no_rep(module, fmt, ...)					\
	({								\
		if (0)							\
			pr_rep((module), fmt, ##__VA_ARGS__);		\
		0;							\
	})

#define pr_fmt(fmt) fmt

#define pr_emerg( m, fmt, ...) pr_rep((m), MODULE_EMERG   pr_fmt(fmt), ##__VA_ARGS__)
#define pr_alert( m, fmt, ...) pr_rep((m), MODULE_ALERT   pr_fmt(fmt), ##__VA_ARGS__)
#define pr_crit(  m, fmt, ...) pr_rep((m), MODULE_CRIT    pr_fmt(fmt), ##__VA_ARGS__)
#define pr_err(   m, fmt, ...) pr_rep((m), MODULE_ERR     pr_fmt(fmt), ##__VA_ARGS__)
#define pr_warn(  m, fmt, ...) pr_rep((m), MODULE_WARNING pr_fmt(fmt), ##__VA_ARGS__)
#define pr_notice(m, fmt, ...) pr_rep((m), MODULE_NOTICE  pr_fmt(fmt), ##__VA_ARGS__)
#define pr_info(  m, fmt, ...) pr_rep((m), MODULE_INFO    pr_fmt(fmt), ##__VA_ARGS__)

#if defined(DEBUG)
#define pr_debug( m, fmt, ...) pr_rep((m), MODULE_DEBUG   pr_fmt(fmt), ##__VA_ARGS__)
#else
#define pr_debug( m, fmt, ...) no_rep((m), MODULE_DEBUG   pr_fmt(fmt), ##__VA_ARGS__)
#endif

#define pr_err_msg(module, msg)						\
	pr_err(module, "%s:%d: %s: %s\n", __FILE__, __LINE__, __func__, msg)

#define MODULE_BUG_ON(module, expr)					\
	do {								\
		if (expr) {						\
			pr_err_msg(module, "BUG_ON: " STR(expr));	\
		}							\
	} while (0)

#define MODULE_WARN_ONCE(module, format...)				\
	do {								\
		if (!(module)->debug.warned_once)			\
			pr_warn(module, format);			\
		(module)->debug.warned_once = true;			\
	} while (0)

#define MODULE_BUG(module) pr_err_msg(module, "BUG")

#endif /* CF300588_MODULE_ASSERT_H */
