#!/usr/bin/env bash
# Régénère les fichiers v2redux patchés (third_party/v2redux/src/…) depuis les
# copies amont pristine + les patchs rewamp. Même philosophie que
# sync_adplug.sh: v2redux n'est PAS un submodule, son src/ est commité tel quel.
#
#   ./scripts/sync_v2redux.sh              # ré-applique les patchs sur l'amont vendoré
#   ./scripts/sync_v2redux.sh <git-ref>    # clone cette révision amont, RE-VENDORE
#                                          # tout le src/, rafraîchit upstream/ +
#                                          # UPSTREAM_BASE, puis ré-applique
#
# Ce que portent les patchs (tous DISPLAY-ONLY, hors du contrat de déterminisme
# du moteur — ils lisent le bus de canal et n'y reviennent jamais):
#   v2core.cpp   oscilloscope par voix (m_voice_buff) + hauteur de note
#                (vgm_last_note, posée au note-on, effacée au note-off)
#   v2redux.h    déclaration de lastEventMs()
#   v2player.cpp lastEventMs() — l'instant du DERNIER événement de séquence.
#                ⚠️ lengthMs() rend la fin de la SÉQUENCE, qui peut se trouver
#                très loin après la dernière note: fr019 a 5:36 de musique et
#                lengthMs() annonce 67:04. Sans ça un morceau de 5 minutes
#                afficherait une heure et ne finirait jamais.
#
# Layout:
#   third_party/v2redux/upstream/*   pristine (commité)
#   patches/v2redux/*.patch          mods rewamp (commité)
#   third_party/v2redux/src/*        vendoré + patché (commité — c'est ce qui build)
set -euo pipefail

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
V2_DIR="$PKG_DIR/third_party/v2redux"
PATCH_DIR="$PKG_DIR/patches/v2redux"
PATCHED_FILES="v2core.cpp v2redux.h v2player.cpp"
LIB_SOURCES="v2player.cpp v2load.cpp v2core.cpp v2seq.cpp ronan.cpp"

if [ -n "${1:-}" ]; then
  REF="$1"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "clonage de v2redux@$REF …"
  git clone --quiet "https://github.com/spheenik/v2redux" "$TMP/v2redux"
  git -C "$TMP/v2redux" checkout --quiet "$REF"
  git -C "$TMP/v2redux" rev-parse HEAD > "$PATCH_DIR/UPSTREAM_BASE"
  rm -f "$V2_DIR"/src/*.cpp "$V2_DIR"/src/*.h
  cp "$TMP/v2redux"/src/*.cpp "$TMP/v2redux"/src/*.h "$V2_DIR/src/"
  # v2dump = la CLI, v2play = le visualiseur sokol: ni l'un ni l'autre n'est la
  # bibliothèque, et tous deux tirent des dépendances qu'on n'a pas.
  rm -f "$V2_DIR/src/v2dump.cpp" "$V2_DIR/src/v2play.cpp"
  cp "$TMP/v2redux/LICENSE" "$V2_DIR/" 2>/dev/null || true
  for f in $PATCHED_FILES; do cp "$V2_DIR/src/$f" "$V2_DIR/upstream/$f"; done
fi

for f in $PATCHED_FILES; do
  cp "$V2_DIR/upstream/$f" "$V2_DIR/src/$f"
  if ! patch --quiet -p0 -d "$V2_DIR/src" -i "$PATCH_DIR/$f.patch" 2>/dev/null; then
    echo "CONFLIT: $f.patch ne s'applique pas — résoudre à la main, puis" >&2
    echo "  diff -u $V2_DIR/upstream/$f $V2_DIR/src/$f > $PATCH_DIR/$f.patch" >&2
    exit 1
  fi
  echo "appliqué: $f.patch"
done

# Contrôle: les cinq sources de la bibliothèque sont bien là.
for f in $LIB_SOURCES; do
  [ -f "$V2_DIR/src/$f" ] || { echo "manquant: src/$f" >&2; exit 1; }
done
echo "done — v2redux à $(cat "$PATCH_DIR/UPSTREAM_BASE" | cut -c1-12), patchs appliqués."
