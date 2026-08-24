/* Lightweight tag reader for files decoded by the miniaudio fallback
 * (mp3 / flac / ogg / wav). miniaudio decodes audio only, so without this the
 * info panel (ⓘ) stayed empty for plain audio files. Appends whatever it
 * finds to the shared track message via rewamp_track_message_append().
 *
 * Supported: ID3v2.2/2.3/2.4, ID3v1 (fallback), FLAC VORBIS_COMMENT,
 * Ogg Vorbis / Opus comment headers, RIFF WAVE LIST/INFO. All output UTF-8.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <ctype.h>
/* rewamp_tag_* / rewamp_track_artwork* y sont déclarés REWAMP_EXPORT.
 * Ce TU ne voyait AUCUNE déclaration: les définitions ci-dessous
 * sortaient alors avec la visibilité par défaut, donc PAS du tout sur
 * une .so compilée en -fvisibility=hidden (Linux). */
#include "rewamp_channel_data.h"
#ifdef _WIN32
#define strcasecmp _stricmp
#else
#include <strings.h>
#endif

void rewamp_track_message_append(const char* fmt, ...);

#define TAG_VALUE_MAX 1024          /* per-field output cap (UTF-8 bytes) */
#define ID3V2_TAG_MAX (1u << 20)    /* refuse tags larger than 1 MiB */
#define ART_MAX       (16u << 20)   /* refuse embedded pictures above 16 MiB */

/* ── Embedded artwork (cover picture) ──────────────────────────────────────
 * First picture found while parsing (ID3v2 APIC / FLAC PICTURE /
 * METADATA_BLOCK_PICTURE vorbis comment). Owned here; freed on clear. */
static uint8_t* g_art       = NULL;
static int      g_art_size  = 0;
static char     g_art_mime[48] = "";

/* Structured copies of the common fields (the message stays free text).
 * Same lifecycle as the artwork: reset per load. */
static char g_tag_title[TAG_VALUE_MAX]  = "";
static char g_tag_artist[TAG_VALUE_MAX] = "";
static char g_tag_album[TAG_VALUE_MAX]  = "";

const char* rewamp_tag_title(void)  { return g_tag_title; }
const char* rewamp_tag_artist(void) { return g_tag_artist; }
const char* rewamp_tag_album(void)  { return g_tag_album; }

void rewamp_track_artwork_clear(void) {
    free(g_art);
    g_art = NULL;
    g_art_size = 0;
    g_art_mime[0] = '\0';
    g_tag_title[0] = g_tag_artist[0] = g_tag_album[0] = '\0';
}

const uint8_t* rewamp_track_artwork(int* size) {
    if (size) *size = g_art_size;
    return g_art;
}

const char* rewamp_track_artwork_mime(void) { return g_art_mime; }

static void art_store(const uint8_t* data, size_t n, const char* mime) {
    if (g_art || n == 0 || n > ART_MAX) return;   /* keep the first picture */
    g_art = (uint8_t*)malloc(n);
    if (!g_art) return;
    memcpy(g_art, data, n);
    g_art_size = (int)n;
    strncpy(g_art_mime, mime ? mime : "", sizeof(g_art_mime) - 1);
    g_art_mime[sizeof(g_art_mime) - 1] = '\0';
}

/* ── encoding helpers ──────────────────────────────────────────────────── */

/* Latin-1 → UTF-8. Returns bytes written (excl. NUL). */
static size_t latin1_to_utf8(const uint8_t* in, size_t n, char* out, size_t outSize) {
    size_t o = 0;
    for (size_t i = 0; i < n && in[i]; ++i) {
        uint8_t c = in[i];
        if (c < 0x80) {
            if (o + 1 >= outSize) break;
            out[o++] = (char)c;
        } else {
            if (o + 2 >= outSize) break;
            out[o++] = (char)(0xC0 | (c >> 6));
            out[o++] = (char)(0x80 | (c & 0x3F));
        }
    }
    out[o] = '\0';
    return o;
}

/* UTF-16 (explicit endianness) → UTF-8. Handles surrogate pairs. */
static size_t utf16_to_utf8(const uint8_t* in, size_t n, int bigEndian,
                            char* out, size_t outSize) {
    size_t o = 0;
    for (size_t i = 0; i + 1 < n; i += 2) {
        uint32_t u = bigEndian ? (uint32_t)((in[i] << 8) | in[i + 1])
                               : (uint32_t)((in[i + 1] << 8) | in[i]);
        if (u == 0) break;
        if (u >= 0xD800 && u <= 0xDBFF && i + 3 < n) {
            uint32_t lo = bigEndian ? (uint32_t)((in[i + 2] << 8) | in[i + 3])
                                    : (uint32_t)((in[i + 3] << 8) | in[i + 2]);
            if (lo >= 0xDC00 && lo <= 0xDFFF) {
                u = 0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00);
                i += 2;
            }
        }
        if (u < 0x80) {
            if (o + 1 >= outSize) break;
            out[o++] = (char)u;
        } else if (u < 0x800) {
            if (o + 2 >= outSize) break;
            out[o++] = (char)(0xC0 | (u >> 6));
            out[o++] = (char)(0x80 | (u & 0x3F));
        } else if (u < 0x10000) {
            if (o + 3 >= outSize) break;
            out[o++] = (char)(0xE0 | (u >> 12));
            out[o++] = (char)(0x80 | ((u >> 6) & 0x3F));
            out[o++] = (char)(0x80 | (u & 0x3F));
        } else {
            if (o + 4 >= outSize) break;
            out[o++] = (char)(0xF0 | (u >> 18));
            out[o++] = (char)(0x80 | ((u >> 12) & 0x3F));
            out[o++] = (char)(0x80 | ((u >> 6) & 0x3F));
            out[o++] = (char)(0x80 | (u & 0x3F));
        }
    }
    out[o] = '\0';
    return o;
}

/* Decode an ID3v2 text payload (leading encoding byte) into UTF-8. */
static void id3_text_to_utf8(const uint8_t* p, size_t n, char* out, size_t outSize) {
    out[0] = '\0';
    if (n < 1) return;
    uint8_t enc = p[0];
    p++; n--;
    switch (enc) {
        case 0:  latin1_to_utf8(p, n, out, outSize); break;
        case 1:  /* UTF-16 with BOM */
            if (n >= 2 && p[0] == 0xFF && p[1] == 0xFE)
                utf16_to_utf8(p + 2, n - 2, 0, out, outSize);
            else if (n >= 2 && p[0] == 0xFE && p[1] == 0xFF)
                utf16_to_utf8(p + 2, n - 2, 1, out, outSize);
            else
                utf16_to_utf8(p, n, 0, out, outSize);
            break;
        case 2:  utf16_to_utf8(p, n, 1, out, outSize); break;
        default: {  /* 3 = UTF-8 */
            size_t c = n < outSize - 1 ? n : outSize - 1;
            memcpy(out, p, c);
            out[c] = '\0';
            /* trim at first NUL */
            out[strnlen(out, c)] = '\0';
            break;
        }
    }
}

static void trim_trailing(char* s) {
    size_t n = strlen(s);
    while (n > 0 && (s[n - 1] == ' ' || s[n - 1] == '\r' || s[n - 1] == '\n'))
        s[--n] = '\0';
}

static void append_tag(const char* label, const char* value) {
    char v[TAG_VALUE_MAX];
    strncpy(v, value, sizeof(v) - 1);
    v[sizeof(v) - 1] = '\0';
    trim_trailing(v);
    if (!v[0]) return;
    rewamp_track_message_append("%s: %s\n", label, v);
    /* First value wins (ID3v2 before ID3v1 etc.). */
    if (!strcmp(label, "Title")  && !g_tag_title[0])  strcpy(g_tag_title,  v);
    if (!strcmp(label, "Artist") && !g_tag_artist[0]) strcpy(g_tag_artist, v);
    if (!strcmp(label, "Album")  && !g_tag_album[0])  strcpy(g_tag_album,  v);
}

/* ── ID3v2 ─────────────────────────────────────────────────────────────── */

static uint32_t syncsafe32(const uint8_t* p) {
    return ((uint32_t)(p[0] & 0x7F) << 21) | ((uint32_t)(p[1] & 0x7F) << 14) |
           ((uint32_t)(p[2] & 0x7F) << 7)  |  (uint32_t)(p[3] & 0x7F);
}

static const char* id3_frame_label(const char* id) {
    /* v2.3/2.4 ids and their v2.2 3-char equivalents */
    if (!strcmp(id, "TIT2") || !strcmp(id, "TT2")) return "Title";
    if (!strcmp(id, "TPE1") || !strcmp(id, "TP1")) return "Artist";
    if (!strcmp(id, "TALB") || !strcmp(id, "TAL")) return "Album";
    if (!strcmp(id, "TYER") || !strcmp(id, "TDRC") || !strcmp(id, "TYE")) return "Year";
    if (!strcmp(id, "TRCK") || !strcmp(id, "TRK")) return "Track";
    if (!strcmp(id, "TCON") || !strcmp(id, "TCO")) return "Genre";
    if (!strcmp(id, "TPE2") || !strcmp(id, "TP2")) return "Album artist";
    if (!strcmp(id, "TCOM") || !strcmp(id, "TCM")) return "Composer";
    if (!strcmp(id, "COMM") || !strcmp(id, "COM")) return "Comment";
    /* A few more common ones with friendly names; anything unmapped falls back
     * to its raw 3/4-char frame id (so EVERY text/URL tag is shown). */
    if (!strcmp(id, "TPUB") || !strcmp(id, "TPB")) return "Publisher";
    if (!strcmp(id, "TCOP") || !strcmp(id, "TCR")) return "Copyright";
    if (!strcmp(id, "TPOS") || !strcmp(id, "TPA")) return "Disc";
    if (!strcmp(id, "TENC") || !strcmp(id, "TEN")) return "Encoded by";
    if (!strcmp(id, "TSSE")) return "Encoder";
    if (!strcmp(id, "TBPM") || !strcmp(id, "TBP")) return "BPM";
    if (!strcmp(id, "TLEN") || !strcmp(id, "TLE")) return "Length";
    if (!strcmp(id, "TIT1") || !strcmp(id, "TT1")) return "Grouping";
    if (!strcmp(id, "TIT3") || !strcmp(id, "TT3")) return "Subtitle";
    if (!strcmp(id, "TOPE") || !strcmp(id, "TOA")) return "Original artist";
    if (!strcmp(id, "TEXT") || !strcmp(id, "TXT")) return "Lyricist";
    if (!strcmp(id, "TLAN") || !strcmp(id, "TLA")) return "Language";
    if (!strcmp(id, "TDRL")) return "Release date";
    if (!strcmp(id, "WOAS") || !strcmp(id, "WAS")) return "Source URL";
    if (!strcmp(id, "WOAF") || !strcmp(id, "WAF")) return "File URL";
    if (!strcmp(id, "WOAR") || !strcmp(id, "WAR")) return "Artist URL";
    if (!strcmp(id, "WPUB") || !strcmp(id, "WPB")) return "Publisher URL";
    if (!strcmp(id, "WCOM") || !strcmp(id, "WCM")) return "Commercial URL";
    return NULL;
}

/* Returns 1 if an ID3v2 tag was found and parsed. */
static int read_id3v2(FILE* f) {
    uint8_t hdr[10];
    if (fseek(f, 0, SEEK_SET) != 0 || fread(hdr, 1, 10, f) != 10) return 0;
    if (memcmp(hdr, "ID3", 3) != 0) return 0;
    uint8_t ver = hdr[3];
    uint8_t flags = hdr[5];
    uint32_t tagSize = syncsafe32(hdr + 6);
    if (tagSize == 0 || tagSize > ID3V2_TAG_MAX) return 0;

    uint8_t* tag = (uint8_t*)malloc(tagSize);
    if (!tag) return 0;
    if (fread(tag, 1, tagSize, f) != tagSize) { free(tag); return 0; }

    size_t pos = 0;
    if (flags & 0x40) {  /* extended header — skip it */
        if (tagSize < 4) { free(tag); return 1; }
        uint32_t ext = (ver >= 4) ? syncsafe32(tag)
                                  : ((uint32_t)tag[0] << 24 | tag[1] << 16 |
                                     tag[2] << 8 | tag[3]) + 4;
        pos = ext < tagSize ? ext : tagSize;
    }

    int idLen   = (ver == 2) ? 3 : 4;
    int hdrLen  = (ver == 2) ? 6 : 10;
    char value[TAG_VALUE_MAX];

    while (pos + (size_t)hdrLen <= tagSize) {
        const uint8_t* p = tag + pos;
        if (p[0] == 0) break;  /* padding reached */
        char id[5] = {0};
        memcpy(id, p, idLen);
        uint32_t fsz;
        if (ver == 2)
            fsz = ((uint32_t)p[3] << 16) | ((uint32_t)p[4] << 8) | p[5];
        else if (ver >= 4)
            fsz = syncsafe32(p + 4);
        else
            fsz = ((uint32_t)p[4] << 24) | ((uint32_t)p[5] << 16) |
                  ((uint32_t)p[6] << 8) | p[7];
        pos += (size_t)hdrLen;
        if (fsz == 0 || pos + fsz > tagSize) break;

        /* APIC (v2.3/2.4) / PIC (v2.2): embedded cover picture. */
        if (!g_art && (!strcmp(id, "APIC") || !strcmp(id, "PIC"))) {
            const uint8_t* b = tag + pos;
            size_t blen = fsz;
            if (blen > 4) {
                uint8_t enc = b[0];
                const uint8_t* q = b + 1;
                size_t rem = blen - 1;
                char mime[48] = "";
                if (id[3] == '\0' && idLen == 3) {  /* v2.2 PIC: 3-char format */
                    if (rem >= 3) {
                        snprintf(mime, sizeof(mime), "image/%.3s", q);
                        for (char* m = mime; *m; ++m)
                            *m = (char)tolower((unsigned char)*m);
                        q += 3; rem -= 3;
                    }
                } else {                            /* APIC: NUL-ended MIME */
                    size_t ml = 0;
                    while (ml < rem && q[ml]) ml++;
                    if (ml < sizeof(mime)) { memcpy(mime, q, ml); mime[ml] = '\0'; }
                    if (ml < rem) { q += ml + 1; rem -= ml + 1; } else rem = 0;
                }
                if (rem > 1) {
                    q++; rem--;                     /* picture type byte */
                    /* description, terminator depends on encoding */
                    if (enc == 1 || enc == 2) {
                        while (rem >= 2 && (q[0] || q[1])) { q += 2; rem -= 2; }
                        if (rem >= 2) { q += 2; rem -= 2; }
                    } else {
                        while (rem > 0 && q[0]) { q++; rem--; }
                        if (rem > 0) { q++; rem--; }
                    }
                    if (rem > 0) art_store(q, rem, mime);
                }
            }
        }

        /* Text (T***), user-defined text (TXXX), URL (W***) and comment (COMM)
         * frames → the info panel. Unmapped frames fall back to their raw 3/4-
         * char id, so EVERY text/URL tag is shown. Binary frames (APIC handled
         * above, MCDI/PRIV/UFID/… ) are skipped. */
        const char* label = id3_frame_label(id);   /* friendly name or NULL */
        const uint8_t* body = tag + pos;
        size_t blen = fsz;
        if ((!strcmp(id, "TXXX") || !strcmp(id, "TXX")) && blen > 1) {
            /* enc(1) + description(NUL-term) + value; description is the label. */
            uint8_t enc = body[0];
            const uint8_t* q = body + 1;
            size_t rem = blen - 1, dl = 0;
            if (enc == 1 || enc == 2) { while (dl + 1 < rem && (q[dl] || q[dl + 1])) dl += 2; }
            else                      { while (dl < rem && q[dl]) dl++; }
            char desc[128]; uint8_t t1[128];
            size_t dc = dl < sizeof(t1) - 1 ? dl : sizeof(t1) - 1;
            t1[0] = enc; memcpy(t1 + 1, q, dc);
            id3_text_to_utf8(t1, dc + 1, desc, sizeof(desc));
            size_t adv = dl + ((enc == 1 || enc == 2) ? 2 : 1);
            if (adv <= rem) {
                uint8_t t2[TAG_VALUE_MAX]; size_t vl = rem - adv;
                size_t vc = vl < sizeof(t2) - 1 ? vl : sizeof(t2) - 1;
                t2[0] = enc; memcpy(t2 + 1, q + adv, vc);
                id3_text_to_utf8(t2, vc + 1, value, sizeof(value));
                append_tag(desc[0] ? desc : "Info", value);
            }
        } else if (id[0] == 'T') {
            id3_text_to_utf8(body, blen, value, sizeof(value));
            append_tag(label ? label : id, value);
        } else if ((!strcmp(id, "WXXX") || !strcmp(id, "WXX")) && blen > 1) {
            /* enc(1) + description(NUL-term) + URL(Latin-1 to end). */
            uint8_t enc = body[0];
            const uint8_t* q = body + 1;
            size_t rem = blen - 1, dl = 0;
            if (enc == 1 || enc == 2) { while (dl + 1 < rem && (q[dl] || q[dl + 1])) dl += 2; }
            else                      { while (dl < rem && q[dl]) dl++; }
            char desc[128]; uint8_t t1[128];
            size_t dc = dl < sizeof(t1) - 1 ? dl : sizeof(t1) - 1;
            t1[0] = enc; memcpy(t1 + 1, q, dc);
            id3_text_to_utf8(t1, dc + 1, desc, sizeof(desc));
            size_t adv = dl + ((enc == 1 || enc == 2) ? 2 : 1);
            if (adv <= rem) {
                latin1_to_utf8(q + adv, rem - adv, value, sizeof(value));
                append_tag(desc[0] ? desc : (label ? label : "URL"), value);
            }
        } else if (id[0] == 'W') {
            /* URL frame: the whole body is a Latin-1 URL, no encoding byte. */
            latin1_to_utf8(body, blen, value, sizeof(value));
            append_tag(label ? label : id, value);
        } else if (!strcmp(id, "COMM") || !strcmp(id, "COM")) {
            /* enc(1) + lang(3) + short desc(NUL-term) + text. */
            if (blen > 4) {
                uint8_t enc = body[0];
                const uint8_t* q = body + 4;
                size_t rem = blen - 4;
                if (enc == 1 || enc == 2) {
                    while (rem >= 2 && (q[0] || q[1])) { q += 2; rem -= 2; }
                    if (rem >= 2) { q += 2; rem -= 2; }
                } else {
                    while (rem > 0 && q[0]) { q++; rem--; }
                    if (rem > 0) { q++; rem--; }
                }
                uint8_t tmp[TAG_VALUE_MAX];
                size_t c = rem < sizeof(tmp) - 1 ? rem : sizeof(tmp) - 1;
                tmp[0] = enc;
                memcpy(tmp + 1, q, c);
                id3_text_to_utf8(tmp, c + 1, value, sizeof(value));
                append_tag(label ? label : "Comment", value);
            }
        }
        pos += fsz;
    }
    free(tag);
    return 1;
}

/* ── ID3v1 (last 128 bytes) ────────────────────────────────────────────── */

static int read_id3v1(FILE* f) {
    uint8_t b[128];
    if (fseek(f, -128, SEEK_END) != 0 || fread(b, 1, 128, f) != 128) return 0;
    if (memcmp(b, "TAG", 3) != 0) return 0;
    char v[128];
    latin1_to_utf8(b + 3,  30, v, sizeof(v)); append_tag("Title",  v);
    latin1_to_utf8(b + 33, 30, v, sizeof(v)); append_tag("Artist", v);
    latin1_to_utf8(b + 63, 30, v, sizeof(v)); append_tag("Album",  v);
    latin1_to_utf8(b + 93,  4, v, sizeof(v)); append_tag("Year",   v);
    latin1_to_utf8(b + 97, 30, v, sizeof(v)); append_tag("Comment", v);
    return 1;
}

/* ── Vorbis comments (FLAC / Ogg) ──────────────────────────────────────── */

static uint32_t le32(const uint8_t* p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static const char* vorbis_key_label(const char* key) {
    if (!strcasecmp(key, "TITLE"))       return "Title";
    if (!strcasecmp(key, "ARTIST"))      return "Artist";
    if (!strcasecmp(key, "ALBUM"))       return "Album";
    if (!strcasecmp(key, "ALBUMARTIST")) return "Album artist";
    if (!strcasecmp(key, "DATE"))        return "Year";
    if (!strcasecmp(key, "TRACKNUMBER")) return "Track";
    if (!strcasecmp(key, "GENRE"))       return "Genre";
    if (!strcasecmp(key, "COMPOSER"))    return "Composer";
    if (!strcasecmp(key, "COMMENT") || !strcasecmp(key, "DESCRIPTION"))
        return "Comment";
    return NULL;
}

static uint32_t be32(const uint8_t* p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
           ((uint32_t)p[2] << 8) | (uint32_t)p[3];
}

/* FLAC METADATA_BLOCK_PICTURE layout (also used base64'd in ogg comments). */
static void parse_flac_picture(const uint8_t* b, size_t n) {
    if (g_art || n < 32) return;
    size_t pos = 4;                       /* picture type */
    uint32_t mlen = be32(b + pos); pos += 4;
    if (pos + mlen + 4 > n) return;
    char mime[48] = "";
    if (mlen < sizeof(mime)) { memcpy(mime, b + pos, mlen); mime[mlen] = '\0'; }
    pos += mlen;
    uint32_t dlen = be32(b + pos); pos += 4 + dlen;      /* description */
    if (pos + 20 > n) return;
    pos += 16;                            /* w, h, depth, colors */
    uint32_t plen = be32(b + pos); pos += 4;
    if (plen == 0 || pos + plen > n) return;
    art_store(b + pos, plen, mime);
}

static int b64_val(int c) {
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= 'a' && c <= 'z') return c - 'a' + 26;
    if (c >= '0' && c <= '9') return c - '0' + 52;
    if (c == '+') return 62;
    if (c == '/') return 63;
    return -1;
}

static uint8_t* b64_decode(const char* in, size_t n, size_t* outLen) {
    uint8_t* out = (uint8_t*)malloc(n / 4 * 3 + 4);
    if (!out) return NULL;
    size_t o = 0;
    int acc = 0, bits = 0;
    for (size_t i = 0; i < n; ++i) {
        int v = b64_val((unsigned char)in[i]);
        if (v < 0) { if (in[i] == '=') break; continue; }
        acc = (acc << 6) | v;
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            out[o++] = (uint8_t)((acc >> bits) & 0xFF);
        }
    }
    *outLen = o;
    return out;
}

/* Parse a vorbis-comment block at buf (vendor + user comments, all LE). */
static void parse_vorbis_comments(const uint8_t* buf, size_t n) {
    if (n < 8) return;
    size_t pos = 0;
    uint32_t vlen = le32(buf);
    pos = 4 + vlen;
    if (pos + 4 > n) return;
    uint32_t count = le32(buf + pos);
    pos += 4;
    if (count > 256) count = 256;
    char value[TAG_VALUE_MAX];
    for (uint32_t i = 0; i < count && pos + 4 <= n; ++i) {
        uint32_t clen = le32(buf + pos);
        pos += 4;
        if (clen == 0 || pos + clen > n) break;
        const char* c = (const char*)(buf + pos);
        const char* eq = memchr(c, '=', clen);
        if (eq) {
            char key[64];
            size_t klen = (size_t)(eq - c);
            if (klen < sizeof(key)) {
                memcpy(key, c, klen);
                key[klen] = '\0';
                const char* label = vorbis_key_label(key);
                if (label) {
                    size_t vlen2 = clen - klen - 1;
                    size_t cp = vlen2 < sizeof(value) - 1 ? vlen2 : sizeof(value) - 1;
                    memcpy(value, eq + 1, cp);
                    value[cp] = '\0';
                    append_tag(label, value);
                } else if (!g_art &&
                           !strcasecmp(key, "METADATA_BLOCK_PICTURE")) {
                    size_t blen = 0;
                    uint8_t* blk = b64_decode(eq + 1, clen - klen - 1, &blen);
                    if (blk) {
                        parse_flac_picture(blk, blen);
                        free(blk);
                    }
                }
            }
        }
        pos += clen;
    }
}

static int read_flac(FILE* f) {
    uint8_t magic[4];
    if (fseek(f, 0, SEEK_SET) != 0 || fread(magic, 1, 4, f) != 4) return 0;
    if (memcmp(magic, "fLaC", 4) != 0) return 0;
    for (int i = 0; i < 64; ++i) {
        uint8_t bh[4];
        if (fread(bh, 1, 4, f) != 4) break;
        int last = bh[0] & 0x80;
        int type = bh[0] & 0x7F;
        uint32_t len = ((uint32_t)bh[1] << 16) | ((uint32_t)bh[2] << 8) | bh[3];
        if (type == 4 && len > 0 && len < ID3V2_TAG_MAX) {  /* VORBIS_COMMENT */
            uint8_t* buf = (uint8_t*)malloc(len);
            if (buf && fread(buf, 1, len, f) == len)
                parse_vorbis_comments(buf, len);
            free(buf);
        } else if (type == 6 && len > 0 && len < ART_MAX && !g_art) {
            uint8_t* buf = (uint8_t*)malloc(len);   /* PICTURE (cover art) */
            if (buf && fread(buf, 1, len, f) == len)
                parse_flac_picture(buf, len);
            free(buf);
        } else if (fseek(f, (long)len, SEEK_CUR) != 0) {
            break;
        }
        if (last) break;
    }
    return 1;  /* it IS a flac, just without comments */
}

static int read_ogg(FILE* f) {
    uint8_t magic[4];
    if (fseek(f, 0, SEEK_SET) != 0 || fread(magic, 1, 4, f) != 4) return 0;
    if (memcmp(magic, "OggS", 4) != 0) return 0;
    /* The comment header ("\x03vorbis" or "OpusTags") normally sits inside
     * the second page, well within the first 128 KiB. Scan for the marker
     * instead of walking page lacing — good enough for real-world files. */
    enum { SCAN = 128 * 1024 };
    uint8_t* buf = (uint8_t*)malloc(SCAN);
    if (!buf) return 1;
    fseek(f, 0, SEEK_SET);
    size_t n = fread(buf, 1, SCAN, f);
    for (size_t i = 0; i + 8 < n; ++i) {
        if (buf[i] == 0x03 && memcmp(buf + i, "\x03vorbis", 7) == 0) {
            parse_vorbis_comments(buf + i + 7, n - i - 7);
            break;
        }
        if (buf[i] == 'O' && memcmp(buf + i, "OpusTags", 8) == 0) {
            parse_vorbis_comments(buf + i + 8, n - i - 8);
            break;
        }
    }
    free(buf);
    return 1;
}

/* ── RIFF WAVE LIST/INFO ───────────────────────────────────────────────── */

static const char* wav_info_label(const char* id) {
    if (!memcmp(id, "INAM", 4)) return "Title";
    if (!memcmp(id, "IART", 4)) return "Artist";
    if (!memcmp(id, "IPRD", 4)) return "Album";
    if (!memcmp(id, "ICRD", 4)) return "Year";
    if (!memcmp(id, "IGNR", 4)) return "Genre";
    if (!memcmp(id, "ICMT", 4)) return "Comment";
    if (!memcmp(id, "ISFT", 4)) return "Software";
    return NULL;
}

static int read_wav(FILE* f) {
    uint8_t hdr[12];
    if (fseek(f, 0, SEEK_SET) != 0 || fread(hdr, 1, 12, f) != 12) return 0;
    if (memcmp(hdr, "RIFF", 4) != 0 || memcmp(hdr + 8, "WAVE", 4) != 0) return 0;
    char value[TAG_VALUE_MAX];
    for (int i = 0; i < 128; ++i) {
        uint8_t ch[8];
        if (fread(ch, 1, 8, f) != 8) break;
        uint32_t len = le32(ch + 4);
        if (!memcmp(ch, "LIST", 4) && len >= 4) {
            uint8_t sub[4];
            if (fread(sub, 1, 4, f) != 4) break;
            if (!memcmp(sub, "INFO", 4)) {
                uint32_t rem = len - 4;
                while (rem >= 8) {
                    uint8_t sh[8];
                    if (fread(sh, 1, 8, f) != 8) return 1;
                    uint32_t slen = le32(sh + 4);
                    if (slen > rem - 8) break;
                    const char* label = wav_info_label((const char*)sh);
                    uint32_t padded = slen + (slen & 1);
                    if (label && slen > 0 && slen < TAG_VALUE_MAX) {
                        uint8_t tmp[TAG_VALUE_MAX];
                        if (fread(tmp, 1, padded, f) != padded) return 1;
                        latin1_to_utf8(tmp, slen, value, sizeof(value));
                        append_tag(label, value);
                    } else {
                        if (fseek(f, (long)padded, SEEK_CUR) != 0) return 1;
                    }
                    rem -= 8 + padded;
                }
                return 1;
            }
            if (fseek(f, (long)(len - 4 + (len & 1)), SEEK_CUR) != 0) break;
        } else {
            if (fseek(f, (long)(len + (len & 1)), SEEK_CUR) != 0) break;
        }
    }
    return 1;
}

/* ── entry point ───────────────────────────────────────────────────────── */

void rewamp_tags_append_info(const char* path) {
    FILE* f = fopen(path, "rb");
    if (!f) return;
    /* Container detection by magic, not extension. */
    if (!read_flac(f) && !read_ogg(f) && !read_wav(f)) {
        /* mp3 & friends: ID3v2 at the front, ID3v1 fallback at the tail */
        if (!read_id3v2(f)) read_id3v1(f);
    }
    fclose(f);
}
