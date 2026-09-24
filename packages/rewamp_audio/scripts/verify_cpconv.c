/* Harnais: exerce les convertisseurs INTÉGRÉS (chemin Android < API 28) en
 * neutralisant iconv, puis le chemin iconv tel quel. */
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "../src/StrUtils-CPConv_Stub.c"

static void force_builtin(void) {
    g_iconv_probed = 1; g_iconv_open = NULL; g_iconv = NULL; g_iconv_close = NULL;
}
/* ⚠️ La longueur attendue est DONNÉE: plusieurs sorties portent leur
 * terminateur, et un strlen s'arrêterait dessus — c'est exactement le bug
 * qu'on teste. */
static int check(const char* what, const char* got, size_t n,
                 const char* want, size_t wantLen) {
    int ok = (n == wantLen) && memcmp(got, want, n) == 0;
    printf("%-34s %s  (%zu o) %.*s\n", what, ok ? "OK  " : "ÉCHEC", n, (int)n, got);
    return ok;
}
int main(int argc, char** argv) {
    const int builtinOnly = !(argc > 1 && strcmp(argv[1], "--iconv") == 0);
    if (builtinOnly) force_builtin(); else probe_iconv();
    printf("== chemin: %s\n", builtinOnly ? "convertisseurs INTÉGRÉS (Android < 28)" : (g_iconv ? "iconv (Android >= 28, Apple, Linux)" : "iconv ABSENT"));
    int ok = 1;
    /* UTF-16LE → UTF-8: le cas du GD3 */
    {
        const unsigned char in[] = {'G',0,'a',0,'m',0,'e',0,' ',0,'O',0,'v',0,'e',0,'r',0,0,0};
        CPCONV* c; CPConv_Init(&c, "UTF-16LE", "UTF-8");
        char* out = NULL; size_t n = 0;
        CPConv_StrConvert(c, &n, &out, sizeof(in), (const char*)in);
        ok &= check("UTF-16LE ascii", out, n, "Game Over\0", 10);
        free(out); CPConv_Deinit(c);
    }
    { /* japonais: ゲーム = U+30B2 U+30FC U+30E0 */
        const unsigned char in[] = {0xB2,0x30, 0xFC,0x30, 0xE0,0x30};
        CPCONV* c; CPConv_Init(&c, "UTF-16LE", "UTF-8");
        char* out = NULL; size_t n = 0;
        CPConv_StrConvert(c, &n, &out, sizeof(in), (const char*)in);
        ok &= check("UTF-16LE japonais", out, n, "\xE3\x82\xB2\xE3\x83\xBC\xE3\x83\xA0", 9);
        free(out); CPConv_Deinit(c);
    }
    { /* hors BMP: 𝄞 U+1D11E, paire de substitution */
        const unsigned char in[] = {0x34,0xD8, 0x1E,0xDD};
        CPCONV* c; CPConv_Init(&c, "UTF-16LE", "UTF-8");
        char* out = NULL; size_t n = 0;
        CPConv_StrConvert(c, &n, &out, sizeof(in), (const char*)in);
        ok &= check("UTF-16LE paire de substitution", out, n, "\xF0\x9D\x84\x9E", 4);
        free(out); CPConv_Deinit(c);
    }
    { /* longueur AUTO: deux octets nuls terminent une chaîne UTF-16 */
        const unsigned char in[] = {'H',0,'i',0,0,0};
        CPCONV* c; CPConv_Init(&c, "UTF-16LE", "UTF-8");
        char* out = NULL; size_t n = 0;
        CPConv_StrConvert(c, &n, &out, 0, (const char*)in);
        ok &= check("UTF-16LE longueur auto", out, n, "Hi\0", 3);
        free(out); CPConv_Deinit(c);
    }
    { /* CP1252: 0x92 = apostrophe typographique U+2019 */
        const char in[] = {'I', (char)0x92, 'm', 0};
        CPCONV* c; CPConv_Init(&c, "CP1252", "UTF-8");
        char* out = NULL; size_t n = 0;
        CPConv_StrConvert(c, &n, &out, sizeof(in), in);
        ok &= check("CP1252 apostrophe", out, n, "I\xE2\x80\x99m\0", 6);
        free(out); CPConv_Deinit(c);
    }
    { /* CP932 sans iconv: recopie, comme avant — jamais de plantage */
        const char in[] = {'a','b',0};
        CPCONV* c; CPConv_Init(&c, "CP932", "UTF-8");
        char* out = NULL; size_t n = 0;
        CPConv_StrConvert(c, &n, &out, sizeof(in), in);
        ok &= check("CP932 sans iconv (recopie)", out, n, "ab\0", 3);
        free(out); CPConv_Deinit(c);
    }
    printf("%s\n", ok ? "TOUT PASSE" : "DES CAS ÉCHOUENT");
    return ok ? 0 : 1;
}
