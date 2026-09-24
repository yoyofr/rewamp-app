#!/usr/bin/env bash
# Construit un FFmpeg MINIMAL, à embarquer dans l'AppImage.
#
# POURQUOI on ne prend pas celui de la distribution — mesuré le 2026-09-21 sur
# Ubuntu 24.04:
#
#     ldd /usr/lib/<triplet>/libavcodec.so.60   →  96 bibliothèques
#
# Le FFmpeg d'Ubuntu est bâti avec TOUT activé: aom, dav1d, jxl, OpenCL, lame,
# opus, et — par le filtre drawtext — cairo, pango, harfbuzz, fontconfig,
# gdk-pixbuf, glib, icu. Embarquer libavcodec, c'est embarquer cet arbre entier.
# Deux raisons de refuser, la seconde étant la vraie:
#
#   1. la taille (≈100 .so);
#   2. ⚠️ **glib, pango, cairo et gdk-pixbuf sont les MÊMES bibliothèques que le
#      GTK du système**. Une copie embarquée se retrouve chargée à côté de celle
#      du système, et ce conflit-là ne se manifeste pas par un message clair: il
#      plante, ailleurs, plus tard.
#
# Et on ne peut pas non plus s'en remettre au FFmpeg du système: son SONAME
# change à chaque millésime (58 sur Ubuntu 22.04, 60 sur 24.04, 61 sur 25.04).
# Un AppImage qui en dépend meurt sur une distribution sur deux, avec le
# `backend=""` généralisé du §3 de docs/BUILD_LINUX_WSL.md.
#
# La sortie: `--disable-autodetect` coupe TOUTES les bibliothèques externes,
# mais garde les décodeurs NATIFS de FFmpeg — or Vorbis, Opus, AAC, ATRAC3,
# ATRAC3+, WMA, XMA, AC3, ALAC, MP3 et FLAC en font partie. On ne perd donc
# aucun format que vgmstream nous demande, et l'arbre de dépendances tombe à
# libc/libm/libz.
#
# ⚠️ Corollaire heureux pour la CI: la version de FFmpeg ne dépend plus de la
# distribution du conteneur. Le plancher glibc et FFmpeg deviennent deux
# questions SÉPARÉES.
#
# Usage:  scripts/appimage/build_ffmpeg_minimal.sh
set -euo pipefail

FFMPEG_VERSION="${REWAMP_FFMPEG_VERSION:-7.1}"

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$SRC/app/build/appimage"
OUT="$WORK/ffmpeg"
TARBALL="ffmpeg-${FFMPEG_VERSION}.tar.xz"

bold() { printf '\033[1m==> %s\033[0m\n' "$1"; }
die()  { printf '\033[31mERREUR: %s\033[0m\n' "$1" >&2; exit 1; }

if [[ -f "$OUT/include/libavcodec/avcodec.h" && -f "$OUT/lib/libavcodec.so" ]]; then
  bold "FFmpeg minimal déjà présent: $OUT  (effacer pour reconstruire)"
  exit 0
fi

for t in make pkg-config; do command -v "$t" >/dev/null || die "$t absent"; done
# ⚠️ x86_64 exige nasm pour l'assembleur; aarch64 n'en a pas besoin. L'absence
# de nasm ne casse PAS le build (FFmpeg retombe sur le C), elle le rend LENT et
# plus lourd — donc on prévient au lieu d'échouer.
if [[ "$(uname -m)" == "x86_64" ]] && ! command -v nasm >/dev/null; then
  printf '\033[33mATTENTION: nasm absent — FFmpeg sera bâti sans assembleur x86.\033[0m\n'
fi

mkdir -p "$WORK"
cd "$WORK"

if [[ ! -d "ffmpeg-${FFMPEG_VERSION}" ]]; then
  bold "Téléchargement de FFmpeg ${FFMPEG_VERSION}"
  [[ -f "$TARBALL" ]] || curl -fL --retry 3 -o "$TARBALL" \
    "https://ffmpeg.org/releases/${TARBALL}"
  tar xf "$TARBALL"
fi
cd "ffmpeg-${FFMPEG_VERSION}"

if [[ ! -f config.h ]]; then
  bold "configure"
  # Lecture seule, et rien d'externe. On GARDE:
  #   - tous les décodeurs, démultiplexeurs, parseurs et filtres de flux natifs
  #     (c'est le scope qu'on ne veut pas perdre en silence);
  #   - zlib, parce que des démultiplexeurs en dépendent et que libz.so.1 est
  #     présent partout — c'est la seule dépendance externe qu'on s'autorise.
  # On JETTE: programmes, doc, encodeurs, multiplexeurs, périphériques, réseau,
  # avfilter/swscale/avdevice (le CMake les lie « si présents », donc optionnels).
  ./configure \
    --prefix="$OUT" \
    --enable-shared --disable-static \
    --disable-programs --disable-doc \
    --disable-avdevice --disable-avfilter --disable-swscale --disable-postproc \
    --disable-encoders --disable-muxers --disable-devices \
    --disable-network --disable-protocols --enable-protocol=file \
    --disable-autodetect \
    --enable-zlib \
    --disable-debug \
    --enable-pic
fi

bold "make -j$(nproc)"
make -j"$(nproc)"
make install

# ── Contrôle: l'arbre de dépendances doit être RETOMBÉ ───────────────────────
# Le but de tout ce script est ce chiffre. On le vérifie sur l'artefact plutôt
# que de faire confiance aux drapeaux de configure.
bold "Dépendances de la libavcodec produite"
# ⚠️ DEUX pièges, les deux payés au premier run de CI (2026-09-24), et les deux
# invisibles sur la machine de développement:
#
#   * le chargeur dynamique n'a pas le même CHEMIN selon l'architecture —
#     `/lib/ld-linux-aarch64.so.1` mais `/lib64/ld-linux-x86-64.so.2`. Un
#     filtre écrit sur `/lib/ld-` laissait donc passer le chargeur x86_64 et
#     le comptait comme dépendance externe: le job x86_64 mourait sur
#     « 1 dépendance(s) externe(s) restante(s) » qui n'en était pas une. On
#     filtre désormais sur le NOM du chargeur, pas sur son dossier;
#   * `grep -v` rend 1 quand il ne sélectionne RIEN — c'est-à-dire dans le cas
#     NOMINAL, où tout a été filtré. Sous `set -e` (+ pipefail), le succès
#     TUAIT donc le script, sans un mot: c'est exactement ce qu'a fait le job
#     aarch64. D'où `|| true` sur le filtrage, et un `ldd` séparé qui, lui,
#     doit toujours échouer bruyamment s'il échoue.
RAW="$(ldd "$OUT/lib/libavcodec.so")"
DEPS="$(printf '%s\n' "$RAW" | awk '{print $1}' \
        | grep -vE '^(linux-vdso|libc\.so|libm\.so|libdl\.so|libpthread|librt\.so|libz\.so|libgcc_s|libstdc\+\+|libav|libsw)|(^|/)ld[-.][^/]*\.so' \
        | sort -u || true)"
n="$(printf '%s' "$DEPS" | grep -c . || true)"
if [[ "$n" -gt 0 ]]; then
  echo "$DEPS" | sed 's/^/    /'
  die "$n dépendance(s) externe(s) restante(s) — c'est exactement ce que ce script existe pour éviter."
fi
echo "    aucune (hors libc/libm/libz) ✓"

bold "OK — $OUT  ($(du -sh "$OUT/lib" | cut -f1) de bibliothèques)"
ls -la "$OUT/lib"/*.so.* 2>/dev/null | sed 's/^/    /'
