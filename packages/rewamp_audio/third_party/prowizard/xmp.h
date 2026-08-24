/* Minimal stand-in for libxmp's public xmp.h.
 *
 * The vendored ProWizard depackers (third_party/prowizard/prowizard/) are kept
 * BYTE-IDENTICAL to libxmp upstream so they can be resynced trivially. They
 * include "xmp.h", "../../common.h", "../../format.h" and "../../hio.h";
 * this directory supplies rewamp's own tiny replacements for those four
 * headers so no part of libxmp itself has to be vendored.
 */
#ifndef REWAMP_PROWIZARD_XMP_H
#define REWAMP_PROWIZARD_XMP_H

#define XMP_NAME_SIZE 64

struct xmp_test_info {
	char name[XMP_NAME_SIZE];	/* Module title */
	char type[XMP_NAME_SIZE];	/* Module format */
};

#endif /* REWAMP_PROWIZARD_XMP_H */
