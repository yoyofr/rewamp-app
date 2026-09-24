#!/usr/bin/env bash
# Régénère l'arbre libxmp vendoré (third_party/libxmp) depuis l'amont épinglé
# + les patchs rewamp. Même philosophie que sync_libkss.sh / sync_adplug.sh.
#
# Ce que rewamp modifie dans libxmp tient en UN fichier — mixer.c, où trois
# accroches publient la capture par voix (rewamp_xmp_capture.h). Tout le reste
# est de l'amont pur:
#
#   third_party/libxmp/{include,src}/**     arbre vendoré (ce qui compile)
#   third_party/libxmp/upstream/<relpath>   copie PRISTINE des fichiers patchés
#   third_party/libxmp/rewamp_xmp_*.h       fichiers À NOUS (renommage + capture)
#   patches/libxmp/<basename>.patch         les modifications rewamp
#   patches/libxmp/UPSTREAM_VERSION         tag + commit amont épinglés
#
# Usage:
#   ./scripts/sync_libxmp.sh              # ré-applique les patchs sur le vendoré
#   ./scripts/sync_libxmp.sh <git-ref>    # RE-VENDORE cette référence amont,
#                                         # rafraîchit upstream/ + UPSTREAM_VERSION,
#                                         # puis ré-applique
#
# ⚠️ Le jeu de fichiers vendoré est celui que l'AMONT compile, pas `*.c` en vrac:
#   - src/depackers/ et src/lite/ ne sont PAS vendorés (LIBXMP_NO_DEPACKERS: nos
#     archives passent par libarchive, et les depackers de libxmp dupliquent
#     zip/lzma/crc32),
#   - src/loaders/prowizard/ ne l'est pas non plus (LIBXMP_NO_PROWIZARD:
#     third_party/prowizard EST ce code, vendoré à part en convertisseur),
#   - src/lutgen.c est un GÉNÉRATEUR (il a un main()), pas une source.
# Un fichier de trop ici, c'est un `main` ou des symboles en double au lien.
set -euo pipefail

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XMP_DIR="$PKG_DIR/third_party/libxmp"
UP_DIR="$XMP_DIR/upstream"
PATCH_DIR="$PKG_DIR/patches/libxmp"

REF="${1:-}"

if [ -n "$REF" ]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "== clone amont $REF"
  git clone --depth 1 --branch "$REF" https://github.com/libxmp/libxmp "$TMP/libxmp"
  COMMIT="$(git -C "$TMP/libxmp" rev-parse HEAD)"

  echo "== re-vendoring"
  rm -rf "$XMP_DIR/include" "$XMP_DIR/src"
  cp -R "$TMP/libxmp/include" "$XMP_DIR/include"
  cp -R "$TMP/libxmp/src"     "$XMP_DIR/src"
  rm -rf "$XMP_DIR/src/depackers" "$XMP_DIR/src/lite" "$XMP_DIR/src/bitrot" \
         "$XMP_DIR/src/loaders/prowizard" "$XMP_DIR/src/lutgen.c" \
         "$XMP_DIR/src/Makefile" "$XMP_DIR/src/loaders/Makefile"
  cp "$TMP/libxmp/docs/COPYING" "$XMP_DIR/COPYING"
  cp "$TMP/libxmp/docs/CREDITS" "$XMP_DIR/CREDITS"
  cp "$TMP/libxmp/README"       "$XMP_DIR/README"

  mkdir -p "$UP_DIR/src"
  cp "$TMP/libxmp/src/mixer.c" "$UP_DIR/src/mixer.c"
  printf '%s\n%s\n' "$REF" "$COMMIT" > "$PATCH_DIR/UPSTREAM_VERSION"
fi

echo "== application des patchs"
for p in "$PATCH_DIR"/*.patch; do
  [ -e "$p" ] || continue
  rel="src/$(basename "$p" .patch)"
  cp "$UP_DIR/$rel" "$XMP_DIR/$rel"
  patch -p0 -d "$XMP_DIR" --quiet < "$p" || {
    echo "ÉCHEC: $p ne s'applique pas sur l'amont" >&2
    exit 1
  }
  echo "   $rel"
done

cat <<'NOTE'

Rappels APRÈS une resynchro:
  - régénérer rewamp_xmp_rename.h si l'amont a ajouté/retiré un symbole global
    hors namespace xmp_/libxmp_ (nm sur une compilation isolée; la liste sert à
    éviter les doublons avec third_party/prowizard et uade),
  - relancer scripts/verify_xmp_notes.sh (l'échelle des notes est le défaut que
    cet oracle attrape),
  - rebâtir: `cd app && flutter build macos --debug`.
NOTE
