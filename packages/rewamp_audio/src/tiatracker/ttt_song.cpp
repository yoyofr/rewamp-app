// .ttt (JSON) -> VCS replay tables. See ttt_song.h for the licensing note.
//
// Every rule below was verified against the tracker's OWN exported
// <song>_trackdata.asm for six songs (92/92 patterns identical, semantically
// compared so the exporter's instrument renumbering does not matter). The
// non-obvious ones, each of which produced a real mismatch before it was
// found:
//
//  - A slide's JSON `value` is the SIGNED amount (-7..+7); the note byte is
//    value + 8, which is what the player subtracts back out.
//  - Envelope frames with volume 0 at the END are dropped. Not cosmetic: the
//    release phase is terminated by a literal $00 byte, and a "volume 0, no
//    pitch change" frame encodes as $80, so keeping them would walk the
//    envelope index straight into the next instrument's data. The release
//    always keeps at least one frame.
//  - The "Pure Combined (4+12)" pseudo-waveform (16) is two real instruments
//    sharing one envelope: note value < 32 plays AUDC 4 at that frequency,
//    >= 32 plays AUDC 12 at value - 32.
//  - A goto target is relative to its own channel's sub-track; channel 1's
//    entries sit after channel 0's in one shared table, so the absolute index
//    is target + that channel's base.
#include "ttt_song.h"

#include <stdlib.h>
#include <string.h>

namespace {

// --------------------------------------------------------------------------
// Minimal JSON reader. A .ttt is machine-written by Qt's QJsonDocument, so it
// only ever contains objects, arrays, numbers, strings and bools — no need to
// pull a general-purpose library into two build systems for it.
// --------------------------------------------------------------------------
struct JValue {
  enum Type { kNull, kBool, kNum, kStr, kArr, kObj };
  Type type;
  bool b;
  double num;
  std::string str;
  std::vector<JValue> arr;
  std::vector<std::pair<std::string, JValue> > obj;

  JValue() : type(kNull), b(false), num(0) {}

  const JValue* find(const char* key) const {
    if (type != kObj) return NULL;
    for (size_t i = 0; i < obj.size(); ++i)
      if (obj[i].first == key) return &obj[i].second;
    return NULL;
  }
  int intOr(const char* key, int def) const {
    const JValue* v = find(key);
    return (v && v->type == kNum) ? (int)v->num : def;
  }
  bool boolOr(const char* key, bool def) const {
    const JValue* v = find(key);
    if (!v) return def;
    if (v->type == kBool) return v->b;
    if (v->type == kNum) return v->num != 0;
    return def;
  }
  std::string strOr(const char* key, const char* def) const {
    const JValue* v = find(key);
    return (v && v->type == kStr) ? v->str : std::string(def);
  }
  const JValue* array(const char* key) const {
    const JValue* v = find(key);
    return (v && v->type == kArr) ? v : NULL;
  }
};

class JParser {
 public:
  JParser(const char* p, size_t n) : p_(p), end_(p + n), ok_(true) {}

  bool parse(JValue& out) {
    skip();
    value(out);
    return ok_;
  }
  const std::string& error() const { return err_; }

 private:
  const char* p_;
  const char* end_;
  bool ok_;
  std::string err_;

  void fail(const char* msg) {
    if (ok_) { ok_ = false; err_ = msg; }
  }
  void skip() {
    while (p_ < end_ && (*p_ == ' ' || *p_ == '\t' || *p_ == '\n' || *p_ == '\r')) ++p_;
  }
  bool eat(char c) {
    skip();
    if (p_ < end_ && *p_ == c) { ++p_; return true; }
    return false;
  }

  void appendUtf8(std::string& s, unsigned cp) {
    if (cp < 0x80) {
      s += (char)cp;
    } else if (cp < 0x800) {
      s += (char)(0xc0 | (cp >> 6));
      s += (char)(0x80 | (cp & 0x3f));
    } else {
      s += (char)(0xe0 | (cp >> 12));
      s += (char)(0x80 | ((cp >> 6) & 0x3f));
      s += (char)(0x80 | (cp & 0x3f));
    }
  }

  void string(std::string& out) {
    if (!eat('"')) { fail("expected string"); return; }
    while (p_ < end_ && *p_ != '"') {
      char c = *p_++;
      if (c != '\\') { out += c; continue; }
      if (p_ >= end_) break;
      char e = *p_++;
      switch (e) {
        case 'n': out += '\n'; break;
        case 't': out += '\t'; break;
        case 'r': out += '\r'; break;
        case 'b': out += '\b'; break;
        case 'f': out += '\f'; break;
        case 'u': {
          unsigned cp = 0;
          for (int i = 0; i < 4 && p_ < end_; ++i) {
            char h = *p_++;
            cp <<= 4;
            if (h >= '0' && h <= '9') cp |= (unsigned)(h - '0');
            else if (h >= 'a' && h <= 'f') cp |= (unsigned)(h - 'a' + 10);
            else if (h >= 'A' && h <= 'F') cp |= (unsigned)(h - 'A' + 10);
          }
          appendUtf8(out, cp);
          break;
        }
        default: out += e; break;  // covers \" \\ \/
      }
    }
    if (!eat('"')) fail("unterminated string");
  }

  void value(JValue& v) {
    if (!ok_) return;
    skip();
    if (p_ >= end_) { fail("unexpected end"); return; }
    char c = *p_;
    if (c == '{') {
      ++p_;
      v.type = JValue::kObj;
      skip();
      if (eat('}')) return;
      for (;;) {
        std::pair<std::string, JValue> kv;
        string(kv.first);
        if (!eat(':')) { fail("expected ':'"); return; }
        value(kv.second);
        if (!ok_) return;
        v.obj.push_back(kv);
        if (eat(',')) continue;
        if (eat('}')) return;
        fail("expected ',' or '}'");
        return;
      }
    } else if (c == '[') {
      ++p_;
      v.type = JValue::kArr;
      skip();
      if (eat(']')) return;
      for (;;) {
        v.arr.push_back(JValue());
        value(v.arr.back());
        if (!ok_) return;
        if (eat(',')) continue;
        if (eat(']')) return;
        fail("expected ',' or ']'");
        return;
      }
    } else if (c == '"') {
      v.type = JValue::kStr;
      string(v.str);
    } else if (c == 't' || c == 'f') {
      v.type = JValue::kBool;
      v.b = (c == 't');
      p_ += (c == 't') ? 4 : 5;
      if (p_ > end_) fail("truncated literal");
    } else if (c == 'n') {
      v.type = JValue::kNull;
      p_ += 4;
      if (p_ > end_) fail("truncated literal");
    } else {
      char* stop = NULL;
      v.type = JValue::kNum;
      v.num = strtod(p_, &stop);
      if (stop == p_) { fail("bad number"); return; }
      p_ = stop;
    }
  }
};

// --------------------------------------------------------------------------
// Note types, as stored in the JSON. Pinned by cross-referencing the songs
// against their exports: Salami is the only file carrying type 4 and the only
// one exported with TT_USE_SLIDE = 1, while Tetris-A carries type 2 with
// TT_USE_SLIDE = 0, which can only be a pause.
// --------------------------------------------------------------------------
enum {
  kTypeHold       = 0,
  kTypeInstrument = 1,
  kTypePause      = 2,
  kTypePercussion = 3,
  kTypeSlide      = 4,
};

const int kCombinedWaveform = 16;  // "Pure Combined (4+12)"
const int kCombinedLow      = 4;   // note values 0..31
const int kCombinedHigh     = 12;  // note values 32..63
const int kMaxInsSlots      = 7;   // note byte only has 3 bits for the slot
const int kNumPercussion    = 15;

struct EnvIn {
  std::vector<int> volumes;
  std::vector<int> freqs;
  int length, sustainStart, releaseStart, waveform;
  bool used;
  int slotLow, slotHigh;  // 1-based note-byte slots; slotHigh only if combined
};

void readIntArray(const JValue* obj, const char* key, std::vector<int>& out) {
  out.clear();
  const JValue* a = obj ? obj->array(key) : NULL;
  if (!a) return;
  out.reserve(a->arr.size());
  for (size_t i = 0; i < a->arr.size(); ++i)
    out.push_back(a->arr[i].type == JValue::kNum ? (int)a->arr[i].num : 0);
}

uint8_t envByte(int freqMod, int volume) {
  // bits 7..4 = modifier + 8 (so 8 means "no change"), bits 3..0 = volume.
  int m = freqMod + 8;
  if (m < 0) m = 0;
  if (m > 15) m = 15;
  return (uint8_t)(((m & 0x0f) << 4) | (volume & 0x0f));
}

}  // namespace

bool ttt_probe(const void* data, size_t size) {
  if (!data || size < 64) return false;
  const char* p = (const char*)data;
  // Must open as a JSON object.
  bool brace = false;
  for (size_t i = 0; i < size && i < 64 && !brace; ++i) {
    if (p[i] == '{') brace = true;
    else if (p[i] != ' ' && p[i] != '\t' && p[i] != '\n' && p[i] != '\r') break;
  }
  if (!brace) return false;
  // Qt writes the keys alphabetically, so "channels" comes first and the two
  // pattern sequences it holds push every other key tens of KB in — a probe
  // that only reads a fixed-size header window finds "channels" and nothing
  // else, and declines every real file. So: "channels" near the top, the rest
  // anywhere in what we were handed.
  const size_t headLen = size < 4096 ? size : 4096;
  if (std::string(p, headLen).find("\"channels\"") == std::string::npos) return false;
  const std::string all(p, size);
  return all.find("\"percussion\"") != std::string::npos &&
         all.find("\"evenspeed\"") != std::string::npos &&
         all.find("\"patterns\"") != std::string::npos;
}

bool ttt_parse(const void* data, size_t size, TttTables& out, std::string* err) {
  JValue root;
  JParser parser((const char*)data, size);
  if (!parser.parse(root) || root.type != JValue::kObj) {
    if (err) *err = "not a JSON object: " + parser.error();
    return false;
  }
  const JValue* jinstr = root.array("instruments");
  const JValue* jperc  = root.array("percussion");
  const JValue* jpat   = root.array("patterns");
  const JValue* jchan  = root.array("channels");
  if (!jpat || !jchan || jchan->arr.size() < 2) {
    if (err) *err = "missing patterns/channels";
    return false;
  }

  out = TttTables();
  out.name    = root.strOr("metaName", "");
  out.author  = root.strOr("metaAuthor", "");
  out.comment = root.strOr("metaComment", "");
  out.pal     = root.strOr("tvmode", "pal") != "ntsc";
  out.speedEven = root.intOr("evenspeed", 6);
  out.speedOdd  = root.intOr("oddspeed", out.speedEven);
  if (out.speedEven < 1) out.speedEven = 1;
  if (out.speedOdd  < 1) out.speedOdd  = 1;
  out.useFunkTempo = (out.speedEven != out.speedOdd);
  out.globalSpeed  = root.boolOr("globalspeed", true);

  // ---- which melodic instruments are actually played --------------------
  std::vector<EnvIn> ins;
  for (size_t i = 0; i < (jinstr ? jinstr->arr.size() : 0); ++i) {
    const JValue& j = jinstr->arr[i];
    EnvIn e;
    readIntArray(&j, "volumes", e.volumes);
    readIntArray(&j, "frequencies", e.freqs);
    e.length       = j.intOr("envelopeLength", (int)e.volumes.size());
    e.sustainStart = j.intOr("sustainStart", 0);
    e.releaseStart = j.intOr("releaseStart", e.length > 0 ? e.length - 1 : 0);
    e.waveform     = j.intOr("waveform", 0);
    e.used = false;
    e.slotLow = e.slotHigh = 0;
    ins.push_back(e);
  }
  for (size_t p = 0; p < jpat->arr.size(); ++p) {
    const JValue* notes = jpat->arr[p].array("notes");
    for (size_t n = 0; notes && n < notes->arr.size(); ++n) {
      const JValue& nv = notes->arr[n];
      if (nv.intOr("type", 0) != kTypeInstrument) continue;
      int idx = nv.intOr("number", 0);
      if (idx >= 0 && idx < (int)ins.size()) ins[idx].used = true;
    }
  }

  // ---- envelopes --------------------------------------------------------
  int nextSlot = 1;
  for (size_t i = 0; i < ins.size(); ++i) {
    EnvIn& e = ins[i];
    if (!e.used || e.length <= 0) continue;
    const bool combined = (e.waveform == kCombinedWaveform);
    if (nextSlot + (combined ? 1 : 0) > kMaxInsSlots) continue;  // cannot be addressed

    // Trailing zero-volume frames go away; the release keeps one frame.
    int n = e.length;
    if (n > (int)e.volumes.size()) n = (int)e.volumes.size();
    while (n > e.releaseStart + 1 && e.volumes[n - 1] == 0) --n;

    const int base = (int)out.insFreqVol.size();
    for (int f = 0; f < n; ++f) {
      if (f == e.releaseStart) out.insFreqVol.push_back(0x00);  // junk separator
      const int mod = f < (int)e.freqs.size() ? e.freqs[f] : 0;
      out.insFreqVol.push_back(envByte(mod, e.volumes[f]));
    }
    if (e.releaseStart >= n) out.insFreqVol.push_back(0x00);     // release was empty
    out.insFreqVol.push_back(0x00);                              // end of release

    const uint8_t ad      = (uint8_t)base;
    const uint8_t sustain = (uint8_t)(base + e.sustainStart);
    const uint8_t release = (uint8_t)(base + e.releaseStart);    // the junk byte
    e.slotLow = nextSlot++;
    out.insCtrl.push_back((uint8_t)(combined ? kCombinedLow : e.waveform));
    out.insAD.push_back(ad);
    out.insSustain.push_back(sustain);
    out.insRelease.push_back(release);
    if (combined) {
      e.slotHigh = nextSlot++;
      out.insCtrl.push_back((uint8_t)kCombinedHigh);
      out.insAD.push_back(ad);
      out.insSustain.push_back(sustain);
      out.insRelease.push_back(release);
    }
  }

  // ---- percussion -------------------------------------------------------
  // All 15 slots get an entry: a note byte addresses them by their JSON index,
  // so renumbering would mean rewriting note bytes for nothing. Empty ones
  // point at a shared terminator frame.
  out.percFreq.push_back(0x00);
  out.percCtrlVol.push_back(0x00);
  const uint8_t emptyPerc = 1;  // stored +1
  out.percIndex.assign(kNumPercussion, emptyPerc);
  for (int i = 0; i < kNumPercussion; ++i) {
    if (!jperc || i >= (int)jperc->arr.size()) continue;
    const JValue& j = jperc->arr[i];
    std::vector<int> wf, fr, vol;
    readIntArray(&j, "waveforms", wf);
    readIntArray(&j, "frequencies", fr);
    readIntArray(&j, "volumes", vol);
    int n = j.intOr("envelopeLength", (int)vol.size());
    if (n > (int)vol.size()) n = (int)vol.size();
    if (n > (int)wf.size())  n = (int)wf.size();
    if (n > (int)fr.size())  n = (int)fr.size();
    if (n <= 0) continue;
    const bool overlay = j.boolOr("overlay", false);
    if (overlay) out.useOverlay = true;

    const int start = (int)out.percFreq.size();
    for (int f = 0; f < n; ++f) {
      uint8_t freq = (uint8_t)(fr[f] & kTttFreqMask);
      // The overlay marker rides bit 7 of the LAST real frame's frequency: the
      // player fetches the next note the frame that one is output, so the
      // melodic instrument takes over as the percussion falls silent.
      if (overlay && f == n - 1) freq |= 0x80;
      out.percFreq.push_back(freq);
      out.percCtrlVol.push_back((uint8_t)(((wf[f] & 0x0f) << 4) | (vol[f] & 0x0f)));
    }
    out.percFreq.push_back(0x00);
    out.percCtrlVol.push_back(0x00);  // end of percussion data
    out.percIndex[i] = (uint8_t)(start + 1);
  }

  // ---- patterns ---------------------------------------------------------
  out.patterns.resize(jpat->arr.size());
  out.patternSpeedEven.assign(jpat->arr.size(), (uint8_t)out.speedEven);
  out.patternSpeedOdd.assign(jpat->arr.size(), (uint8_t)out.speedOdd);
  for (size_t p = 0; p < jpat->arr.size(); ++p) {
    const JValue& jp = jpat->arr[p];
    out.patternSpeedEven[p] = (uint8_t)jp.intOr("evenspeed", out.speedEven);
    out.patternSpeedOdd[p]  = (uint8_t)jp.intOr("oddspeed", out.speedOdd);
    if (!out.globalSpeed && out.patternSpeedEven[p] != out.patternSpeedOdd[p])
      out.useFunkTempo = true;

    std::vector<uint8_t>& bytes = out.patterns[p];
    const JValue* notes = jp.array("notes");
    for (size_t n = 0; notes && n < notes->arr.size(); ++n) {
      const JValue& nv = notes->arr[n];
      const int type = nv.intOr("type", kTypeHold);
      const int num  = nv.intOr("number", 0);
      const int val  = nv.intOr("value", 0);
      switch (type) {
        case kTypePause:
          bytes.push_back((uint8_t)kTttNotePause);
          break;
        case kTypeSlide: {
          int b = val + 8;
          if (b < 1) b = 1;
          if (b > 15) b = 15;
          if (b != kTttNoteHold) out.useSlide = true;
          bytes.push_back((uint8_t)b);
          break;
        }
        case kTypePercussion:
          bytes.push_back((uint8_t)(kTttNoteFirstPerc + (num & 0x0f)));
          break;
        case kTypeInstrument: {
          int slot = 0, freq = val;
          if (num >= 0 && num < (int)ins.size()) {
            const EnvIn& e = ins[num];
            if (e.slotHigh && val >= 32) { slot = e.slotHigh; freq = val - 32; }
            else                          { slot = e.slotLow; }
          }
          if (slot == 0) {  // undefined instrument: keep playing whatever plays
            bytes.push_back((uint8_t)kTttNoteHold);
          } else {
            bytes.push_back((uint8_t)((slot << 5) | (freq & kTttFreqMask)));
          }
          break;
        }
        case kTypeHold:
        default:
          bytes.push_back((uint8_t)kTttNoteHold);
          break;
      }
    }
    bytes.push_back(kTttNoteEndOfPattern);
  }

  // ---- sequences --------------------------------------------------------
  // One table, channel 0 then channel 1. A goto is its own byte AFTER the
  // pattern it follows, which is why channel 1's base is a byte count and not
  // an entry count.
  for (int c = 0; c < 2; ++c) {
    const int base = (int)out.sequence.size();
    const JValue* seq = jchan->arr[c].array("sequence");
    const int startEntry = root.intOr(c == 0 ? "startpattern0" : "startpattern1", 0);
    out.seqStart[c] = base;
    for (size_t i = 0; seq && i < seq->arr.size(); ++i) {
      if ((int)i == startEntry) out.seqStart[c] = (int)out.sequence.size();
      int pat = seq->arr[i].intOr("patternindex", 0);
      if (pat < 0 || pat >= (int)out.patterns.size()) pat = 0;
      out.sequence.push_back((uint8_t)pat);
      const int gt = seq->arr[i].intOr("gototarget", -1);
      if (gt >= 0) out.sequence.push_back((uint8_t)(0x80 | ((base + gt) & 0x7f)));
    }
    if (out.sequence.size() == (size_t)base) {  // empty channel: park it
      out.sequence.push_back(0);
      out.sequence.push_back((uint8_t)(0x80 | (base & 0x7f)));
    }
  }
  if (out.patterns.empty() || out.insCtrl.empty()) {
    // No instrument slot at all still plays (percussion-only songs exist), but
    // an empty pattern list has nothing to fetch.
    if (out.patterns.empty()) {
      if (err) *err = "no patterns";
      return false;
    }
  }
  return true;
}
