/* No-op charset-conversion stub for platforms where iconv is unavailable
 * (Android API < 28) or undesirable.
 *
 * Music file titles that use non-ASCII encodings (e.g. Shift-JIS in S98 files)
 * will appear as raw bytes rather than converted Unicode, but audio playback is
 * unaffected — charset conversion is only used for display purposes.
 */

#include <stdlib.h>
#include <string.h>

#include "../third_party/libvgm/libvgm/stdtype.h"
#include "../third_party/libvgm/libvgm/utils/StrUtils.h"

struct _codepage_conversion {
    char* cpFrom;
    char* cpTo;
};

UINT8 CPConv_Init(CPCONV** retCPC, const char* cpFrom, const char* cpTo) {
    CPCONV* cpc = (CPCONV*)malloc(sizeof(CPCONV));
    if (!cpc) { *retCPC = NULL; return 0xFF; }
    cpc->cpFrom = cpFrom ? strdup(cpFrom) : NULL;
    cpc->cpTo   = cpTo   ? strdup(cpTo)   : NULL;
    *retCPC = cpc;
    return 0x00;
}

void CPConv_Deinit(CPCONV* cpc) {
    if (!cpc) return;
    free(cpc->cpFrom);
    free(cpc->cpTo);
    free(cpc);
}

UINT8 CPConv_StrConvert(CPCONV* cpc, size_t* outSize, char** outStr,
                         size_t inSize, const char* inStr) {
    if (!inStr) { *outSize = 0; return 0x00; }
    if (inSize == 0) inSize = strlen(inStr) + 1;

    if (*outStr == NULL) {
        *outStr = (char*)malloc(inSize);
        if (!*outStr) return 0xFF;
    } else if (*outSize < inSize) {
        /* Buffer too small — copy as much as fits. */
        memcpy(*outStr, inStr, *outSize);
        return 0x01;
    }
    memcpy(*outStr, inStr, inSize);
    *outSize = inSize;
    return 0x00;
}
