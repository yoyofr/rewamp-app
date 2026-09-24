/* Ce que la chaîne réelle fournit ailleurs et que cet oracle n'exerce pas.
 *
 * ⚠️ Les signatures sont RECOPIÉES de leurs en-têtes: un stub dont la signature
 * ment ne casse pas le lien, il fausse la mesure. Et `rewamp_ext_in_list` est
 * REIMPLEMENTÉ, pas bouchonné — c'est lui qui décide de l'extension, donc le
 * neutraliser changerait ce qu'on mesure. */
#include <stdint.h>
#include <string.h>
#include "rewamp_waveform.h"

int rewamp_ext_in_list(const char* ext, const char* const* list)
{
    if (ext == NULL || list == NULL) return 0;
    for (int i = 0; list[i] != NULL; ++i)
        if (strcmp(ext, list[i]) == 0) return 1;
    return 0;
}

double rewamp_get_engine_param(const char* engine, const char* key, double defval)
{ (void)engine; (void)key; return defval; }

void rewamp_waveform_write(const float* pcm, uint64_t frame_count, int channels)
{ (void)pcm; (void)frame_count; (void)channels; }

int rewamp_waveform_read_i8(int channel, int8_t* out, int n)
{ (void)channel; (void)out; (void)n; return 0; }

int64_t rewamp_waveform_pos(void) { return 0; }
