#!/usr/bin/env bash
# Met le submodule libvgm sur le commit amont épinglé et réapplique les patchs
# rewamp (captures d'oscilloscope par voix et de notes) par-dessus, en
# modifications d'ARBRE DE TRAVAIL. Le pointeur de submodule reste sur un vrai
# SHA amont, donc un clone frais peut toujours le récupérer; les patchs vivent
# dans patches/libvgm/ et sont rejoués par ce script (idempotent).
#
# Usage:
#   ./scripts/sync_libvgm.sh            # base épinglée + patchs
#   ./scripts/sync_libvgm.sh <sha|tag>  # tenter les patchs sur un amont PLUS
#                                       # RÉCENT (met à jour UPSTREAM_BASE si OK)
#
# Un patch par FICHIER: un fichier qui bouge chez ValleyBell ne fait échouer que
# son propre patch, et la reprise est chirurgicale. Voir patches/libvgm/README.md
# — en particulier pourquoi on ne « nettoie » PAS ces patchs des espaces.
set -euo pipefail

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SUB="$PKG_DIR/third_party/libvgm/libvgm"
PATCH_DIR="$PKG_DIR/patches/libvgm"
BASE_FILE="$PATCH_DIR/UPSTREAM_BASE"

if [ ! -d "$SUB/.git" ] && [ ! -f "$SUB/.git" ]; then
  echo "error: submodule non initialisé. Lancer: git submodule update --init $SUB" >&2
  exit 1
fi

TARGET="${1:-$(cat "$BASE_FILE")}"

cd "$SUB"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "note: modifications locales écartées (elles sont régénérées depuis patches/)"
  git checkout -q -f -- .
  git clean -qfd
fi

git fetch origin --quiet
git checkout --quiet "$TARGET"
echo "libvgm sur $(git rev-parse --short HEAD) ($(git log -1 --format=%s | cut -c1-60))"

fail=0
for patch in "$PATCH_DIR"/*.patch; do
  if git apply --check "$patch" 2>/dev/null; then
    git apply "$patch"
  elif git apply --check --reverse "$patch" 2>/dev/null; then
    :   # déjà appliqué
  else
    echo "CONFLIT: $(basename "$patch")" >&2
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  cat >&2 <<'MSG'

Un ou plusieurs patchs ne s'appliquent pas sur cette révision. Marche à suivre:
  1. git apply -3 <le patch>            # fusion 3 voies, souvent suffisante
  2. résoudre les marqueurs de conflit dans le fichier
  3. régénérer CE patch: git diff -- <fichier> > <le patch>
  4. relancer ce script, puis mettre à jour UPSTREAM_BASE
Un patch dont le FICHIER a disparu amont a été renommé: retrouver le nouveau nom
(git log --diff-filter=D --all -- <ancien>) et porter le contenu à la main.
MSG
  exit 1
fi

if [ -n "${1:-}" ]; then
  git rev-parse HEAD > "$BASE_FILE"
  echo "UPSTREAM_BASE mis à jour: $(git rev-parse --short HEAD)"
  echo "Penser à committer le nouveau pointeur de submodule dans le superprojet."
fi

echo "done — patchs appliqués en arbre de travail (pointeur de submodule = SHA amont)."
