/* SNDH plugin — Atari ST .sndh chiptunes via the vendored AtariAudio library
 * (Arnaud Carré / Leonard, third_party/atariaudio, v1.27: 68000 emulation via
 * its own thread-safe Musashi + cycle-accurate YM2149 + STE DAC + blitter).
 * Mono output; miniaudio mirrors it to stereo.
 *
 * Per-voice scope + notes live in the patched cores (grep REWAMP in
 * third_party/atariaudio): ym2149c.cpp fills m_voice_buff[0..2] for the PSG
 * channels, AtariMachine.cpp voice 3 for the STE DAC. Mute is the library's
 * own MuteVoices, fed from generic_mute_mask (same bit order: A, B, C, DAC).
 *
 * Durations: the library's (FRMS, else its embedded timedb, else TIME); a
 * subsong with no known duration plays until the app moves on. Per-subsong
 * titles (!#SN) are no longer parsed by the library — read here.
 *
 * ICE-packed .sndh are depacked by SndhRenderer::Create. Since 1.10 the
 * library keeps no global CPU state, so the subsong probe runs its own
 * instance. */
#ifdef REWAMP_WITH_SNDH

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

#include "AtariAudio.h"           /* SndhRenderer, YmRenderer + ATARI_AUDIO_VERSION */
#include "external/lzh.h"         /* LzhDepacker::IsLzhPacked, for the .ym probe */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <string>
#include <vector>

#define SNDH_RATE      44100
#define SNDH_VOICES    4   /* YM2149 A, B, C + STE DAC */
/* The patched cores mask their ring writes with SOUND_BUFFER_SIZE_SAMPLE*4*2-1:
 * the scope's trigger search needs outLen + TRIGGER_SEARCH_LEN ≈ 2212 samples
 * of history (rewamp_channel_data.c) — a bare SOUND_BUFFER_SIZE_SAMPLE ring
 * leaves it nothing to search and the scope never locks phase. */
#define SNDH_RING_SIZE (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)

namespace {

/* ⚠️ Not `struct RewampDecoder`: it owns a std::vector, and an implicit
 * destructor is a weak symbol the linker merges with another plugin's (ODR) —
 * every plugin keeps its state in its own type. */
struct SndhDec {
    SndhRenderer* sndh = nullptr;
    int      subsongId = 1;     /* 1-based, SNDH's own convention */
    uint64_t framePos = 0;
    uint64_t totalFrames = 0;   /* one pass; 0 = unknown (never ends) */
    double   speed = 1.0;       /* native playback speed */
    double   posFrac = 0.0;
    int64_t  muteApplied = -1;
    std::vector<int16_t> buf;
};

/* ⚠️ SndhRenderer DECLARES GetSongInfo() but never defines it (1.27): called
 * through it, the link fails. The base class defines it inline — call it
 * there. */
const AtariAudioRenderer::SongInfo& song_info(const SndhRenderer* r) {
    return static_cast<const AtariAudioRenderer*>(r)->GetSongInfo();
}

bool read_file(const char* path, std::vector<uint8_t>& out) {
    FILE* f = fopen(path, "rb");
    if (!f) return false;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0 || len > 16 * 1024 * 1024) { fclose(f); return false; }
    out.resize((size_t)len);
    const size_t got = fread(out.data(), 1, (size_t)len, f);
    fclose(f);
    return got == (size_t)len;
}

/* Strip ?subsong=N; returns N (0 if absent). */
int split_subsong(const char* path, char* clean, size_t cap) {
    strncpy(clean, path, cap - 1);
    clean[cap - 1] = '\0';
    char* q = strrchr(clean, '?');
    int sub = 0;
    if (q && strncmp(q, "?subsong=", 9) == 0) sub = atoi(q + 9);
    if (q) *q = '\0';
    return sub;
}

/* Per-subsong titles: the !#SN tag (a word table of offsets, on an EVEN
 * address, then the NUL-terminated names in order). 1.27 skips it. */
std::vector<std::string> subsong_titles(const AtariAudioRenderer::SongInfo& si) {
    std::vector<std::string> out;
    const char* base = (const char*)si.rawBinaryData;
    const size_t size = si.rawBinaryDataSize;
    if (!base || size < 16 || si.subsongCount <= 0) return out;
    int headerSize = ((uint8_t)base[2] << 8 | (uint8_t)base[3]) + 2;   /* bra.w */
    if (base[1]) headerSize = (uint8_t)base[1] + 2;                    /* bra.s */
    const size_t end = (size_t)headerSize < size ? (size_t)headerSize : size;
    for (size_t i = 16; i + 4 <= end; i++) {
        if (memcmp(base + i, "HDNS", 4) == 0) break;
        if (memcmp(base + i, "!#SN", 4) != 0) continue;
        size_t p = i + 4;
        if (p & 1) p++;
        p += (size_t)si.subsongCount * 2;
        for (int s = 0; s < si.subsongCount && p < size; s++) {
            const char* t = base + p;
            const size_t n = strnlen(t, size - p);
            out.emplace_back(t, n);
            p += n + 1;
        }
        break;
    }
    return out;
}

int sndh_probe(const char* ext, const uint8_t* header, size_t headerSize) {
    const int extMatch = ext && strcmp(ext, "sndh") == 0;
    /* Uncompressed files carry "SNDH" at offset 12; ICE-packed ones start
     * with "ICE!" (depacked by Create, too costly to verify here). */
    if (header && headerSize >= 16 && 0 == memcmp(header + 12, "SNDH", 4))
        return extMatch ? 100 : 90;
    if (header && headerSize >= 4 && 0 == memcmp(header, "ICE!", 4))
        return extMatch ? 95 : 40;
    return extMatch ? 90 : 0;
}

void sndh_close_fn(RewampDecoder* rd);

RewampDecoder* sndh_open_fn(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return nullptr;
    char clean[4096];
    const int subsong = split_subsong(path, clean, sizeof(clean));
    std::vector<uint8_t> data;
    if (!read_file(clean, data)) return nullptr;

    SndhDec* d = new SndhDec();
    d->sndh = SndhRenderer::Create(data.data(), (uint32_t)data.size(), SNDH_RATE);
    if (!d->sndh) { delete d; return nullptr; }
    const AtariAudioRenderer::SongInfo& si = song_info(d->sndh);
    d->subsongId = (subsong > 0 && subsong <= si.subsongCount) ? subsong : si.defaultSubsong;
    if (!d->sndh->InitSubSong(d->subsongId, false)) {
        sndh_close_fn(reinterpret_cast<RewampDecoder*>(d));
        return nullptr;
    }
    d->totalFrames = d->sndh->GetSubsongDurationSample(d->subsongId);

    /* Ring buffers BEFORE rendering: the patched cores write m_voice_buff
     * inline (circular, masked to SNDH_RING_SIZE-1). */
    rewamp_channel_data_reset(SNDH_VOICES);
    rewamp_channel_data_set_ring_write_size(SNDH_RING_SIZE);
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("YM2149", 0, 3);
    rewamp_voices_add_chip("STE DAC", 3, 1);
    rewamp_voice_set_name(0, "PSG A");
    rewamp_voice_set_name(1, "PSG B");
    rewamp_voice_set_name(2, "PSG C");
    rewamp_voice_set_name(3, "DAC");

    /* Info panel. */
    const std::vector<std::string> titles = subsong_titles(si);
    if (si.musicName && si.musicName[0])
        rewamp_track_message_append("Title: %s\n", si.musicName);
    if (d->subsongId - 1 < (int)titles.size() && !titles[d->subsongId - 1].empty())
        rewamp_track_message_append("Subtitle: %s\n", titles[d->subsongId - 1].c_str());
    if (si.musicAuthor && si.musicAuthor[0])
        rewamp_track_message_append("Author: %s\n", si.musicAuthor);
    if (si.year && si.year[0])
        rewamp_track_message_append("Year: %s\n", si.year);
    if (si.ripper && si.ripper[0])
        rewamp_track_message_append("Ripper: %s\n", si.ripper);
    if (si.converter && si.converter[0])
        rewamp_track_message_append("Converter: %s\n", si.converter);
    rewamp_track_message_append("Player rate: %dHz\nSubsongs: %d\nEngine: AtariAudio %s\n",
                                si.playerTickRate, si.subsongCount, ATARI_AUDIO_VERSION);

    if (outFormat) {
        outFormat->channels   = 1;
        outFormat->sampleRate = SNDH_RATE;
    }
    return reinterpret_cast<RewampDecoder*>(d);
}

uint64_t sndh_read_fn(RewampDecoder* rd, float* out, uint64_t frameCount) {
    SndhDec* d = reinterpret_cast<SndhDec*>(rd);
    if (!d || !d->sndh || frameCount == 0) return 0;
    /* Mute: the library's own, same bit order as generic_mute_mask. It is
     * reset by InitSubSong, hence the -1 start. */
    if (d->muteApplied != generic_mute_mask) {
        d->sndh->MuteVoices((uint32_t)(generic_mute_mask & 0xF));
        d->muteApplied = generic_mute_mask;
    }
    /* One pass, then EOF: the library loops forever by itself. framePos is
     * in SONG time (speed × rendered), so is the cap. */
    uint64_t want = frameCount;
    if (d->totalFrames > 0) {
        if (d->framePos >= d->totalFrames) return 0;
        const double sp = d->speed > 0.0 ? d->speed : 1.0;
        const uint64_t leftOut = (uint64_t)((double)(d->totalFrames - d->framePos) / sp) + 1;
        if (want > leftOut) want = leftOut;
    }
    if (d->buf.size() < want) d->buf.resize((size_t)want);
    d->sndh->AudioRender(d->buf.data(), (uint32_t)want);
    const float scale = 1.0f / 32768.0f;
    for (uint64_t i = 0; i < want; i++) out[i] = d->buf[(size_t)i] * scale;
    d->posFrac += (double)want * (d->speed > 0.0 ? d->speed : 1.0);
    const uint64_t whole = (uint64_t)d->posFrac;
    d->posFrac -= (double)whole;
    d->framePos += whole;
    return want;
}

extern "C" volatile int    g_seek_cancel;
extern "C" volatile int    g_is_seeking;
extern "C" volatile double g_seek_progress_s;

void sndh_seek_fn(RewampDecoder* rd, uint64_t frameIndex) {
    SndhDec* d = reinterpret_cast<SndhDec*>(rd);
    if (!d || !d->sndh) return;
    if (frameIndex < d->framePos) {
        d->sndh->InitSubSong(d->subsongId, false);
        d->muteApplied = -1;   /* InitSubSong unmutes everything */
        d->framePos = 0;
    }
    if (d->framePos == frameIndex) return;
    g_is_seeking = 1;
    d->sndh->RewampSetSpeed(1.0);   /* the fast-forward is in song time */
    int16_t tmp[512];
    while (d->framePos < frameIndex && !g_seek_cancel) {
        const uint64_t room = frameIndex - d->framePos;
        const uint32_t n = (uint32_t)(room > 512 ? 512 : room);
        d->sndh->AudioRender(tmp, n);   /* not FastForward: the scopes follow */
        d->framePos += n;
        g_seek_progress_s = (double)d->framePos / (double)SNDH_RATE;
    }
    d->sndh->RewampSetSpeed(d->speed);
    d->posFrac = 0.0;
    g_is_seeking = 0;
}

/* Vitesse NATIVE: le tick du pilote SNDH (SndhRenderer::RewampSetSpeed). */
int sndh_set_speed_fn(RewampDecoder* rd, double speed) {
    SndhDec* d = reinterpret_cast<SndhDec*>(rd);
    if (!d || !d->sndh || speed < 0.2 || speed > 3.0) return 0;
    d->speed = speed;
    d->sndh->RewampSetSpeed(speed);
    return 1;
}

uint64_t sndh_length_fn(RewampDecoder* rd) {
    SndhDec* d = reinterpret_cast<SndhDec*>(rd);
    return d ? d->totalFrames : 0;
}

void sndh_close_fn(RewampDecoder* rd) {
    SndhDec* d = reinterpret_cast<SndhDec*>(rd);
    if (!d) return;
    if (d->sndh) AtariAudioRenderer::Destroy(d->sndh);
    delete d;
}

const RewampPluginVTable kSndhVTable = {
    "sndh",
    sndh_probe,
    sndh_open_fn,
    sndh_read_fn,
    sndh_seek_fn,
    sndh_length_fn,
    sndh_close_fn,
    nullptr,          /* configure_loop */
    0,                /* supportsNativeFadeout */
    nullptr,          /* engine_id */
    nullptr,          /* param_changed */
    nullptr, nullptr, nullptr, nullptr, nullptr, /* pattern view */
    nullptr,          /* probe_path */
    0,                /* noPrefixProbe */
    sndh_set_speed_fn, /* vitesse native */
};

/* ── .ym: the same library's YmRenderer ─────────────────────────────────────
 * Second engine for .ym next to zxtune, and the default one (it scores above
 * zxtune's extension-only 55; « Décodeurs par défaut » pins either). Written
 * by the author of the format: YM2 to YM6, MIX1 (digimix), YMT1/YMT2, LZH
 * depacked by the library, and the Atari effects YM5/YM6 carry (digidrums,
 * SID voice, SinSid, Sync-Buzzer) that zxtune does not render. The YM2149
 * core is the one of the .sndh plugin, so scope, notes and mute come with
 * it. Mono, one subsong; the library loops by itself, so one pass then EOF
 * like .sndh. */
struct YmDec {
    YmRenderer* ym = nullptr;
    uint64_t framePos = 0;
    uint64_t totalFrames = 0;   /* 0 = unknown */
    double   speed = 1.0;
    double   posFrac = 0.0;
    int64_t  muteApplied = -1;
    std::vector<int16_t> buf;
};

const AtariAudioRenderer::SongInfo& song_info(const YmRenderer* r) {
    return static_cast<const AtariAudioRenderer*>(r)->GetSongInfo();
}

/* The header a YmRenderer accepts (AtariAudioRenderer::QuickFileTypeCheck):
 * LZH level 0 (how nearly every .ym ships), "LeOnArD!" after the id (YM4 to
 * YM6, MIX1, YMT1/2), or the bare YM2!/YM3!/YM3b register dumps. */
bool ym_header_ok(const uint8_t* h, size_t n) {
    if (!h || n < 16) return false;
    if (LzhDepacker::IsLzhPacked(h, (uint32_t)n)) return true;
    if (memcmp(h + 4, "LeOnArD!", 8) == 0) return true;
    return memcmp(h, "YM2!", 4) == 0 || memcmp(h, "YM3!", 4) == 0 ||
           memcmp(h, "YM3b", 4) == 0;
}

int ym_probe(const char* ext, const uint8_t* header, size_t headerSize) {
    const bool extMatch = ext && strcasecmp(ext, "ym") == 0;
    const bool magic = ym_header_ok(header, headerSize);
    /* An LZH archive under another name is not a .ym. */
    if (!extMatch) {
        return magic && !LzhDepacker::IsLzhPacked(header, (uint32_t)headerSize) ? 80 : 0;
    }
    return magic ? 90 : 60;
}

void ym_close_fn(RewampDecoder* rd);

RewampDecoder* ym_open_fn(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return nullptr;
    char clean[4096];
    split_subsong(path, clean, sizeof(clean));
    std::vector<uint8_t> data;
    if (!read_file(clean, data)) return nullptr;

    YmDec* d = new YmDec();
    d->ym = YmRenderer::Create(data.data(), (uint32_t)data.size(), SNDH_RATE,
                               AtariAudioRenderer::kDefaultAtariYmClock);
    if (!d->ym) { delete d; return nullptr; }
    if (!d->ym->InitSubSong(1, false)) {
        ym_close_fn(reinterpret_cast<RewampDecoder*>(d));
        return nullptr;
    }
    d->totalFrames = d->ym->GetSubsongDurationSample(1);
    const AtariAudioRenderer::SongInfo& si = song_info(d->ym);

    /* The digimix and YM-tracker formats play SAMPLES through the mixer, not
     * the PSG: their 4th voice is that mix (mute bit 3, as the STE DAC). */
    const char* fmt = si.fileFormat ? si.fileFormat : "";
    const bool sampled = strncmp(fmt, "YM Digimix", 10) == 0 ||
                         strncmp(fmt, "YM Tracker", 10) == 0;
    rewamp_channel_data_reset(sampled ? SNDH_VOICES : 3);
    rewamp_channel_data_set_ring_write_size(SNDH_RING_SIZE);
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("YM2149", 0, 3);
    rewamp_voice_set_name(0, "PSG A");
    rewamp_voice_set_name(1, "PSG B");
    rewamp_voice_set_name(2, "PSG C");
    if (sampled) {
        rewamp_voices_add_chip("Samples", 3, 1);
        rewamp_voice_set_name(3, "Samples");
    }

    if (si.musicName && si.musicName[0])
        rewamp_track_tag_set(si.musicName, si.musicAuthor, nullptr);
    if (si.musicName && si.musicName[0])
        rewamp_track_message_append("Title: %s\n", si.musicName);
    if (si.musicAuthor && si.musicAuthor[0])
        rewamp_track_message_append("Author: %s\n", si.musicAuthor);
    if (si.converter && si.converter[0])
        rewamp_track_message_append("Comment: %s\n", si.converter);
    if (fmt[0]) rewamp_track_message_append("Format: %s\n", fmt);
    rewamp_track_message_append("YM2149 clock: %u Hz\nPlayer rate: %dHz\n"
                                "Engine: AtariAudio %s\n",
                                si.ym2149Clock, si.playerTickRate, ATARI_AUDIO_VERSION);

    if (outFormat) {
        outFormat->channels   = 1;
        outFormat->sampleRate = SNDH_RATE;
    }
    return reinterpret_cast<RewampDecoder*>(d);
}

uint64_t ym_read_fn(RewampDecoder* rd, float* out, uint64_t frameCount) {
    YmDec* d = reinterpret_cast<YmDec*>(rd);
    if (!d || !d->ym || frameCount == 0) return 0;
    if (d->muteApplied != generic_mute_mask) {
        d->ym->MuteVoices((uint32_t)(generic_mute_mask & 0xF));
        d->muteApplied = generic_mute_mask;
    }
    uint64_t want = frameCount;
    if (d->totalFrames > 0) {
        if (d->framePos >= d->totalFrames) return 0;
        const double sp = d->speed > 0.0 ? d->speed : 1.0;
        const uint64_t leftOut = (uint64_t)((double)(d->totalFrames - d->framePos) / sp) + 1;
        if (want > leftOut) want = leftOut;
    }
    if (d->buf.size() < want) d->buf.resize((size_t)want);
    d->ym->AudioRender(d->buf.data(), (uint32_t)want);
    const float scale = 1.0f / 32768.0f;
    for (uint64_t i = 0; i < want; i++) out[i] = d->buf[(size_t)i] * scale;
    d->posFrac += (double)want * (d->speed > 0.0 ? d->speed : 1.0);
    const uint64_t whole = (uint64_t)d->posFrac;
    d->posFrac -= (double)whole;
    d->framePos += whole;
    return want;
}

void ym_seek_fn(RewampDecoder* rd, uint64_t frameIndex) {
    YmDec* d = reinterpret_cast<YmDec*>(rd);
    if (!d || !d->ym) return;
    if (frameIndex < d->framePos) {
        d->ym->InitSubSong(1, false);
        d->muteApplied = -1;   /* InitSubSong unmutes everything */
        d->framePos = 0;
    }
    if (d->framePos == frameIndex) return;
    g_is_seeking = 1;
    d->ym->RewampSetSpeed(1.0);   /* the fast-forward is in song time */
    int16_t tmp[512];
    while (d->framePos < frameIndex && !g_seek_cancel) {
        const uint64_t room = frameIndex - d->framePos;
        const uint32_t n = (uint32_t)(room > 512 ? 512 : room);
        d->ym->AudioRender(tmp, n);   /* not FastForward: the scopes follow */
        d->framePos += n;
        g_seek_progress_s = (double)d->framePos / (double)SNDH_RATE;
    }
    d->ym->RewampSetSpeed(d->speed);
    d->posFrac = 0.0;
    g_is_seeking = 0;
}

/* Vitesse NATIVE: le tick du pilote YM. Le digimix (MIX1) n'en a pas: repli
 * générique. */
int ym_set_speed_fn(RewampDecoder* rd, double speed) {
    YmDec* d = reinterpret_cast<YmDec*>(rd);
    if (!d || !d->ym || speed < 0.2 || speed > 3.0) return 0;
    if (!d->ym->RewampHasDriverTick()) return 0;
    d->speed = speed;
    d->ym->RewampSetSpeed(speed);
    return 1;
}

uint64_t ym_length_fn(RewampDecoder* rd) {
    YmDec* d = reinterpret_cast<YmDec*>(rd);
    return d ? d->totalFrames : 0;
}

void ym_close_fn(RewampDecoder* rd) {
    YmDec* d = reinterpret_cast<YmDec*>(rd);
    if (!d) return;
    if (d->ym) AtariAudioRenderer::Destroy(d->ym);
    delete d;
}

const RewampPluginVTable kYmVTable = {
    "atariaudio_ym",
    ym_probe,
    ym_open_fn,
    ym_read_fn,
    ym_seek_fn,
    ym_length_fn,
    ym_close_fn,
    nullptr,          /* configure_loop */
    0,                /* supportsNativeFadeout */
    nullptr,          /* engine_id */
    nullptr,          /* param_changed */
    nullptr, nullptr, nullptr, nullptr, nullptr, /* pattern view */
    nullptr,          /* probe_path */
    0,                /* noPrefixProbe */
    ym_set_speed_fn,  /* vitesse native */
};

/* ── Subsong probe (Dart container UI: SNDH files may list up to 128 songs) ── */
SndhRenderer*            g_probe = nullptr;
std::vector<std::string> g_probe_titles;
char                     g_probe_title[256];

}  // namespace

extern "C" const RewampPluginVTable* rewamp_sndh_plugin(void) { return &kSndhVTable; }
extern "C" const RewampPluginVTable* rewamp_atariaudio_ym_plugin(void) { return &kYmVTable; }

extern "C" int rewamp_sndh_probe_subsong_count(const char* path) {
    if (g_probe) { AtariAudioRenderer::Destroy(g_probe); g_probe = nullptr; }
    g_probe_titles.clear();
    if (!path) return 0;
    char clean[4096];
    split_subsong(path, clean, sizeof(clean));
    std::vector<uint8_t> data;
    if (!read_file(clean, data)) return 0;
    g_probe = SndhRenderer::Create(data.data(), (uint32_t)data.size(), SNDH_RATE);
    if (!g_probe) return 0;
    g_probe_titles = subsong_titles(song_info(g_probe));
    return song_info(g_probe).subsongCount;
}

/* SNDH subsong ids are 1-based already — base=1 so the absolute index the
 * Dart layer advertises via ?subsong= is exactly what InitSubSong() expects. */
extern "C" int rewamp_sndh_probe_base(void) { return 1; }

extern "C" const char* rewamp_sndh_probe_get_title(int idx) {
    if (!g_probe) return "";
    const AtariAudioRenderer::SongInfo& si = song_info(g_probe);
    const char* t = (idx >= 0 && idx < (int)g_probe_titles.size() && !g_probe_titles[idx].empty())
        ? g_probe_titles[idx].c_str() : si.musicName;
    if (!t) return "";
    strncpy(g_probe_title, t, sizeof(g_probe_title) - 1);
    g_probe_title[sizeof(g_probe_title) - 1] = '\0';
    return g_probe_title;
}

extern "C" int rewamp_sndh_probe_get_duration_ms(int idx) {
    if (!g_probe) return -1;
    const uint32_t s = g_probe->GetSubsongDurationSample(idx + 1);
    if (s == 0) return -1;
    return (int)((uint64_t)s * 1000 / SNDH_RATE);
}

#endif /* REWAMP_WITH_SNDH */
