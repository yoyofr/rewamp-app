// SPDX-License-Identifier: GPL-2.0

#ifndef CF300588_MACRO_H
#define CF300588_MACRO_H

#define __ALIGN__MASK(x, mask) (((x) + (mask)) & ~(mask))
#define __ALIGN_(x, a) __ALIGN__MASK(x, (typeof(x))(a) - 1)
#define ALIGN(x, a) __ALIGN_((x), (a))

#define STR(x) #x

#define ARRAY_SIZE(arr) (sizeof(arr) / sizeof((arr)[0]))

#endif /* CF300588_MACRO_H */
