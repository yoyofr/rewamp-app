// Ligne de commande du bureau, côté NATIF Linux et Windows (en-tête seul,
// partagé par app/linux/runner et app/windows/runner).
//
// Le natif n'interprète presque rien: Dart reçoit les arguments BRUTS
// (lib/cli_options.dart). Il ne décide que ce qui précède Dart — `--help`,
// `--version`, « commande de pilotage sans instance lancée » — et le lit dans
// `data/flutter_assets/assets/cli/cli_manifest.json`, GÉNÉRÉ depuis la table
// Dart. Même balayage que `scanCommandLine` de macos/Runner/AppDelegate.swift.
//
// Le manifeste est NOTRE fichier: le lecteur JSON ci-dessous n'en connaît que
// ce qu'il contient (objets, tableaux, chaînes, booléens), et tout écart rend
// un manifeste vide plutôt qu'une erreur — l'app démarre alors normalement.
#ifndef REWAMP_CLI_H_
#define REWAMP_CLI_H_

#include <cstdint>
#include <fstream>
#include <set>
#include <sstream>
#include <string>
#include <vector>

namespace rewamp_cli {

struct Manifest {
  bool loaded = false;
  std::string help;
  std::set<std::string> valued;  // options qui prennent une valeur
  std::set<std::string> remote;  // pilotage d'une instance lancée
};

namespace detail {

struct Reader {
  std::string s;  // copie: pas de membre référence (avertissement MSVC /W4)
  size_t i = 0;
  bool ok = true;

  void ws() {
    while (i < s.size() && (s[i] == ' ' || s[i] == '\n' || s[i] == '\r' ||
                            s[i] == '\t')) {
      i++;
    }
  }
  bool eat(char c) {
    ws();
    if (i < s.size() && s[i] == c) {
      i++;
      return true;
    }
    return false;
  }
  static void utf8(std::string& out, uint32_t cp) {
    if (cp < 0x80) {
      out.push_back(static_cast<char>(cp));
    } else if (cp < 0x800) {
      out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else if (cp < 0x10000) {
      out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else {
      out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    }
  }
  bool hex4(uint32_t& v) {
    if (i + 4 > s.size()) return false;
    v = 0;
    for (int k = 0; k < 4; k++) {
      char c = s[i++];
      v <<= 4;
      if (c >= '0' && c <= '9') v |= c - '0';
      else if (c >= 'a' && c <= 'f') v |= c - 'a' + 10;
      else if (c >= 'A' && c <= 'F') v |= c - 'A' + 10;
      else return false;
    }
    return true;
  }
  std::string str() {
    std::string out;
    if (!eat('"')) {
      ok = false;
      return out;
    }
    while (i < s.size() && s[i] != '"') {
      char c = s[i++];
      if (c != '\\') {
        out.push_back(c);
        continue;
      }
      if (i >= s.size()) break;
      char e = s[i++];
      switch (e) {
        case 'n': out.push_back('\n'); break;
        case 't': out.push_back('\t'); break;
        case 'r': out.push_back('\r'); break;
        case 'b': out.push_back('\b'); break;
        case 'f': out.push_back('\f'); break;
        case 'u': {
          uint32_t cp;
          if (!hex4(cp)) {
            ok = false;
            return out;
          }
          if (cp >= 0xD800 && cp < 0xDC00 && i + 1 < s.size() &&
              s[i] == '\\' && s[i + 1] == 'u') {
            i += 2;
            uint32_t lo;
            if (!hex4(lo)) {
              ok = false;
              return out;
            }
            cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
          }
          utf8(out, cp);
          break;
        }
        default: out.push_back(e);  // \" \\ \/
      }
    }
    if (i >= s.size()) ok = false;
    i++;  // guillemet fermant
    return out;
  }
  // Saute une valeur dont on n'a pas l'usage.
  void skip() {
    ws();
    if (i >= s.size()) {
      ok = false;
      return;
    }
    char c = s[i];
    if (c == '"') {
      str();
    } else if (c == '{' || c == '[') {
      char close = c == '{' ? '}' : ']';
      i++;
      if (eat(close)) return;
      do {
        if (c == '{') {
          str();
          if (!eat(':')) {
            ok = false;
            return;
          }
        }
        skip();
      } while (ok && eat(','));
      if (!eat(close)) ok = false;
    } else {
      while (i < s.size() && s[i] != ',' && s[i] != '}' && s[i] != ']') i++;
    }
  }
  bool boolean() {
    ws();
    if (s.compare(i, 4, "true") == 0) {
      i += 4;
      return true;
    }
    skip();
    return false;
  }
};

}  // namespace detail

inline Manifest ParseManifest(const std::string& text) {
  Manifest m;
  detail::Reader r{text};
  if (!r.eat('{')) return Manifest();
  if (!r.eat('}')) {
    do {
      std::string key = r.str();
      if (!r.ok || !r.eat(':')) return Manifest();
      if (key == "help") {
        m.help = r.str();
      } else if (key == "options") {
        if (!r.eat('[')) return Manifest();
        if (!r.eat(']')) {
          do {
            if (!r.eat('{')) return Manifest();
            std::string name;
            bool valued = false, remote = false;
            if (!r.eat('}')) {
              do {
                std::string k = r.str();
                if (!r.ok || !r.eat(':')) return Manifest();
                if (k == "name") name = r.str();
                else if (k == "value") valued = r.boolean();
                else if (k == "remote") remote = r.boolean();
                else r.skip();
              } while (r.ok && r.eat(','));
              if (!r.eat('}')) return Manifest();
            }
            if (!name.empty()) {
              if (valued) m.valued.insert(name);
              if (remote) m.remote.insert(name);
            }
          } while (r.ok && r.eat(','));
          if (!r.eat(']')) return Manifest();
        }
      } else {
        r.skip();
      }
      if (!r.ok) return Manifest();
    } while (r.eat(','));
    if (!r.eat('}')) return Manifest();
  }
  m.loaded = true;
  return m;
}

// [path] est le manifeste du bundle: `<dossier de l'exécutable>/data/
// flutter_assets/assets/cli/cli_manifest.json` sur les deux plateformes.
// Un `std::wstring` sous Windows (chemin non ASCII), un `std::string` ailleurs.
template <class Path>
inline Manifest LoadManifest(const Path& path) {
  std::ifstream f(path, std::ios::binary);
  if (!f) return Manifest();
  std::stringstream ss;
  ss << f.rdbuf();
  return ParseManifest(ss.str());
}

struct Scan {
  std::set<std::string> names;  // options `--x` vues, connues ou non
  int positional = 0;

  bool Has(const char* n) const { return names.count(n) != 0; }
  // Une commande de PILOTAGE seule: elle n'a de sens que si l'app tourne.
  bool RemoteOnly(const Manifest& m) const {
    if (positional > 0) return false;
    for (const auto& n : names) {
      if (m.remote.count(n)) return true;
    }
    return false;
  }
};

// [args] sans argv[0] ni `--cwd=`. Mêmes règles que parseCommandLine (Dart):
// `--x=v` ou `--x v`, `--` termine les options, un réglage à tiret seul et à
// MAJUSCULE emporte sa valeur, tout autre tiret seul est écarté.
inline Scan ScanArgs(const std::vector<std::string>& args, const Manifest& m) {
  Scan out;
  bool only_files = false;
  for (size_t i = 0; i < args.size(); i++) {
    const std::string& a = args[i];
    if (a.empty()) continue;
    if (only_files) {
      out.positional++;
      continue;
    }
    if (a == "--") {
      only_files = true;
      continue;
    }
    bool next_is_value =
        i + 1 < args.size() && (args[i + 1].empty() || args[i + 1][0] != '-');
    if (a.size() >= 2 && a[0] == '-' && a[1] == '-') {
      size_t eq = a.find('=');
      std::string name = a.substr(2, eq == std::string::npos ? std::string::npos
                                                              : eq - 2);
      out.names.insert(name);
      if (eq == std::string::npos && m.valued.count(name) && next_is_value) i++;
      continue;
    }
    if (a.size() > 1 && a[0] == '-') {
      if (a[1] >= 'A' && a[1] <= 'Z' && next_is_value) i++;
      continue;
    }
    out.positional++;
  }
  return out;
}

inline std::string VersionLine(const char* version) {
  return std::string("Rewamp ") + (version && *version ? version : "?") + "\n";
}

inline std::string HelpText(const Manifest& m, const char* version) {
  return VersionLine(version) + "\n" +
         (m.help.empty() ? std::string("Usage: rewamp [OPTIONS] [FILES...]\n")
                         : m.help);
}

constexpr char kNotRunning[] = "rewamp: Rewamp is not running.\n";

}  // namespace rewamp_cli

#endif  // REWAMP_CLI_H_
