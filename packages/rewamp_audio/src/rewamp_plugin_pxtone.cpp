// PxTone Collage plugin — Studio Pixel's own tracker format (.ptcop project
// files / .pttune compiled tunes) via the vendored pxtone library
// (third_party/libpixel/pxtone, Modizer's copy of Pixel's official source
// with the YOYOFR per-voice capture patches baked into pxtnService_moo.cpp /
// pxtnUnit.cpp — grep YOYOFR). Sibling of the Organya plugin (same
// libs/libpixel origin, same author, Organya being the Cave Story precursor
// of PxTone).
//
// The glue is ported from Modizer's mmp_pixelLoad (ModizMusicPlayer.mm):
// pxtnService::init → set_destination_quality(2, 44100) → pxtnDescriptor::
// set_memory_r → read → tones_ready → moo_preparation, then Moo() renders
// int16 stereo. The file buffer must stay alive for the whole decode: the
// descriptor references it and the backward-seek path re-reads it.
//
// Native seek via prepareVomitPxtone() (a Modizer addition to pxtnService):
// forward = direct moo_preparation at the sample offset; backward needs the
// full clear+init+read+tones_ready reload first (mirrors Modizer's seek
// block). Exact analytical length via moo_get_total_sample().
//
// Mute: pxtnService.mute_mask is an INSTANCE field (not a global) consumed
// by the YOYOFR capture sites in pxtnService_moo.cpp (both the scope write
// and the real mix, via the Tone_Supple skip) — read() copies
// generic_mute_mask into it every call. Shifts widened to 1ULL during
// vendoring (pxtnMAX_TUNEUNITSTRUCT is 50 > 31).
//
// Embedded ogg-vorbis voices (pxINCLUDE_OGGVORBIS) stay compiled OUT,
// matching Modizer's build — a .ptcop whose woice needs vorbis fails to
// load rather than pulling a whole vorbis decoder into the pod.
//
// Text (title/comment/unit names) is Shift-JIS; converted through the shared
// rewamp_sjis_to_utf8 (iconv on Apple, '?' per glyph elsewhere).
#ifdef REWAMP_WITH_PXTONE

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

#include "pxtnService.h"
#include "pxtnError.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PXTONE_RATE 44100

struct RewampDecoder {
    pxtnService*    pxtn;
    pxtnDescriptor* desc;
    char*           fileBuf;
    int32_t         fileLen;
    uint64_t        totalFrames;
    uint64_t        framePos;
};

static const char* const kPxtoneExts[] = { "ptcop", "pttune", NULL };


static int pxtone_probe(const char* ext, const uint8_t* h, size_t n) {
    int magic = 0;
    if (n >= 16) {
        if (!memcmp(h, "PTCOLLAGE-", 10)) magic = 1;
        else if (!memcmp(h, "PTTUNE--", 8)) magic = 1;
    }
    int extMatch = rewamp_ext_in_list(ext, kPxtoneExts);
    if (magic) return extMatch ? 110 : 90;
    if (extMatch) return 60; // extension without magic: unlikely a real tune
    return 0;
}

// Full pxtnService (re)initialisation from the kept file buffer. Used by
// open() and by the backward-seek path (Modizer's own idiom: clear+init+
// re-read — moo_preparation alone cannot rewind).
static bool pxtone_prepare(RewampDecoder* dec, bool firstTime) {
    pxtnService*    pxtn = dec->pxtn;
    pxtnDescriptor* desc = dec->desc;
    if (firstTime) {
        if (pxtn->init() != pxtnOK) return false;
    } else {
        // clear() empties the song but leaves the object initialized —
        // init() on an initialized pxtnService returns pxtnERR_INIT (Modizer
        // calls it anyway and ignores the result; don't call it at all).
        pxtn->clear();
    }
    if (!pxtn->set_destination_quality(2, PXTONE_RATE)) return false;
    if (!desc->set_memory_r(dec->fileBuf, dec->fileLen)) return false;
    if (pxtn->read(desc) != pxtnOK || pxtn->tones_ready() != pxtnOK) {
        pxtn->evels->Release();
        return false;
    }
    pxtnVOMITPREPARATION prep = {0};
    prep.start_pos_float = 0;
    prep.master_volume   = 1.0f;
    return pxtn->moo_preparation(&prep);
}

static RewampDecoder* pxtone_open_impl(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q) *q = '\0';

    FILE* f = fopen(cleanPath, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size <= 0) { fclose(f); return NULL; }

    char* buf = (char*)malloc((size_t)size);
    if (!buf) { fclose(f); return NULL; }
    size_t got = fread(buf, 1, (size_t)size, f);
    fclose(f);
    if (got != (size_t)size) { free(buf); return NULL; }

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { free(buf); return NULL; }
    dec->fileBuf = buf;
    dec->fileLen = (int32_t)size;
    dec->pxtn    = new pxtnService();
    dec->desc    = new pxtnDescriptor();

    if (!pxtone_prepare(dec, true)) {
        delete dec->pxtn;
        delete dec->desc;
        free(buf);
        free(dec);
        return NULL;
    }

    int voices = dec->pxtn->Unit_Num();
    if (voices < 1) voices = 1;
    m_genNumVoicesChannels = voices;
    rewamp_channel_data_reset(voices);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_channel_data_set_ring_circular(1);
    m_voice_current_samplerate = PXTONE_RATE;
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("PxTone", 0, voices);

    char utf8[512];
    for (int i = 0; i < dec->pxtn->Unit_Num(); i++) {
        const pxtnUnit* unit = dec->pxtn->Unit_Get(i);
        const char* nm = unit ? unit->get_name_buf(NULL) : NULL;
        if (nm && nm[0]) {
            rewamp_sjis_to_utf8(nm, utf8, sizeof(utf8));
            rewamp_voice_set_name(i, utf8);
        }
    }

    dec->totalFrames = (uint64_t)dec->pxtn->moo_get_total_sample();

    const char* name    = dec->pxtn->text->get_name_buf(NULL);
    const char* comment = dec->pxtn->text->get_comment_buf(NULL);
    if (name && name[0]) {
        rewamp_sjis_to_utf8(name, utf8, sizeof(utf8));
        rewamp_track_message_append("Title: %s\n", utf8);
    } else {
        const char* base = strrchr(cleanPath, '/');
        rewamp_track_message_append("Title: %s\n", base ? base + 1 : cleanPath);
    }
    if (comment && comment[0]) {
        rewamp_sjis_to_utf8(comment, utf8, sizeof(utf8));
        rewamp_track_message_append("Comment: %s\n", utf8);
    }
    rewamp_track_message_append("Format: PxTone Collage, %d units, %d Hz, stereo\n",
                                dec->pxtn->Unit_Num(), PXTONE_RATE);
    if (dec->totalFrames > 0) {
        unsigned total = (unsigned)(dec->totalFrames / PXTONE_RATE);
        rewamp_track_message_append("Duration: %u:%02u\n", total / 60, total % 60);
    }

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = PXTONE_RATE;
    }
    return dec;
}

static uint64_t pxtone_read_impl(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || frameCount == 0) return 0;
    if (dec->totalFrames > 0) {
        if (dec->framePos >= dec->totalFrames) return 0;
        uint64_t remain = dec->totalFrames - dec->framePos;
        if (frameCount > remain) frameCount = remain;
    }

    dec->pxtn->mute_mask = (uint64_t)generic_mute_mask;

    static int16_t s_buf[4096 * 2];
    const float scale = 1.0f / 32768.0f;
    uint64_t written = 0;
    while (written < frameCount) {
        uint32_t want = (uint32_t)(frameCount - written);
        if (want > 4096) want = 4096;
        if (!dec->pxtn->Moo(s_buf, (int32_t)(want * 2 * sizeof(int16_t)))) break;
        float* dst = out + written * 2;
        for (uint32_t i = 0; i < want * 2; i++) dst[i] = s_buf[i] * scale;
        written += want;
        dec->framePos += want;
    }
    return written;
}

static void pxtone_seek_impl(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec) return;
    // Backward: moo state only advances — full reload first (Modizer idiom).
    if (frameIndex < dec->framePos) {
        if (!pxtone_prepare(dec, false)) return;
    }
    dec->pxtn->prepareVomitPxtone((int)frameIndex);
    dec->framePos = frameIndex;
}

static uint64_t pxtone_length_impl(RewampDecoder* dec) {
    return dec ? dec->totalFrames : 0;
}

static void pxtone_close_impl(RewampDecoder* dec) {
    if (!dec) return;
    delete dec->pxtn;
    delete dec->desc;
    free(dec->fileBuf);
    free(dec);
}

static const RewampPluginVTable kPxtoneVTable = {
    "pxtone",
    pxtone_probe,
    pxtone_open_impl,
    pxtone_read_impl,
    pxtone_seek_impl,
    pxtone_length_impl,
    pxtone_close_impl,
};

extern "C" const RewampPluginVTable* rewamp_pxtone_plugin(void) { return &kPxtoneVTable; }

#endif /* REWAMP_WITH_PXTONE */
