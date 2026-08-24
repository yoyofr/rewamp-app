//
//  chp2ym.h
//  libchpconv
//
//  Created by Yohann Magnien David on 20/05/2024.
//

#ifndef chp2ym_h
#define chp2ym_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Convert an Amstrad CPC ChipTracker (.chp) file at `filename` into a malloc'd
// YM3 buffer (*ym_data). Returns the buffer length in bytes, or 0 on failure.
int chp2ym(char *filename,uint8_t **ym_data);

#ifdef __cplusplus
}
#endif

#endif /* chp2ym_h */
