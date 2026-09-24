// Furnace plugin — chiptune tracker engine (DivEngine) via the Modizer-authored
// FurnacePlayer wrapper. Handles .fur and the formats Furnace imports (.dmf/.dmp/…).
// Compiled only when REWAMP_WITH_FURNACE is defined.
#ifdef REWAMP_WITH_FURNACE

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"   // m_voice_buff / m_voice_current_ptr / vgm_last_*
#include "ModizerConstants.h"    // SOUND_BUFFER_SIZE_SAMPLE, SOUND_MAXVOICES_BUFFER_FX

#include <zlib.h>      // .dmf/.fur sont zlib-compressés: la magie est SOUS
#include "FurnacePlayer.h"   // third_party/furnace/src/modizer (added to include path)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>   // strcasecmp
#include <mutex>
#include <string>

// Furnace output is always stereo; pick a fixed device rate (miniaudio resamples).
static const int FURNACE_RATE = 44100;

// Per-voice oscilloscope ring size — matches rewamp_channel_data's default
// g_ring_write_size (RING_BUF_SAMPLES) so our writes line up with ring_read.
static const int FURNACE_RING = SOUND_BUFFER_SIZE_SAMPLE * 4 * 4;

struct RewampDecoder {
    FurnacePlayer* player;
    double         rate;
    int            subsong;
    int            voiceCount;  // furnace channels (capped to SOUND_MAXVOICES_BUFFER_FX)
    int16_t*       pcm;         // scratch int16 stereo buffer
    int            pcmFrames;
    int64_t        lastMuteMask; // applied generic_mute_mask snapshot
    // Pattern view (cached at open — constant per subsong).
    int            patOrders;   // getOrderCount()
    int            patRows;     // subsong patLen (same for every order)
    int            patChannels; // total channel count (NOT capped like voiceCount)
    int*           patEffRows;  // per-order EFFECTIVE rows (cut by 0B/0D/FF jumps)
    // Chemin NETTOYÉ (sans `?subsong=`) — la clé de mise en réserve à la
    // fermeture. Gardé ici parce que `close()` ne reçoit que le décodeur.
    char           path[4096];
};

// Furnace native ".fur" + the FamiTracker family it imports (.ftm and the
// 0CC/Dn/E-FamiTracker variants). NOT plain ".dmf": that extension is shared with
// X-Tracker (libopenmpt) — instead we claim DefleMask .dmf by its unambiguous
// header magic below, so real DefleMask files go to Furnace while X-Tracker .dmf
// (no magic match, ext not listed → score 0) stays with libopenmpt.
static const char* const kFurnaceExts[] = { "fur", "ftm", "0cc", "dnm", "eft", NULL };

/// La magie d'un fichier zlib-compressé, lue SOUS la compression.
///
/// ⚠️ **Un `.dmf` DefleMask est compressé** (`78 9c`), et un `.fur` Furnace
/// aussi: leur magie n'est donc PAS dans l'en-tête brut. Le probe ne voyait
/// que des octets deflate, rendait 0, et le fichier partait chez libopenmpt —
/// qui réclame `dmf` par extension pour le format X-Tracker, homonyme sans
/// rapport, et échouait à l'ouvrir. Résultat: aucun `.dmf` DefleMask ne jouait
/// (vérifié sur modland: les deux premiers essais commencent par `78 9c`).
///
/// On dépaquette donc les quelques octets nécessaires. C'est ce qui permet de
/// NE PAS mettre `dmf` dans la liste d'extensions: la magie décompressée est
/// sans ambiguïté, là où l'extension est partagée avec X-Tracker.
static bool furnace_inflate_magic(const uint8_t* hdr, size_t hdrSize,
                                  uint8_t* out, size_t outSize) {
    // En-tête zlib: 0x78 puis un octet de contrôle dont (CMF<<8|FLG) % 31 == 0.
    if (hdrSize < 2 || hdr[0] != 0x78) return false;
    if ((((unsigned)hdr[0] << 8) | hdr[1]) % 31 != 0) return false;

    z_stream zs;
    memset(&zs, 0, sizeof(zs));
    if (inflateInit(&zs) != Z_OK) return false;
    zs.next_in   = const_cast<Bytef*>(hdr);
    zs.avail_in  = (uInt)hdrSize;
    zs.next_out  = out;
    zs.avail_out = (uInt)outSize;
    // Z_OK (sortie pleine) et Z_STREAM_END (fichier minuscule) valent tous deux
    // succès; seul compte d'avoir produit assez d'octets pour la magie.
    const int rc = inflate(&zs, Z_NO_FLUSH);
    const bool ok = (rc == Z_OK || rc == Z_STREAM_END || rc == Z_BUF_ERROR) &&
                    zs.total_out >= outSize;
    inflateEnd(&zs);
    return ok;
}

static int furnace_probe(const char* ext, const uint8_t* hdr, size_t hdrSize) {
    // Header magics are decisive.
    if (hdr) {
        if (hdrSize >= 16 && memcmp(hdr, "-Furnace module-", 16) == 0) return 95;
        if (hdrSize >= 18 && memcmp(hdr, "FamiTracker Module", 18) == 0) return 95;
        if (hdrSize >= 21 && memcmp(hdr, "Dn-FamiTracker Module", 21) == 0) return 95;
        if (hdrSize >= 16 && memcmp(hdr, ".DelekDefleMask.", 16) == 0) return 95;
        // …et les mêmes magies SOUS zlib, qui est la forme courante des deux
        // formats (DefleMask compresse toujours, Furnace par défaut).
        uint8_t magic[21];
        if (furnace_inflate_magic(hdr, hdrSize, magic, sizeof(magic))) {
            if (memcmp(magic, ".DelekDefleMask.", 16) == 0) return 95;
            if (memcmp(magic, "-Furnace module-", 16) == 0) return 95;
            if (memcmp(magic, "Dn-FamiTracker Module", 21) == 0) return 95;
            if (memcmp(magic, "FamiTracker Module", 18) == 0) return 95;
        }
    }
    return (ext && rewamp_ext_in_list(ext, kFurnaceExts)) ? 70 : 0;
}

// ⚠️ DivEngine s'initialise par INSTANCE, et deux instances sont
// indépendantes (`systemsRegistered`/`romExportsRegistered` sont des membres,
// et `engine.cpp` n'a aucun global) — SAUF le fichier de log. `preInit` appelle
// `startLogFile`, qui se garde sur `logFileAvail`: un `std::atomic<bool>`, mais
// testé PUIS posé, donc deux inits simultanés peuvent tous deux le lire à faux,
// faire tourner la rotation de fichiers et ouvrir le log deux fois.
//
// Le cas n'est pas théorique chez nous: la SONDE tourne sur le fil Dart pendant
// que le relais gapless ouvre le morceau suivant sur le fil PRODUCTEUR. On
// sérialise donc les seules initialisations de DivEngine du binaire — elles
// sont courtes, et c'est la seule fenêtre partagée.
static std::mutex s_furnace_init_mtx;

// Furnace pose `logLevel = LOGLEVEL_TRACE` en dur (log.cpp, « until done »):
// une ouverture de module déverse alors des centaines de lignes sur la sortie
// standard. C'est le réglage d'un TRACKER qu'on lance à la main, pas d'un
// lecteur qui ouvre des modules en arrière-plan. Posé une fois, sous le même
// verrou que l'init.
// `logLevel` vit dans `furnace/src/ta-log.h`, qui n'est PAS sur le chemin
// d'inclusion de ce fichier (seuls `src/momo`, `src/icon` et `src/modizer` y
// sont) — et l'y ajouter exposerait des en-têtes aux noms très génériques
// (`engine.h`, `song.h`…) à tout le pod. On redéclare donc le symbole: c'est un
// `int` global de C++, la liaison est la même des deux côtés.
extern int logLevel;
#define FURNACE_LOGLEVEL_ERROR 0   // ta-log.h

// ── Cache d'UN module chargé ─────────────────────────────────────────────────
//
// Mesuré sur « Shovel Knight » (.ftm, macOS): `init` 0,8 ms, `select` 0,0 ms,
// **`load` 900 ms**. Or changer de sous-chanson passe par un `open()` complet,
// donc rechargeait le module entier pour un travail qui coûte zéro. Le parseur
// FTM tourne en plus sur un fil à 8 Mo de pile (il déborde la pile normale),
// ce qui explique l'ordre de grandeur.
//
// On garde donc le DERNIER lecteur, clefé par son chemin, au lieu de le
// détruire. Un `open()` sur le même fichier le reprend et ne fait plus qu'un
// `selectSong`.
//
// ⚠️ UNE seule place, et le lecteur en est RETIRÉ quand on le reprend: deux
// décodeurs vivants sur le même module sont exactement ce que le relais gapless
// interdit (il ferme N avant d'ouvrir N+1, précisément pour les moteurs qui ne
// supportent pas deux instances). Le cache ne peut donc pas en fabriquer un
// second.
//
// ⚠️ On ne `close()` PAS le lecteur mis en réserve — `close()` DÉCHARGE le
// module, ce qui annulerait tout l'intérêt.
static FurnacePlayer* s_cached_player = NULL;
static char           s_cached_path[4096] = { 0 };

// Reprend le lecteur en réserve s'il porte ce chemin, sinon NULL. Le mutex
// couvre l'accès: la sonde tourne sur le fil Dart, l'ouverture sur le fil
// producteur.
static FurnacePlayer* furnace_cache_take(const char* path) {
    std::lock_guard<std::mutex> lk(s_furnace_init_mtx);
    if (!s_cached_player || strcmp(s_cached_path, path) != 0) return NULL;
    FurnacePlayer* p = s_cached_player;
    s_cached_player = NULL;
    s_cached_path[0] = '\0';
    return p;
}

// Met un lecteur CHARGÉ en réserve. Celui qui s'y trouvait est détruit.
static void furnace_cache_put(FurnacePlayer* player, const char* path) {
    FurnacePlayer* evicted = NULL;
    {
        std::lock_guard<std::mutex> lk(s_furnace_init_mtx);
        evicted = s_cached_player;
        s_cached_player = player;
        strncpy(s_cached_path, path, sizeof(s_cached_path) - 1);
        s_cached_path[sizeof(s_cached_path) - 1] = '\0';
    }
    if (evicted) { evicted->stop(); evicted->close(); delete evicted; }
}

static void furnace_quiet_logs_once() {
    static bool done = false;
    if (done) return;
    done = true;
    logLevel = FURNACE_LOGLEVEL_ERROR;
}

static RewampDecoder* furnace_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    // Strip optional ?subsong=N suffix; keep the real path for fopen.
    char clean[4096];
    int subsong = 0;
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }

    // Read the whole file into memory (FurnacePlayer::load takes a buffer).
    FILE* f = fopen(clean, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0) { fclose(f); return NULL; }
    uint8_t* data = (uint8_t*)malloc((size_t)len);
    if (!data) { fclose(f); return NULL; }
    size_t got = fread(data, 1, (size_t)len, f);
    fclose(f);
    if (got != (size_t)len) { free(data); return NULL; }

    // Même module que la dernière fois ? On reprend le lecteur en réserve: le
    // rechargement coûte ~900 ms, la sélection zéro.
    FurnacePlayer* player = furnace_cache_take(clean);
    const bool reused = (player != NULL);

    if (!reused) {
        player = new FurnacePlayer();
        bool ok;
        {
            std::lock_guard<std::mutex> lk(s_furnace_init_mtx);
            furnace_quiet_logs_once();
            ok = player->init(FURNACE_RATE);
        }
        if (!ok || !player->load(data, (size_t)len, clean)) {
            free(data);
            delete player;
            return NULL;
        }
    }
    free(data);

    // Inconditionnel sur un lecteur REPRIS: il est resté sur la sous-chanson
    // précédente, et `selectSong` est aussi ce qui remet la lecture à son
    // début (`changeSongP` + `play`).
    if (subsong > 0 || reused) player->selectSong(subsong);

    FurnaceSongInfo info = player->getInfo();
    int voices = info.channels;
    if (voices < 1) voices = 2;
    if (voices > SOUND_MAXVOICES_BUFFER_FX) voices = SOUND_MAXVOICES_BUFFER_FX;
    // Per-channel oscilloscope buffers must exist before the first render.
    rewamp_channel_data_reset(voices);

    // Voice metadata for the mute/grouping UI (after reset — it wipes the
    // tables): one group per Furnace system slot, channel names from the
    // engine (e.g. "FM 1", "PSG 2").
    rewamp_voices_meta_reset();
    const int sysCount = player->getSystemCount();
    if (sysCount > 0) {
        for (int s = 0; s < sysCount; s++) {
            FurnaceSystemInfo si = player->getSystemInfo(s);
            if (si.channelCount <= 0 || si.firstChannel < 0 ||
                si.firstChannel >= voices)
                continue;
            int cnt = si.channelCount;
            if (si.firstChannel + cnt > voices) cnt = voices - si.firstChannel;
            rewamp_voices_add_chip(
                (si.name && si.name[0]) ? si.name : "Chip",
                si.firstChannel, cnt);
        }
    } else {
        rewamp_voices_add_chip("Furnace", 0, voices);
    }
    for (int i = 0; i < voices; i++) {
        const char* cn = player->getChannelShortName(i);
        if (cn && cn[0]) rewamp_voice_set_name(i, cn);
    }

    // Info panel: Furnace song metadata.
    if (!info.title.empty())
        rewamp_track_message_append("Title: %s\n", info.title.c_str());
    if (!info.author.empty())
        rewamp_track_message_append("Author: %s\n", info.author.c_str());
    if (!info.systemName.empty())
        rewamp_track_message_append("System: %s\n", info.systemName.c_str());
    if (info.subsongCount > 1) {
        rewamp_track_message_append("Subsongs: %d\n", info.subsongCount);
        if (!info.subsongName.empty())
            rewamp_track_message_append("Subsong: %s\n",
                                        info.subsongName.c_str());
    }
    rewamp_track_message_append("Channels: %d\n", info.channels);
    if (!info.comment.empty())
        rewamp_track_message_append("\n%s\n", info.comment.c_str());

    player->setPlaying(true);

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { delete player; return NULL; }
    dec->player     = player;
    dec->rate       = FURNACE_RATE;
    dec->subsong    = subsong;
    strncpy(dec->path, clean, sizeof(dec->path) - 1);
    dec->path[sizeof(dec->path) - 1] = '\0';
    dec->voiceCount = voices;
    dec->pcm        = NULL;
    dec->pcmFrames  = 0;

    // Pattern-view geometry. Nominally every order is patLen rows, but a jump
    // effect (0Dxx break-to-next, 0Bxx jump-to-order, FFxx stop) cuts the order
    // short — the cursor leaves at that row and the tail never plays. The
    // pattern timeline must use the EFFECTIVE length, otherwise the view shows
    // the dead tail instead of the (dimmed) next pattern and the scroll leaps
    // when the cursor jumps (user-visible bug on break-heavy .fur files).
    dec->patOrders = player->getOrderCount();
    if (dec->patOrders > 0) {
        dec->patEffRows = (int*)malloc((size_t)dec->patOrders * sizeof(int));
        if (!dec->patEffRows) dec->patOrders = 0;
    }
    for (int o = 0; o < dec->patOrders; o++) {
        int rows = 0, chans = 0;
        FurnacePatternNote* buf = player->getOrderPattern(o, &rows, &chans);
        if (!buf) { dec->patOrders = o; break; }   /* keep what we scanned */
        if (o == 0) { dec->patRows = rows; dec->patChannels = chans; }
        int eff = rows;
        for (int r = 0; r < rows && eff == rows; r++)
            for (int c = 0; c < chans && eff == rows; c++) {
                const FurnacePatternNote* n = &buf[r * chans + c];
                for (int e = 0; e < 4; e++) {
                    int fx = n->fx[e];
                    if (fx == 0x0B || fx == 0x0D || fx == 0xFF) { eff = r + 1; break; }
                }
            }
        dec->patEffRows[o] = eff;
        delete[] buf;
    }
    if (dec->patOrders > 0 && dec->patChannels <= 0) dec->patOrders = 0;

    outFormat->channels   = 2;
    outFormat->sampleRate = (uint32_t)FURNACE_RATE;
    return dec;
}

// Feed the per-voice oscilloscope ring + note state from Furnace's introspection
// API, mirroring Modizer. The datasource then drives rewamp_notes_capture /
// rewamp_channel_data_capture_delayed off these globals (same as the libvgm cores
// do inline). Called once per render with the just-produced frame count.
static void furnace_capture_voices(RewampDecoder* dec, int frames) {
    FurnacePlayer* pl = dec->player;
    const int nv = dec->voiceCount;

    // Furnace osc buffers run at a fixed 65536 Hz; map that window onto our frames.
    const float oscPerFrame = (float)FurnaceOscData::OSC_RATE / (float)FURNACE_RATE;
    const int   oscWindow   = (int)(frames * oscPerFrame) + 2;

    for (int j = 0; j < nv; j++) {
        signed char* buf = m_voice_buff[j];
        if (!buf) continue;
        const int64_t base = m_voice_current_ptr[j] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT;

        FurnaceOscData osc = pl->getOscData(j);
        if (osc.valid && osc.data) {
            short lastValid = 0;
            const unsigned short baseIdx = (unsigned short)(osc.readPos - oscWindow);
            for (int i = 0; i < frames; i++) {
                int slotStart = (int)(i       * oscPerFrame);
                int slotEnd   = (int)((i + 1) * oscPerFrame);
                if (slotEnd == slotStart) slotEnd = slotStart + 1;
                // Average the valid osc slots covering this display frame
                // (-1 is Furnace's "no sample" sentinel).
                int sum = 0, count = 0;
                for (int s = slotStart; s < slotEnd; s++) {
                    short v = osc.data[(unsigned short)(baseIdx + s)];
                    if (v != -1) { sum += v; count++; }
                }
                short sample;
                if (count > 0) {
                    sample = (short)(sum / count);
                    lastValid = sample;
                } else {
                    sample = -1;
                    for (int d = slotEnd; d < slotEnd + 3 && sample == -1; d++) {
                        short v = osc.data[(unsigned short)(baseIdx + d)];
                        if (v != -1) sample = v;
                    }
                    if (sample == -1) sample = lastValid; else lastValid = sample;
                }
                buf[(int)(((base + i) % FURNACE_RING + FURNACE_RING) % FURNACE_RING)] =
                    (signed char)(sample >> 8);
            }
        } else {
            for (int i = 0; i < frames; i++)
                buf[(int)(((base + i) % FURNACE_RING + FURNACE_RING) % FURNACE_RING)] = 0;
        }
        m_voice_current_ptr[j] += (int64_t)frames << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
    }

    // Note state (Hz / volume / instrument) → rewamp_notes_capture reads these.
    // Clear on silence so released notes don't linger as ghost notes.
    for (int j = 0; j < nv; j++) {
        FurnaceChannelLiveState st = pl->getChannelLiveState(j);
        if (st.active && st.note >= 0 && st.volume > 0) {
            vgm_last_note[j]  = (unsigned int)st.freqHz;
            vgm_last_vol[j]   = (unsigned int)st.volume;
            vgm_last_instr[j] = (unsigned char)(st.instrument > 0 ? st.instrument : 0);
        } else {
            vgm_last_note[j] = 0;
            vgm_last_vol[j]  = 0;
        }
    }
}

static uint64_t furnace_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->player || !out || frameCount == 0) return 0;
    if (dec->player->isEndOfSong()) return 0;

    // Apply voice-mute changes from the UI (Modizer: furPlayer->setMute).
    if (dec->lastMuteMask != generic_mute_mask) {
        dec->lastMuteMask = generic_mute_mask;
        for (int ch = 0; ch < dec->voiceCount && ch < 64; ch++)
            dec->player->setMute(ch, ((generic_mute_mask >> ch) & 1) != 0);
    }

    if ((int)frameCount > dec->pcmFrames) {
        free(dec->pcm);
        dec->pcm = (int16_t*)malloc(frameCount * 2 * sizeof(int16_t));
        dec->pcmFrames = (int)frameCount;
    }
    if (!dec->pcm) return 0;

    dec->player->render(dec->pcm, (int)frameCount);

    furnace_capture_voices(dec, (int)frameCount);

    const int samples = (int)(frameCount * 2);
    const float inv = 1.0f / 32768.0f;
    for (int i = 0; i < samples; i++) out[i] = dec->pcm[i] * inv;
    return frameCount;
}

static void furnace_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->player) return;
    /* ⚠️ **Un seek ne relance pas un morceau TERMINÉ.** `FurnacePlayer::seek`
     * ne fait qu'un `engine->setOrder(...)`; il ne remet pas le moteur en
     * marche. Or `furnace_read` sort immédiatement sur `isEndOfSong()`, qui
     * vaut `!userStopped && !engine->isPlaying()` — donc vrai tant que le
     * moteur n'a pas été redémarré. Une fois le morceau fini, tout seek en
     * arrière rendait un décodeur muet.
     *
     * Le greffon n'a pas de boucle native (`configure_loop` est NULL), donc
     * c'est le repli générique de Dart qui relance par `seek(0)` + `play()`:
     * sans ce redémarrage, la boucle infinie ne pouvait pas fonctionner.
     * Même panne que vgmstream, autre bibliothèque.
     *
     * `setPlaying(true)` appelle `engine->play()`. On ne le fait QUE si le
     * morceau était terminé — un seek en cours de lecture ne doit rien
     * changer à l'état du moteur. */
    const bool wasEnded = dec->player->isEndOfSong();
    dec->player->seek((double)frameIndex / dec->rate);
    if (wasEnded) dec->player->setPlaying(true);
}

static uint64_t furnace_length(RewampDecoder* dec) {
    if (!dec || !dec->player) return 0;
    // ⚠️ `getDuration()`, PAS `getTotalDuration()`: le second SOMME toutes les
    // sous-chansons du module (`for i in count: total += …`). Un `.ftm`
    // FamiTracker à une dizaine de morceaux annonçait donc 105:10 pour la
    // piste en cours. Les deux noms se ressemblent et rendent un double de
    // secondes; seul celui-ci décrit ce qu'on joue.
    double secs = dec->player->getDuration();
    if (secs <= 0) return 0;
    return (uint64_t)(secs * dec->rate);
}

static void furnace_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->player) {
        // En RÉSERVE plutôt qu'à la poubelle: la sous-chanson suivante du même
        // module fait un `open()`, et c'est le `load` (~900 ms) qu'on évite.
        // Pas de `close()` ici — il déchargerait justement le module.
        dec->player->stop();
        furnace_cache_put(dec->player, dec->path);
    }
    free(dec->patEffRows);
    free(dec->pcm);
    free(dec);
}

// ── Tracker-pattern view ─────────────────────────────────────────────────────
// Furnace's order list maps a pattern PER CHANNEL (ord[c][order]), so there is
// no song-global "pattern index": the viewable unit IS the order. We expose
// pattern == order (identity mapping) and convert lazily per fetch — the GL
// renderer only asks for the handful of orders in its window, and the calls
// arrive under decodeLock (rewamp_audio.c) so they never race the engine.

static int furnace_pattern_song_info(RewampDecoder* dec, RewampPatternSongInfo* out) {
    if (!dec || !out || !dec->player || dec->patOrders <= 0 ||
        dec->patChannels <= 0)
        return 0;
    out->num_channels = dec->patChannels;
    out->num_orders   = dec->patOrders;
    out->num_patterns = dec->patOrders;   /* identity: pattern == order */
    out->max_fx_cols  = 4;                /* FurnacePatternNote fx[4] */
    return 1;
}

static int furnace_pattern_order(RewampDecoder* dec, int order) {
    if (!dec || order < 0 || order >= dec->patOrders) return -1;
    return order;
}

static int furnace_pattern_num_rows(RewampDecoder* dec, int pattern) {
    if (!dec || pattern < 0 || pattern >= dec->patOrders) return 0;
    /* EFFECTIVE rows (cut at the first jump effect) — what actually plays. */
    return dec->patEffRows ? dec->patEffRows[pattern] : dec->patRows;
}

static int furnace_pattern_get(RewampDecoder* dec, int pattern,
                               RewampPatternCell* out, int maxCells) {
    if (!dec || !out || !dec->player || pattern < 0 || pattern >= dec->patOrders)
        return 0;
    int rows = 0, chans = 0;
    FurnacePatternNote* src = dec->player->getOrderPattern(pattern, &rows, &chans);
    if (!src) return 0;
    int n = rows * chans;
    if (n > maxCells) n = maxCells;
    static const char* H = "0123456789ABCDEF";
    for (int i = 0; i < n; i++) {
        const FurnacePatternNote* s = &src[i];
        RewampPatternCell* c = &out[i];
        memset(c, 0, sizeof(*c));
        // Furnace pattern notes share our semitone origin (playback.cpp:
        // note = patNote - 60, calcBaseFreq → pattern 57 = A-4 = generic 57).
        if      (s->note == 253) c->note = REWAMP_NOTE_OFF;
        else if (s->note == 254) c->note = REWAMP_NOTE_FADE;   /* release */
        else if (s->note >= 0 && s->note <= 179) c->note = s->note;
        else c->note = REWAMP_NOTE_EMPTY;
        c->instrument = (s->instrument >= 0) ? s->instrument : -1;
        c->volume     = (s->volume     >= 0) ? s->volume     : -1;
        int nfx = 0;
        for (int e = 0; e < 4; e++) {
            if (s->fx[e] < 0) continue;
            /* Furnace displays the effect code as 2 hex digits. */
            c->fx[nfx][0]  = H[(s->fx[e] >> 4) & 15];
            c->fx[nfx][1]  = H[s->fx[e] & 15];
            c->fxval[nfx]  = (s->fxVal[e] >= 0) ? s->fxVal[e] : -1;
            nfx++;
        }
        c->num_fx = (uint8_t)nfx;
        for (int e = nfx; e < REWAMP_PATTERN_MAX_FX; e++) c->fxval[e] = -1;
    }
    delete[] src;
    return n;
}

static void furnace_pattern_cursor(RewampDecoder* dec, int* order, int* row) {
    /* Producer thread, under decodeLock, right after read() — reflects the
     * just-decoded position (consumer sync happens in the cursor store). */
    if (order) *order = (dec && dec->player) ? dec->player->getCurrentOrder() : -1;
    if (row)   *row   = (dec && dec->player) ? dec->player->getCurrentRow()   : -1;
}

static const RewampPluginVTable kFurnaceVTable = {
    "furnace",
    furnace_probe,
    furnace_open,
    furnace_read,
    furnace_seek,
    furnace_length,
    furnace_close,
    NULL,                    /* configure_loop */
    0,                       /* supportsNativeFadeout */
    NULL,                    /* engine_id */
    NULL,                    /* param_changed */
    furnace_pattern_song_info,  /* pattern view */
    furnace_pattern_order,
    furnace_pattern_num_rows,
    furnace_pattern_get,
    furnace_pattern_cursor,
};

extern "C" const RewampPluginVTable* rewamp_furnace_plugin(void) { return &kFurnaceVTable; }

// ── Sonde de sous-chansons — cache statique lu par les accesseurs ────────────
//
// Un `.ftm` FamiTracker porte couramment une dizaine de morceaux, et Furnace
// les importe en SOUS-CHANSONS. Le décodeur savait déjà en jouer une
// (`?subsong=N` → `selectSong`) et le panneau ⓘ annonçait leur nombre, mais
// `rewamp_probe_subsong_count` n'avait aucune branche Furnace: il rendait donc
// le compte d'un AUTRE moteur, ou 1. Vu de l'utilisateur, un module à dix
// morceaux n'en proposait aucun et s'entendait comme une piste unique qui les
// enchaîne.
//
// ⚠️ Garde d'EXTENSION obligatoire, contrairement aux branches openmpt et
// zxtune qui se contentent d'essayer d'ouvrir: initialiser DivEngine et
// charger le module coûte cher, et cette fonction est appelée sur des fichiers
// que Furnace n'a aucune raison de revendiquer.

#define FURNACE_PROBE_MAX 256

static int  s_fprobe_count = 0;
static char s_fprobe_titles[FURNACE_PROBE_MAX][256];
static int  s_fprobe_durations_ms[FURNACE_PROBE_MAX];
// Dernier chemin sondé, pour ne pas recharger le module deux fois de suite:
// l'ouverture locale demande le COMPTE puis les TITRES (deux appels d'affilée
// sur le même fichier), ce qui est gratuit chez libgme mais vaut deux
// initialisations de DivEngine ici.
static char s_fprobe_path[4096] = { 0 };

extern "C" int rewamp_furnace_probe_subsong_info(const char* path) {
    if (!path) { s_fprobe_count = 0; s_fprobe_path[0] = '\0'; return 0; }

    char clean[4096];
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) *q = '\0';

    // Même fichier que l'appel précédent: le cache est encore bon.
    if (s_fprobe_count > 0 && strcmp(s_fprobe_path, clean) == 0)
        return s_fprobe_count;

    s_fprobe_count = 0;
    s_fprobe_path[0] = '\0';

    const char* dot = strrchr(clean, '.');
    if (!dot || !rewamp_ext_in_list(dot + 1, kFurnaceExts)) return 0;

    FILE* f = fopen(clean, "rb");
    if (!f) return 0;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0) { fclose(f); return 0; }
    uint8_t* data = (uint8_t*)malloc((size_t)len);
    if (!data) { fclose(f); return 0; }
    size_t got = fread(data, 1, (size_t)len, f);
    fclose(f);
    if (got != (size_t)len) { free(data); return 0; }

    FurnacePlayer* player = new FurnacePlayer();
    bool ok;
    {
        std::lock_guard<std::mutex> lk(s_furnace_init_mtx);
        furnace_quiet_logs_once();
        ok = player->init(FURNACE_RATE);
    }
    if (!ok || !player->load(data, (size_t)len, clean)) {
        free(data);
        delete player;
        return 0;
    }
    free(data);

    int count = player->getInfo().subsongCount;
    if (count < 1) count = 1;
    if (count > FURNACE_PROBE_MAX) count = FURNACE_PROBE_MAX;

    // Noms ET durées. Mesuré: `selectSong` 0,0 ms et `getDuration()` (donc
    // `calcSongTimestamps`) sous la milliseconde — la lenteur initialement
    // attribuée à ce calcul venait en réalité du déluge de `printf` de Furnace,
    // chacun passant par `fmt::sprintf`. Une fois les journaux coupés, une
    // durée par sous-chanson est gratuite, et c'est elle qui évite d'afficher
    // « -- » jusqu'à ce que chaque sous-chanson ait été jouée une fois.
    for (int i = 0; i < count; i++) {
        s_fprobe_titles[i][0]    = '\0';
        s_fprobe_durations_ms[i] = -1;
        // `getSubsongName` LIT le nom sans sélectionner — inutile de payer un
        // `changeSongP` + `play` juste pour une chaîne.
        const std::string nm = player->getSubsongName(i);
        if (!nm.empty()) {
            strncpy(s_fprobe_titles[i], nm.c_str(),
                    sizeof(s_fprobe_titles[i]) - 1);
            s_fprobe_titles[i][sizeof(s_fprobe_titles[i]) - 1] = '\0';
        }
        // La durée, elle, EXIGE la sélection: les timestamps sont calculés pour
        // la sous-chanson courante.
        if (player->selectSong(i)) {
            const double secs = player->getDuration();
            if (secs > 0) s_fprobe_durations_ms[i] = (int)(secs * 1000.0);
        }
    }

    // En RÉSERVE, pas à la poubelle: la lecture qui suit la sonde vise le même
    // fichier, et c'est le `load` (~900 ms) qu'on lui épargne.
    player->stop();
    furnace_cache_put(player, clean);

    s_fprobe_count = count;
    strncpy(s_fprobe_path, clean, sizeof(s_fprobe_path) - 1);
    s_fprobe_path[sizeof(s_fprobe_path) - 1] = '\0';
    return count;
}

extern "C" const char* rewamp_furnace_probe_get_title(int idx) {
    if (idx < 0 || idx >= s_fprobe_count) return "";
    return s_fprobe_titles[idx];
}

extern "C" int rewamp_furnace_probe_get_duration_ms(int idx) {
    if (idx < 0 || idx >= s_fprobe_count) return -1;
    return s_fprobe_durations_ms[idx];
}

#endif /* REWAMP_WITH_FURNACE */
