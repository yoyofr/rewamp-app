/* rewamp_declick — voir rewamp_declick.h pour le pourquoi. */
#include "rewamp_declick.h"

#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <math.h>

/* Contexte: fenêtre de médiane de chaque côté, garde autour de l'échantillon
 * testé (les voisins immédiats d'un déchet en sont souvent aussi). */
#define DK_WINDOW      220   /* 5 ms à 44,1 kHz */
#define DK_GUARD       4
/* Un déchet domine son voisinage d'au moins K (24 dB). */
#define DK_RATIO       16.0f
/* Sous ce plancher de contexte on ne fait plus confiance à la médiane (silence
 * numérique exact, dither) — seuil effectif en silence = K × plancher = 0,04
 * (−28 dBFS). Plus bas, le PLANCHER DE BRUIT de certains rips (±0,02–0,03 sur
 * World Heroes Perfect _42/_04) devenait candidat à 20 × sa médiane, se
 * fusionnait à l'amas de déchets voisin et diluait sa rugosité: une course de
 * 59 trames « lisse » que rien ne réparait plus. */
#define DK_FLOOR       0.0025f
/* Pré-porte absolue: rien en dessous n'est testé (coût nul en silence). */
#define DK_MIN_ABS     0.04f
/* Courses: trous fusionnés, longueur maximale réparée. */
#define DK_MERGE_GAP   8
#define DK_MAX_RUN     64
/* RUGOSITÉ: un déchet saute d'un échantillon à l'autre de l'ordre de sa
 * crête (0,55 → 0,0008 → 0,51 → 0,53 → 0,0000), là où une impulsion
 * MUSICALE isolée est lisse — demi-sinus de 30 échantillons d'un chiptune
 * (pas moyen ≈ 0,07 × crête), palier carré d'un son Atari (≈ 0,1 × crête),
 * blip de synthé. Le test de contexte seul les prenait tous les trois pour
 * des déchets (mesuré sur le disque: progressive_chiptunez.mp3,
 * 04_Kaleidoscope.wav, Skipp-Syntetyzer.flac). Pas moyen |x[n]−x[n−1]| sur la
 * course, bornes comprises, rapporté à la crête. Pour un sinus pur c'est
 * 4f/fs: le seuil ne mord qu'au-dessus de ~2,7 kHz — et une telle rafale
 * doit ENCORE dominer de 24 dB ses deux côtés. */
#define DK_ROUGHNESS   0.25f
/* RÉCURRENCE: un train d'impulsions FINES est de la musique — `run.ogg`
 * (scene.org) tient une note en pulsations de 1 à 3 échantillons toutes les
 * 162 trames (272 Hz), amplitude constante à ±20 %. Rugueux par nature, il
 * passe le test ci-dessus; ce qui le distingue d'un déchet, c'est qu'un
 * événement d'amplitude COMPARABLE existe À DISTANCE. On cherche donc
 * |x| ≥ 0,7 × crête entre 5 et 15 ms de part et d'autre de la course: trouvé,
 * on n'y touche pas. ⚠️ Pas plus près: les déchets viennent aussi en RAFALE
 * (T-3103G_05: trois amas en 2,7 ms, puis rien), et une fenêtre qui part de
 * la course les faisait se couvrir l'un l'autre. Un déchet est suivi d'un
 * plancher ou d'une attaque bien plus basse que lui (jw_hes 07.ogg: 0,39
 * après un amas à 0,84). Les décisions se prennent sur les valeurs BRUTES,
 * avant toute réparation: zéroer la première pulsation d'un train, puis
 * juger la deuxième sur un voisinage déjà réparé, ferait tomber tout le train
 * en cascade. */
#define DK_RECUR_NEAR   220
#define DK_RECUR_FAR    660
#define DK_RECUR_RATIO  0.7f
/* QUEUE: une percussion DÉCROÎT — les 8 échantillons qui suivent sa crête
 * restent à 20–50 % d'elle (Skipp-Syntetyzer.flac, coups courts qui échappent
 * à la bimodalité) — là où un amas de déchets retombe au plancher d'un coup
 * (≤ 3 % sur World Heroes, ≤ 4 % sur jw_hes 07.ogg dont la musique suit
 * pourtant à 2 ms). */
#define DK_TAIL_FRAMES  8
#define DK_TAIL_MAX     0.12f
/* BIMODALITÉ: un amas de déchets ne contient que des valeurs ≈ crête ou ≈ 0
 * (0,55 / 0,0008 / 0,51 / 0,53 / 0,0000 / −0,54 / 0,50 / 0 / 0 / 0,61) — des
 * octets corrompus, pas une forme d'onde. Un transitoire MUSICAL bandlimité
 * traverse toutes les valeurs intermédiaires: le coup de percussion de
 * Skipp-Syntetyzer.flac (oscillation amortie à ~7 kHz, rugueuse ET
 * apériodique, donc invisible aux deux tests précédents) a la moitié de ses
 * échantillons entre 10 % et 45 % de sa crête, l'amas de World Heroes en a un
 * sur douze. Au-delà de 25 % d'intermédiaires, c'est de la musique. */
#define DK_MID_LO       0.10f
#define DK_MID_HI       0.45f
#define DK_MID_MAX      0.25f
/* Désarmement: 200 ms de blocs « musique » (RMS > −50 dBFS), ou 60 s. */
#define DK_MUSIC_BLOCK 256
#define DK_MUSIC_RMS   0.003f
#define DK_MUSIC_SECS  0.2
#define DK_CAP_SECS    60.0
/* Étage: historique (contexte à gauche) et avance (contexte à droite). Il faut
 * H ≥ WINDOW+GUARD et D ≥ MAX_RUN+MERGE_GAP+GUARD+WINDOW (= 296). */
#define DK_HISTORY     768   /* ≥ RECUR_FAR */
#define DK_LOOKAHEAD   768   /* ≥ MAX_RUN+MERGE_GAP+RECUR_FAR (732) */
#define DK_LOG_MAX     32

struct RewampDeclick {
    int      channels;
    int      sampleRate;
    int      armed;
    int      eof;

    /* Étage interleaved: [DK_HISTORY trames d'historique][live trames]. */
    float*   stage;
    int      stageCapFrames;   /* capacité totale, historique compris */
    int      live;             /* trames vivantes après l'historique */
    int      historyValid;     /* trames d'historique réellement remplies */

    unsigned char* flags;      /* par canal: flagsCap*channels */
    int      flagsCap;
    int*     runs;             /* (start, end) des courses d'UN canal */
    int      runsCap;
    float    med[DK_WINDOW];   /* tampon de sélection */

    /* Compteur de musique. */
    double   blockSumSq;
    int      blockCount;
    uint64_t musicFrames;
    uint64_t totalFrames;

    /* Diagnostic. */
    int      repairCount;
    RewampDeclickRepair log[DK_LOG_MAX];
};

RewampDeclick* rewamp_declick_create(int channels, int sampleRate) {
    if (channels < 1 || channels > 32 || sampleRate < 8000) return NULL;
    RewampDeclick* d = (RewampDeclick*)calloc(1, sizeof(*d));
    if (!d) return NULL;
    d->channels   = channels;
    d->sampleRate = sampleRate;
    d->armed      = 1;
    return d;
}

void rewamp_declick_destroy(RewampDeclick* d) {
    if (!d) return;
    free(d->stage);
    free(d->flags);
    free(d->runs);
    free(d);
}

void rewamp_declick_reset(RewampDeclick* d, int armed) {
    if (!d) return;
    d->armed        = armed ? 1 : 0;
    d->eof          = 0;
    d->live         = 0;
    d->historyValid = 0;
    d->blockSumSq   = 0.0;
    d->blockCount   = 0;
    d->musicFrames  = 0;
    d->totalFrames  = 0;
    d->repairCount  = 0;
}

int rewamp_declick_armed(const RewampDeclick* d) { return d ? d->armed : 0; }

int rewamp_declick_repairs(const RewampDeclick* d, RewampDeclickRepair* log, int max) {
    if (!d) return 0;
    int n = d->repairCount < DK_LOG_MAX ? d->repairCount : DK_LOG_MAX;
    if (log && max > 0) {
        if (n > max) n = max;
        memcpy(log, d->log, (size_t)n * sizeof(*log));
    }
    return d->repairCount;
}

int rewamp_declick_ext_is_cd_rip(const char* ext) {
    /* Formats qui servent à publier des pistes de CD audio: le domaine des
     * mauvais rips. Un `.wav` est inclus (rip brut); les formats de jeu
     * (adx, brstm, txtp…) ne le sont pas — leurs débuts sont ceux du jeu. */
    static const char* const kExts[] = {
        "mp3", "mp2", "mp1", "ape", "ogg", "oga", "opus", "flac",
        "wav", "wv", "tta", "tak", "m4a", "aac", "mka", "mpc", "shn",
        "aiff", "aif", NULL
    };
    if (!ext || !*ext) return 0;
    if (*ext == '.') ext++;
    for (int i = 0; kExts[i]; i++)
        if (strcasecmp(ext, kExts[i]) == 0) return 1;
    return 0;
}

/* ---- étage ---------------------------------------------------------------- */

static int dk_ensure_stage(RewampDeclick* d, int liveWanted) {
    int need = DK_HISTORY + liveWanted;
    if (need <= d->stageCapFrames) return 1;
    int cap = need + 1024;
    float* s = (float*)calloc((size_t)cap * d->channels, sizeof(float));
    if (!s) return 0;
    if (d->stage) {
        memcpy(s, d->stage,
               (size_t)(DK_HISTORY + d->live) * d->channels * sizeof(float));
        free(d->stage);
    }
    d->stage = s;
    d->stageCapFrames = cap;
    /* Les drapeaux couvrent tout le live possible: `scan` est borné par
     * `live`, lui-même par la capacité de l'étage — et l'étage ne regrossit
     * pas à chaque appel (un appel plus gourmand qui tient encore dedans ne
     * repasse pas ici). */
    int fcap = cap - DK_HISTORY;
    if (fcap > d->flagsCap) {
        free(d->flags);
        d->flags = (unsigned char*)calloc((size_t)fcap * d->channels, 1);
        d->flagsCap = d->flags ? fcap : 0;
        if (!d->flags) return 0;
        /* Une course occupe au moins une trame et deux courses sont séparées
         * d'au moins MERGE_GAP+1 trames: fcap/2 est large. */
        free(d->runs);
        d->runsCap = fcap / 2 + 2;
        d->runs = (int*)calloc((size_t)d->runsCap * 2, sizeof(int));
        if (!d->runs) return 0;
    }
    return 1;
}

/* Remplit le live jusqu'à `want` trames (ou EOF). */
static void dk_fill(RewampDeclick* d, int want, RewampDeclickSource src, void* user) {
    while (d->live < want && !d->eof) {
        int ask = want - d->live;
        float* dst = d->stage + (size_t)(DK_HISTORY + d->live) * d->channels;
        uint64_t got = src(user, dst, (uint64_t)ask);
        if (got < (uint64_t)ask) d->eof = 1;
        d->live += (int)got;
    }
}

/* ---- détection ------------------------------------------------------------ */

/* Médiane de |x| sur `n` valeurs déjà copiées dans d->med (quickselect). */
static float dk_median_inplace(float* a, int n) {
    if (n <= 0) return 0.0f;
    int k = n / 2, lo = 0, hi = n - 1;
    while (lo < hi) {
        float pivot = a[(lo + hi) / 2];
        int i = lo, j = hi;
        while (i <= j) {
            while (a[i] < pivot) i++;
            while (a[j] > pivot) j--;
            if (i <= j) { float t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
        }
        if (k <= j) hi = j;
        else if (k >= i) lo = i;
        else break;
    }
    return a[k];
}

/* Médiane de |x| du canal `ch` sur les trames [from, to) de l'étage
 * (indices absolus dans l'étage, historique compris), bornées à ce qui est
 * valide. Rend -1 si la fenêtre est vide. */
static float dk_context(RewampDeclick* d, int ch, int from, int to) {
    int lo = DK_HISTORY - d->historyValid;
    int hi = DK_HISTORY + d->live;
    if (from < lo) from = lo;
    if (to > hi) to = hi;
    int n = to - from;
    if (n <= 0) return -1.0f;
    if (n > DK_WINDOW) n = DK_WINDOW;
    const float* s = d->stage + (size_t)from * d->channels + ch;
    for (int i = 0; i < n; i++) d->med[i] = fabsf(s[(size_t)i * d->channels]);
    return dk_median_inplace(d->med, n);
}

/* Marque les déchets des trames live [0, scan). */
static void dk_flag(RewampDeclick* d, int scan) {
    const int C = d->channels;
    memset(d->flags, 0, (size_t)scan * C);
    for (int ch = 0; ch < C; ch++) {
        for (int i = 0; i < scan; i++) {
            const int si = DK_HISTORY + i;
            float v = fabsf(d->stage[(size_t)si * C + ch]);
            if (v < DK_MIN_ABS) continue;
            float need = v / DK_RATIO;   /* le contexte doit rester SOUS ça */
            float before = dk_context(d, ch, si - DK_GUARD - DK_WINDOW, si - DK_GUARD);
            if (before >= need) continue;
            float after = dk_context(d, ch, si + DK_GUARD + 1, si + DK_GUARD + 1 + DK_WINDOW);
            if (after >= need) continue;
            float ctx = before > after ? before : after;
            if (ctx < DK_FLOOR) ctx = DK_FLOOR;
            if (v > DK_RATIO * ctx) d->flags[(size_t)i * C + ch] = 1;
        }
    }
}

/* Une course [sStart, sEnd] (indices d'étage) du canal `ch` est-elle un
 * amas de déchets ? Décision sur les valeurs BRUTES — voir les DK_* pour
 * chacun des quatre tests, et le cas mesuré qui l'a imposé. */
static int dk_is_junk(RewampDeclick* d, int ch, int sStart, int sEnd) {
    const int C = d->channels;
    const int lo = DK_HISTORY - d->historyValid, hi = DK_HISTORY + d->live;
    const int len = sEnd - sStart + 1;
    float pk = 0.0f;
    for (int k = sStart; k <= sEnd; k++) {
        float av = fabsf(d->stage[(size_t)k * C + ch]);
        if (av > pk) pk = av;
    }
    if (pk <= 0.0f) return 0;

    /* Rugosité. */
    float steps = 0.0f; int nsteps = 0;
    for (int k = sStart - 1; k <= sEnd; k++) {
        if (k < lo || k + 1 >= hi) continue;
        steps += fabsf(d->stage[(size_t)(k + 1) * C + ch] -
                       d->stage[(size_t)k * C + ch]);
        nsteps++;
    }
    if (nsteps == 0 || steps / (float)nsteps < DK_ROUGHNESS * pk) return 0;

    /* Bimodalité. */
    int mid = 0;
    for (int k = sStart; k <= sEnd; k++) {
        float av = fabsf(d->stage[(size_t)k * C + ch]);
        if (av >= DK_MID_LO * pk && av <= DK_MID_HI * pk) mid++;
    }
    if ((float)mid > DK_MID_MAX * (float)len) return 0;

    /* Queue. */
    int t1 = sEnd + 1 + DK_TAIL_FRAMES; if (t1 > hi) t1 = hi;
    for (int k = sEnd + 1; k < t1; k++)
        if (fabsf(d->stage[(size_t)k * C + ch]) > DK_TAIL_MAX * pk) return 0;

    /* Récurrence, à distance. */
    const float recur = DK_RECUR_RATIO * pk;
    int a0 = sStart - DK_RECUR_FAR, a1 = sStart - DK_RECUR_NEAR;
    if (a0 < lo) a0 = lo;
    for (int k = a0; k < a1; k++)
        if (fabsf(d->stage[(size_t)k * C + ch]) >= recur) return 0;
    int b0 = sEnd + 1 + DK_RECUR_NEAR, b1 = sEnd + 1 + DK_RECUR_FAR;
    if (b1 > hi) b1 = hi;
    for (int k = b0; k < b1; k++)
        if (fabsf(d->stage[(size_t)k * C + ch]) >= recur) return 0;

    return 1;
}

/* Fusionne les courses, décide, puis interpole. `n` = trames live rendues à
 * cet appel: seules les courses qui COMMENCENT avant n sont réparées (les
 * autres reviendront au prochain appel, avec plus de contexte). Deux passes
 * par canal: toutes les décisions d'abord, sur l'étage intact, les
 * réparations ensuite. */
static void dk_repair(RewampDeclick* d, int n, int scan) {
    const int C = d->channels;
    for (int ch = 0; ch < C; ch++) {
        int nruns = 0;
        int i = 0;
        while (i < n && nruns < d->runsCap) {
            if (!d->flags[(size_t)i * C + ch]) { i++; continue; }
            int start = i, end = i;
            /* Étend: le prochain marqué à ≤ MERGE_GAP trames rejoint la course. */
            int j = i + 1;
            while (j < scan && j - end - 1 <= DK_MERGE_GAP) {
                if (d->flags[(size_t)j * C + ch]) end = j;
                j++;
            }
            i = end + 1;
            if (end - start + 1 > DK_MAX_RUN) continue;   /* pas un clic */
            if (!dk_is_junk(d, ch, DK_HISTORY + start, DK_HISTORY + end)) continue;
            d->runs[nruns * 2] = start; d->runs[nruns * 2 + 1] = end; nruns++;
        }
        for (int r = 0; r < nruns; r++) {
            const int start = d->runs[r * 2], end = d->runs[r * 2 + 1];
            const int len = end - start + 1;
            const int sStart = DK_HISTORY + start, sEnd = DK_HISTORY + end;
            float a = 0.0f, b = 0.0f;
            int haveA = 0, haveB = 0;
            if (sStart - 1 >= DK_HISTORY - d->historyValid) {
                a = d->stage[(size_t)(sStart - 1) * C + ch]; haveA = 1;
            }
            if (sEnd + 1 < DK_HISTORY + d->live) {
                b = d->stage[(size_t)(sEnd + 1) * C + ch]; haveB = 1;
            }
            if (!haveA && haveB) a = b;
            if (haveA && !haveB) b = a;

            float peak = 0.0f;
            for (int k = 0; k < len; k++) {
                float* p = &d->stage[(size_t)(sStart + k) * C + ch];
                float av = fabsf(*p);
                if (av > peak) peak = av;
                *p = a + (b - a) * (float)(k + 1) / (float)(len + 1);
            }
            if (d->repairCount < DK_LOG_MAX) {
                RewampDeclickRepair* rp = &d->log[d->repairCount];
                rp->frame   = d->totalFrames + (uint64_t)start;
                rp->channel = ch;
                rp->length  = len;
                rp->peak    = peak;
            }
            d->repairCount++;
        }
    }
}

/* Compte la musique sur les trames live [0, n) — APRÈS réparation, pour que
 * les déchets eux-mêmes ne comptent pas. */
static void dk_count_music(RewampDeclick* d, int n) {
    const int C = d->channels;
    const float* s = d->stage + (size_t)DK_HISTORY * C;
    for (int i = 0; i < n; i++) {
        for (int ch = 0; ch < C; ch++) {
            float v = s[(size_t)i * C + ch];
            d->blockSumSq += (double)v * v;
        }
        if (++d->blockCount >= DK_MUSIC_BLOCK) {
            double rms = sqrt(d->blockSumSq / ((double)d->blockCount * C));
            if (rms > DK_MUSIC_RMS) d->musicFrames += (uint64_t)d->blockCount;
            d->blockSumSq = 0.0;
            d->blockCount = 0;
        }
    }
    d->totalFrames += (uint64_t)n;
    if (d->musicFrames >= (uint64_t)(DK_MUSIC_SECS * d->sampleRate) ||
        d->totalFrames >= (uint64_t)(DK_CAP_SECS * d->sampleRate))
        d->armed = 0;
}

/* ---- lecture -------------------------------------------------------------- */

uint64_t rewamp_declick_read(RewampDeclick* d, float* out, uint64_t frames,
                             RewampDeclickSource src, void* user) {
    if (!d || !out || !src || frames == 0) return 0;
    const int C = d->channels;
    if (frames > 1u << 20) frames = 1u << 20;
    const int N = (int)frames;

    if (!d->armed) {
        /* Désarmé: vider l'étage d'abord (les trames lues en avance), puis
         * passer la main à la source sans copie. */
        uint64_t done = 0;
        if (d->live > 0) {
            int n = d->live < N ? d->live : N;
            memcpy(out, d->stage + (size_t)DK_HISTORY * C, (size_t)n * C * sizeof(float));
            d->live -= n;
            if (d->live > 0)
                memmove(d->stage + (size_t)DK_HISTORY * C,
                        d->stage + (size_t)(DK_HISTORY + n) * C,
                        (size_t)d->live * C * sizeof(float));
            done = (uint64_t)n;
        }
        if (done < frames && !d->eof)
            done += src(user, out + done * C, frames - done);
        return done;
    }

    if (!dk_ensure_stage(d, N + DK_LOOKAHEAD)) {
        d->armed = 0;
        return src(user, out, frames);
    }
    dk_fill(d, N + DK_LOOKAHEAD, src, user);

    int n = d->live < N ? d->live : N;
    if (n <= 0) { d->armed = 0; return 0; }

    /* Marque jusqu'à un peu au-delà de n pour qu'une course qui commence dans
     * la zone rendue et déborde soit réparée d'un bloc. */
    int scan = n + DK_MAX_RUN + DK_MERGE_GAP;
    if (scan > d->live) scan = d->live;
    dk_flag(d, scan);
    dk_repair(d, n, scan);
    dk_count_music(d, n);

    memcpy(out, d->stage + (size_t)DK_HISTORY * C, (size_t)n * C * sizeof(float));

    /* Décale: les n trames rendues deviennent (la fin de) l'historique. */
    memmove(d->stage, d->stage + (size_t)n * C,
            (size_t)(DK_HISTORY + d->live - n) * C * sizeof(float));
    d->live -= n;
    d->historyValid += n;
    if (d->historyValid > DK_HISTORY) d->historyValid = DK_HISTORY;
    return (uint64_t)n;
}
