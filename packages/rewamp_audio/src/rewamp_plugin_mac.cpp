// Monkey's Audio (.ape) decoder plugin, backed by the vendored MACLib
// (third_party/monkeyaudio, Modizer's curated 26-file set, -DMACLIB_COMPILE).
// Mirrors Modizer's MMP_MAC integration (ModizMusicPlayer.mm mmp_macLoad):
// CreateIAPEDecompress + GetInfo + GetData + Seek. Unlike Modizer we emit
// float32 at the file's native rate (miniaudio resamples downstream), and we
// convert 8/16/24-bit blocks explicitly instead of assuming 16-bit.

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "All.h"
#include "MACLib.h"
#include "APETag.h"
#include "CharacterHelper.h"

namespace {

const char* const kMacExts[] = { "ape", NULL };

struct MacDecoder {
    IAPEDecompress* ape;
    uint32_t channels;
    uint32_t sampleRate;
    int bytesPerSample;   // 1 / 2 / 3
    int blockAlign;       // bytesPerSample * channels
    uint64_t totalBlocks;
    char* blockBuf;       // staging buffer for GetData (native bit depth)
    size_t blockBufFrames;
};

} // namespace

static int mac_probe(const char* ext, const uint8_t* header, size_t headerSize) {
    const bool extMatch = rewamp_ext_in_list(ext, kMacExts) != 0;
    // 'MAC ' magic ("MACF" never shipped; all APE versions start with 'MAC ').
    const bool magic = headerSize >= 4 &&
        header[0] == 'M' && header[1] == 'A' && header[2] == 'C' && header[3] == ' ';
    if (extMatch && magic) return 95;
    if (magic) return 70;   // prefix/renamed file, content is authoritative
    if (extMatch) return 60;
    return 0;
}

static RewampDecoder* mac_open(const char* path, RewampAudioFormat* outFormat) {
    // Strip the rewamp ?subsong=N suffix (APE is single-song, but queue rows
    // built from multi-file M3Us may still carry one) — fopen would fail.
    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    { char* q = strrchr(cleanPath, '?'); if (q) *q = '\0'; }

    int err = 0;
    CSmartPtr<str_utf16> spInput;
    spInput.Assign(CAPECharacterHelper::GetUTF16FromUTF8(
                       (const str_utf8*)cleanPath), TRUE);
    IAPEDecompress* ape = CreateIAPEDecompress(spInput.GetPtr(), &err);
    if (!ape) {
        fprintf(stderr, "[rewamp][mac] CreateIAPEDecompress failed (%d): %s\n",
                err, path);
        return NULL;
    }

    MacDecoder* d = (MacDecoder*)calloc(1, sizeof(MacDecoder));
    d->ape            = ape;
    d->channels       = (uint32_t)ape->GetInfo(APE_INFO_CHANNELS);
    d->sampleRate     = (uint32_t)ape->GetInfo(APE_INFO_SAMPLE_RATE);
    d->bytesPerSample = (int)ape->GetInfo(APE_INFO_BYTES_PER_SAMPLE);
    d->blockAlign     = (int)ape->GetInfo(APE_INFO_BLOCK_ALIGN);
    d->totalBlocks    = (uint64_t)ape->GetInfo(APE_DECOMPRESS_TOTAL_BLOCKS);
    if (d->channels == 0 || d->sampleRate == 0 || d->blockAlign <= 0 ||
        (d->bytesPerSample != 1 && d->bytesPerSample != 2 && d->bytesPerSample != 3)) {
        delete ape;
        free(d);
        return NULL;
    }

    outFormat->channels   = d->channels;
    outFormat->sampleRate = d->sampleRate;

    // Info panel: APE stream facts + every APE/ID3 tag field (Modizer parity).
    rewamp_track_message_append(
        "APE version: %.2f\nSample rate: %u Hz\nBits: %d\nChannels: %u\n",
        (float)ape->GetInfo(APE_INFO_FILE_VERSION) / 1000.0f,
        d->sampleRate, (int)ape->GetInfo(APE_INFO_BITS_PER_SAMPLE),
        d->channels);
    {
        CAPETag* tag = (CAPETag*)ape->GetInfo(APE_INFO_TAG);
        if (tag && (tag->GetHasAPETag() || tag->GetHasID3Tag())) {
            rewamp_track_message_append("\n");
            for (int i = 0; ; i++) {
                CAPETagField* f = tag->GetTagField(i);
                if (!f) break;
                const str_utf16* wname = f->GetFieldName();
                if (!wname || !f->GetFieldValue() || !f->GetFieldValue()[0])
                    continue;
                CSmartPtr<str_utf8> name;
                name.Assign(CAPECharacterHelper::GetUTF8FromUTF16(wname), TRUE);
                rewamp_track_message_append("%s: %s\n",
                    name.GetPtr() ? (const char*)name.GetPtr() : "?",
                    f->GetFieldValue());
            }
        }
    }
    return (RewampDecoder*)d;
}

static uint64_t mac_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    MacDecoder* d = (MacDecoder*)dec;
    if (frameCount == 0) return 0;

    if (d->blockBufFrames < frameCount) {
        free(d->blockBuf);
        d->blockBuf = (char*)malloc((size_t)frameCount * d->blockAlign);
        d->blockBufFrames = frameCount;
    }

    int retrieved = 0;
    if (d->ape->GetData(d->blockBuf, (int)frameCount, &retrieved) != ERROR_SUCCESS ||
        retrieved <= 0) {
        return 0;
    }

    const size_t samples = (size_t)retrieved * d->channels;
    switch (d->bytesPerSample) {
        case 2: {
            const int16_t* s = (const int16_t*)d->blockBuf;
            for (size_t i = 0; i < samples; i++) out[i] = s[i] / 32768.0f;
            break;
        }
        case 1: { // 8-bit APE is unsigned (WAV convention)
            const uint8_t* s = (const uint8_t*)d->blockBuf;
            for (size_t i = 0; i < samples; i++) out[i] = ((int)s[i] - 128) / 128.0f;
            break;
        }
        case 3: { // 24-bit little-endian signed
            const uint8_t* s = (const uint8_t*)d->blockBuf;
            for (size_t i = 0; i < samples; i++) {
                int32_t v = (int32_t)(s[i * 3] | (s[i * 3 + 1] << 8) |
                                      (s[i * 3 + 2] << 16));
                if (v & 0x800000) v |= ~0xFFFFFF;
                out[i] = v / 8388608.0f;
            }
            break;
        }
    }
    return (uint64_t)retrieved;
}

static void mac_seek(RewampDecoder* dec, uint64_t frameIndex) {
    MacDecoder* d = (MacDecoder*)dec;
    d->ape->Seek((int)frameIndex);
}

static uint64_t mac_length(RewampDecoder* dec) {
    return ((MacDecoder*)dec)->totalBlocks;
}

static void mac_close(RewampDecoder* dec) {
    MacDecoder* d = (MacDecoder*)dec;
    delete d->ape;
    free(d->blockBuf);
    free(d);
}

static const RewampPluginVTable kMacVTable = {
    "monkeyaudio",
    mac_probe,
    mac_open,
    mac_read,
    mac_seek,
    mac_length,
    mac_close,
};

extern "C" const RewampPluginVTable* rewamp_mac_plugin(void) {
    return &kMacVTable;
}
