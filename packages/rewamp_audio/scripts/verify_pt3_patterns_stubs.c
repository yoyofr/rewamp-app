/* Ce que l'app fournit et dont le harnais n'a pas besoin. */
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
int rewamp_ext_in_list(const char* ext, const char* const* list) {
    if (!ext) return 0;
    for (; *list; ++list) if (!strcasecmp(ext, *list)) return 1;
    return 0;
}
int rewamp_waveform_pos(void) { return 0; }
int rewamp_waveform_read_i8(int c, signed char* o, int n) { (void)c; (void)o; (void)n; return 0; }
volatile int g_seek_cancel = 0;
volatile int g_is_seeking = 0;
volatile double g_seek_progress_s = 0;
