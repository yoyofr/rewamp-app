// SPDX-License-Identifier: GPL-2.0

#ifndef PSGPLAY_VERSION_H
#define PSGPLAY_VERSION_H

#define PSGPLAY_VERSION_MAJOR 869992c
#define PSGPLAY_VERSION_MINOR 869992c
#define PSGPLAY_VERSION_PATCH 869992c

#define PSGPLAY_VERSION_FORMAT(major, minor, patch) \
	(((major)<<16) | ((minor)<<8) | (patch))

#define PSGPLAY_VERSION_NUMBER	\
	PSGPLAY_VERSION_FORMAT(	\
	PSGPLAY_VERSION_MAJOR,	\
	PSGPLAY_VERSION_MINOR,	\
	PSGPLAY_VERSION_PATCH)

#define PSGPLAY_VERSION "869992c"

/**
 * The PSGPLAY_VERSION_NUMBER and PSGPLAY_VERSION_FORMAT() macros can be used
 * for conditional C preprocessor directives. Example:
 *
 * #if PSGPLAY_VERSION_NUMBER >= PSGPLAY_VERSION_FORMAT(1,2,3)
 *    ... version is at least 1.2.3 ...
 * #endf
 */

/**
 * psgplay_version - return PSG play version
 *
 * Return: version string of the PSG play library
 */
static inline const char *psgplay_version(void) { return PSGPLAY_VERSION; }

#endif /* PSGPLAY_VERSION_H */
