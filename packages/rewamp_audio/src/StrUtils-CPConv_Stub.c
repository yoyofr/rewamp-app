/* Conversion de jeu de caractères pour Android, où iconv n'est PAS garanti.
 *
 * bionic ne fournit `iconv()` qu'à partir de l'API 28, et notre plancher est
 * 26 (AAudio) — d'où ce fichier, qui remplace `StrUtils-CPConv_IConv.c` sur
 * cette plateforme. Il ne convertissait RIEN: il recopiait les octets tels
 * quels.
 *
 * ⚠️ Et ça ne se voyait pas comme un problème d'encodage, mais comme des tags
 * TRONQUÉS À UNE LETTRE. Le GD3 d'un `.vgm`/`.vgz` est en UTF-16LE, donc
 * « Game Over » arrive « G\0a\0m\0e\0… »: la recopie brute rend une chaîne C
 * qui s'arrête au PREMIER octet nul, et le panneau ⓘ affichait « TITLE: G ».
 * Les titres japonais, eux, sortaient en caractères corrompus. Rapporté sur
 * Android le 2026-09-03; Apple et Linux n'ont jamais vu le bug, ils ont iconv.
 *
 * Trois conversions demandées par libvgm, et une seule d'entre elles est le
 * cas courant:
 *   UTF-16LE → UTF-8  (GD3 des VGM/VGZ)   — intégrée ici, exacte
 *   CP1252   → UTF-8  (tags GYM)          — intégrée ici, exacte
 *   CP932    → UTF-8  (Shift-JIS des S98) — table de 7000 entrées: laissée à
 *                                           iconv, donc seulement en API 28+
 *
 * iconv est donc cherché à l'EXÉCUTION (`dlsym`), pas au lien: sur un appareil
 * moderne on récupère tout le catalogue de conversions, y compris CP932, sans
 * relever le plancher d'API ni abandonner les appareils en 26/27, qui gardent
 * les deux conversions intégrées. Chercher au lien aurait obligé à choisir
 * entre les deux.
 */

#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

#include "../third_party/libvgm/libvgm/stdtype.h"
#include "../third_party/libvgm/libvgm/utils/StrUtils.h"

/* ── iconv, résolu à l'exécution ───────────────────────────────────────── */

typedef void* rw_iconv_t;
typedef rw_iconv_t (*rw_iconv_open_fn)(const char*, const char*);
typedef size_t (*rw_iconv_fn)(rw_iconv_t, char**, size_t*, char**, size_t*);
typedef int (*rw_iconv_close_fn)(rw_iconv_t);

static rw_iconv_open_fn  g_iconv_open;
static rw_iconv_fn       g_iconv;
static rw_iconv_close_fn g_iconv_close;
static int               g_iconv_probed;

static void probe_iconv(void) {
    if (g_iconv_probed) return;
    g_iconv_probed = 1;
    g_iconv_open  = (rw_iconv_open_fn)dlsym(RTLD_DEFAULT, "iconv_open");
    g_iconv       = (rw_iconv_fn)dlsym(RTLD_DEFAULT, "iconv");
    g_iconv_close = (rw_iconv_close_fn)dlsym(RTLD_DEFAULT, "iconv_close");
    if (!g_iconv_open) {
        /* macOS/BSD exportent `libiconv_*`, l'en-tête renommant les appels par
         * macro. Sans intérêt sur Android (bionic exporte les noms POSIX), mais
         * c'est ce qui rend cette branche exerçable par le harnais de
         * vérification, qui tourne sur le poste de développement. */
        g_iconv_open  = (rw_iconv_open_fn)dlsym(RTLD_DEFAULT, "libiconv_open");
        g_iconv       = (rw_iconv_fn)dlsym(RTLD_DEFAULT, "libiconv");
        g_iconv_close = (rw_iconv_close_fn)dlsym(RTLD_DEFAULT, "libiconv_close");
    }
    if (!g_iconv_open || !g_iconv || !g_iconv_close) {
        g_iconv_open = NULL; g_iconv = NULL; g_iconv_close = NULL;
    }
}

/* ── Conversions intégrées ─────────────────────────────────────────────── */

enum { CONV_COPY = 0, CONV_UTF16LE, CONV_CP1252 };

struct _codepage_conversion {
    char*      cpFrom;
    char*      cpTo;
    int        builtin;    /* CONV_* — utilisé quand hIConv est NULL */
    rw_iconv_t hIConv;
};

static int cp_is(const char* cp, const char* name) {
    return cp && strcasecmp(cp, name) == 0;
}

/* Les 32 positions où CP1252 diffère de Latin-1 (0x80-0x9F). 0 = non affecté
 * (les octets restants valent leur propre point de code). */
static const unsigned short kCp1252High[32] = {
    0x20AC, 0,      0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
    0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0,      0x017D, 0,
    0,      0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
    0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0,      0x017E, 0x0178,
};

/* Écrit un point de code en UTF-8. Rend le nombre d'octets (0 si dst manque
 * de place). */
static size_t utf8_put(char* dst, size_t room, unsigned int cp) {
    if (cp < 0x80) {
        if (room < 1) return 0;
        dst[0] = (char)cp;
        return 1;
    } else if (cp < 0x800) {
        if (room < 2) return 0;
        dst[0] = (char)(0xC0 | (cp >> 6));
        dst[1] = (char)(0x80 | (cp & 0x3F));
        return 2;
    } else if (cp < 0x10000) {
        if (room < 3) return 0;
        dst[0] = (char)(0xE0 | (cp >> 12));
        dst[1] = (char)(0x80 | ((cp >> 6) & 0x3F));
        dst[2] = (char)(0x80 | (cp & 0x3F));
        return 3;
    }
    if (room < 4) return 0;
    dst[0] = (char)(0xF0 | (cp >> 18));
    dst[1] = (char)(0x80 | ((cp >> 12) & 0x3F));
    dst[2] = (char)(0x80 | ((cp >> 6) & 0x3F));
    dst[3] = (char)(0x80 | (cp & 0x3F));
    return 4;
}

/* Convertit vers UTF-8 dans [dst, dst+room). Rend les octets écrits, ou
 * (size_t)-1 si la place manque. `written` compte aussi quand dst == NULL
 * (passe de mesure). */
static size_t convert_to_utf8(int kind, const unsigned char* in, size_t inLen,
                              char* dst, size_t room) {
    size_t out = 0;
    if (kind == CONV_UTF16LE) {
        for (size_t i = 0; i + 1 < inLen; i += 2) {
            unsigned int cp = (unsigned int)in[i] | ((unsigned int)in[i + 1] << 8);
            /* Paire de substitution: un seul point de code sur quatre octets. */
            if (cp >= 0xD800 && cp <= 0xDBFF && i + 3 < inLen) {
                unsigned int lo =
                    (unsigned int)in[i + 2] | ((unsigned int)in[i + 3] << 8);
                if (lo >= 0xDC00 && lo <= 0xDFFF) {
                    cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
                    i += 2;
                }
            }
            char tmp[4];
            size_t n = utf8_put(dst ? dst + out : tmp,
                                dst ? room - out : sizeof(tmp), cp);
            if (n == 0) return (size_t)-1;
            out += n;
        }
        return out;
    }
    /* CP1252 */
    for (size_t i = 0; i < inLen; i++) {
        unsigned int c = in[i];
        unsigned int cp = c;
        if (c >= 0x80 && c <= 0x9F) {
            unsigned short m = kCp1252High[c - 0x80];
            cp = m ? m : c;   /* non affecté: on garde l'octet tel quel */
        }
        char tmp[4];
        size_t n = utf8_put(dst ? dst + out : tmp,
                            dst ? room - out : sizeof(tmp), cp);
        if (n == 0) return (size_t)-1;
        out += n;
    }
    return out;
}

/* ── API attendue par libvgm ───────────────────────────────────────────── */

UINT8 CPConv_Init(CPCONV** retCPC, const char* cpFrom, const char* cpTo) {
    CPCONV* cpc = (CPCONV*)calloc(1, sizeof(CPCONV));
    if (!cpc) { *retCPC = NULL; return 0xFF; }
    cpc->cpFrom = cpFrom ? strdup(cpFrom) : NULL;
    cpc->cpTo   = cpTo   ? strdup(cpTo)   : NULL;

    probe_iconv();
    if (g_iconv_open && cpFrom && cpTo) {
        rw_iconv_t h = g_iconv_open(cpTo, cpFrom);
        if (h != (rw_iconv_t)(-1)) cpc->hIConv = h;
    }
    if (cpc->hIConv == NULL) {
        if (cp_is(cpTo, "UTF-8") && cp_is(cpFrom, "UTF-16LE"))
            cpc->builtin = CONV_UTF16LE;
        else if (cp_is(cpTo, "UTF-8") && cp_is(cpFrom, "CP1252"))
            cpc->builtin = CONV_CP1252;
        else
            cpc->builtin = CONV_COPY;   /* CP932 sans iconv: octets bruts */
    }
    *retCPC = cpc;
    return 0x00;
}

void CPConv_Deinit(CPCONV* cpc) {
    if (!cpc) return;
    if (cpc->hIConv && g_iconv_close) g_iconv_close(cpc->hIConv);
    free(cpc->cpFrom);
    free(cpc->cpTo);
    free(cpc);
}

UINT8 CPConv_StrConvert(CPCONV* cpc, size_t* outSize, char** outStr,
                        size_t inSize, const char* inStr) {
    if (!cpc || !inStr) { *outSize = 0; return 0x00; }

    /* inSize == 0 = « mesure la chaîne toi-même », terminateur compris. Sa
     * longueur dépend de la largeur de caractère de la source: un UTF-16 se
     * termine par DEUX octets nuls, et un `strlen` s'arrêterait au premier. */
    if (inSize == 0) {
        if (cpc->builtin == CONV_UTF16LE || cp_is(cpc->cpFrom, "UTF-16LE")) {
            const unsigned char* p = (const unsigned char*)inStr;
            size_t n = 0;
            while (p[n] != 0 || p[n + 1] != 0) n += 2;
            inSize = n + 2;
        } else {
            inSize = strlen(inStr) + 1;
        }
    }

    if (cpc->hIConv && g_iconv) {
        /* iconv présent (API 28+): tout le catalogue, CP932 compris. */
        size_t room = inSize * 4 + 4;
        char* buf = (*outStr != NULL) ? *outStr : (char*)malloc(room);
        if (!buf) return 0xFF;
        if (*outStr != NULL) room = *outSize;
        char* inP  = (char*)inStr;
        char* outP = buf;
        size_t inLeft = inSize, outLeft = room;
        size_t rc = g_iconv(cpc->hIConv, &inP, &inLeft, &outP, &outLeft);
        if (rc == (size_t)-1 && *outStr == NULL) { free(buf); return 0x01; }
        *outStr  = buf;
        *outSize = room - outLeft;
        return (rc == (size_t)-1) ? 0x01 : 0x00;
    }

    if (cpc->builtin == CONV_COPY) {
        /* Rien à faire de mieux: on recopie, comme avant. */
        if (*outStr == NULL) {
            *outStr = (char*)malloc(inSize);
            if (!*outStr) return 0xFF;
        } else if (*outSize < inSize) {
            memcpy(*outStr, inStr, *outSize);
            return 0x01;
        }
        memcpy(*outStr, inStr, inSize);
        *outSize = inSize;
        return 0x00;
    }

    /* Conversion intégrée: une passe de MESURE, puis l'écriture — la taille de
     * sortie n'est pas déductible de l'entrée (1 à 4 octets par caractère). */
    const unsigned char* in = (const unsigned char*)inStr;
    size_t need = convert_to_utf8(cpc->builtin, in, inSize, NULL, 0);
    if (need == (size_t)-1) return 0xFF;
    if (*outStr == NULL) {
        *outStr = (char*)malloc(need ? need : 1);
        if (!*outStr) return 0xFF;
        *outSize = need;
    } else if (*outSize < need) {
        size_t part = convert_to_utf8(cpc->builtin, in, inSize, *outStr, *outSize);
        *outSize = (part == (size_t)-1) ? 0 : part;
        return 0x01;
    } else {
        *outSize = need;
    }
    convert_to_utf8(cpc->builtin, in, inSize, *outStr, need);
    return 0x00;
}
