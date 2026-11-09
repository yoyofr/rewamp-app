/* rewamp_path_bank.h — « Lire avec… » for the FM-MIDI engines: the
 * instrument bank chosen for ONE file, above the engine's own bank setting.
 *
 * Header-only, included by rewamp_plugin_adlmidi.cpp and
 * rewamp_plugin_opnmidi.cpp: each gets its OWN table (anonymous namespace),
 * which is what an engine-scoped choice needs. Written from the UI thread
 * (Dart rebuilds it before every load and adds the next file before every
 * gapless arm, like the per-file plugin table of the registry), read by
 * open() on the producer thread. Keyed by the EXACT path, without
 * `?subsong=`. */
#pragma once

#include <mutex>
#include <string>
#include <vector>

namespace {

struct PathBank {
    std::string path;
    int         index = -1;   /* embedded bank, -1 = see file */
    std::string file;         /* imported bank file, "" = see index */
};

class PathBankTable {
public:
    /* index < 0 and an empty file = forget [path]. */
    void set(const char* path, int index, const char* file) {
        if (!path || !path[0]) return;
        const std::string f = file ? file : "";
        std::lock_guard<std::mutex> lk(m_);
        for (size_t i = 0; i < e_.size(); i++) {
            if (e_[i].path == path) {
                if (index < 0 && f.empty()) e_.erase(e_.begin() + (long)i);
                else { e_[i].index = index; e_[i].file = f; }
                return;
            }
        }
        if (index < 0 && f.empty()) return;
        /* Dart only keeps what it is about to play: a few entries. */
        if (e_.size() >= 64) e_.erase(e_.begin());
        e_.push_back(PathBank{path, index, f});
    }

    void clear() {
        std::lock_guard<std::mutex> lk(m_);
        e_.clear();
    }

    /* The choice for [path], false when none. */
    bool get(const char* path, PathBank& out) {
        std::lock_guard<std::mutex> lk(m_);
        for (const auto& b : e_)
            if (b.path == path) { out = b; return true; }
        return false;
    }

private:
    std::mutex            m_;
    std::vector<PathBank> e_;
};

}  // namespace
