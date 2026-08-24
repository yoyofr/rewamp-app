// SPDX-License-Identifier: GPL-2.0
/* Copyright (C) 2025 Fredrik Noring */

#ifndef CF2149_MODULE_DAC_H
#define CF2149_MODULE_DAC_H

/*
 * Computed with [ printf "%.8f" $ 2**( (n-15) / 2 ) | n <- [0..15] ] to
 * match figure 1 "Output level of DA convertor" on page 8 in the YM2149
 * software-controlled sound generator (SSG) manual.
 *
 * For example, a 4-bit level to signed 16-bit DAC can be defined as
 *
 * #define DAC_S16_BITS(S) ((S) * 0xffff - 0x8000)
 *         static const int16_t dac[16] = CF2149_DAC_4_BIT_LEVEL(DAC_S16_BITS);
 *
 */
#define CF2149_DAC_4_BIT_LEVEL(D) { 					\
		D(0.00552427),						\
		D(0.00781250),						\
		D(0.01104854),						\
		D(0.01562500),						\
		D(0.02209709),						\
		D(0.03125000),						\
		D(0.04419417),						\
		D(0.06250000),						\
		D(0.08838835),						\
		D(0.12500000),						\
		D(0.17677670),						\
		D(0.25000000),						\
		D(0.35355339),						\
		D(0.50000000),						\
		D(0.70710678),						\
		D(1.00000000),						\
	}

/*
 * Computed with [ printf "%.8f" $ 2**( (n-31) / 4 ) | n <- [0..31] ] to
 * match figure 1 "Output level of DA convertor" on page 8 in the YM2149
 * software-controlled sound generator (SSG) manual.
 *
 * For example, a 5-bit level to signed 16-bit DAC can be defined as
 *
 * #define DAC_S16_BITS(S) ((S) * 0xffff - 0x8000)
 *         static const int16_t dac[32] = CF2149_DAC_5_BIT_LEVEL(DAC_S16_BITS);
 *
 */
#define CF2149_DAC_5_BIT_LEVEL(D) { 					\
		D(0.00464534),						\
		D(0.00552427),						\
		D(0.00656950),						\
		D(0.00781250),						\
		D(0.00929068),						\
		D(0.01104854),						\
		D(0.01313901),						\
		D(0.01562500),						\
		D(0.01858136),						\
		D(0.02209709),						\
		D(0.02627801),						\
		D(0.03125000),						\
		D(0.03716272),						\
		D(0.04419417),						\
		D(0.05255603),						\
		D(0.06250000),						\
		D(0.07432544),						\
		D(0.08838835),						\
		D(0.10511205),						\
		D(0.12500000),						\
		D(0.14865089),						\
		D(0.17677670),						\
		D(0.21022410),						\
		D(0.25000000),						\
		D(0.29730178),						\
		D(0.35355339),						\
		D(0.42044821),						\
		D(0.50000000),						\
		D(0.59460356),						\
		D(0.70710678),						\
		D(0.84089642),						\
		D(1.00000000),						\
	}

#endif /* CF2149_MODULE_DAC_H */
