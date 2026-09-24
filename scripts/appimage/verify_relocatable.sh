#!/usr/bin/env bash
# Oracle: l'AppImage charge-t-elle SES bibliothèques, ou celles de la machine
# qui l'a compilée ?
#
# La question n'est pas rhétorique. Le 2026-09-21, un AppImage qui démarrait
# parfaitement ici chargeait `libavcodec.so.61` depuis
# `…/app/build/appimage/ffmpeg/lib` — un chemin qui n'existe sur AUCUNE autre
# machine. Cause: le gabarit Flutter installe les bibliothèques de greffons par
# `install(FILES ...)`, ce qui ne réécrit aucun RUNPATH, et un `DT_RUNPATH` ne
# s'HÉRITE PAS pour les dépendances transitives. Rien ne le signalait.
#
# ⚠️ Un contrôle statique des RUNPATH (fait par build_appimage.sh) ne suffit
# pas à le prouver: il dit ce que le binaire DEMANDE, pas ce que l'éditeur de
# liens dynamique FINIT par charger. Le seul oracle honnête est de faire
# DISPARAÎTRE l'arbre de build et de regarder /proc/<pid>/maps.
#
# Usage:  scripts/appimage/verify_relocatable.sh [chemin/vers/Rewamp-*.AppImage]
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$SRC/app/build/appimage"

bold() { printf '\033[1m==> %s\033[0m\n' "$1"; }
die()  { printf '\033[31mERREUR: %s\033[0m\n' "$1" >&2; exit 1; }

APPIMAGE="${1:-$(ls -t "$WORK"/Rewamp-*.AppImage 2>/dev/null | head -1)}"
[[ -x "$APPIMAGE" ]] || die "AppImage introuvable — scripts/appimage/build_appimage.sh d'abord"

# ⚠️ L'app doit pouvoir s'afficher: c'est en démarrant pour de vrai qu'elle
# charge ses bibliothèques. Sans session graphique, cet oracle ne dit rien.
[[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || die "aucune session graphique — cet oracle démarre l'app"

hidden=0
cleanup() {
  [[ $hidden -eq 1 && -d "$WORK/ffmpeg.hidden" ]] && mv "$WORK/ffmpeg.hidden" "$WORK/ffmpeg"
  [[ -n "${PID:-}" ]] && kill "$PID" 2>/dev/null
  return 0
}
trap cleanup EXIT

if [[ -d "$WORK/ffmpeg" ]]; then
  mv "$WORK/ffmpeg" "$WORK/ffmpeg.hidden"; hidden=1
  bold "Arbre de build de FFmpeg caché — il ne peut plus servir de repli"
fi

"$APPIMAGE" >/tmp/rewamp-reloc.log 2>&1 &
PID=""
for _ in $(seq 1 40); do
  for d in /proc/[0-9]*; do
    case "$(readlink "$d/exe" 2>/dev/null)" in */usr/rewamp/rewamp*) PID="${d#/proc/}";; esac
  done
  [[ -n "$PID" ]] && break
  sleep 1
done
# ⚠️ Chercher le processus par `pgrep -f` se trompe: la ligne de commande de ce
# script CONTIENT le motif, donc pgrep se trouve lui-même. On passe par
# /proc/<pid>/exe, qui ne ment pas.
[[ -n "$PID" ]] || { tail -20 /tmp/rewamp-reloc.log; die "l'app n'a pas démarré"; }

sleep 4
MAPS="$(cat /proc/$PID/maps)"

bold "D'où viennent les bibliothèques embarquées"
bad=0
for lib in libavcodec libavformat libavutil libswresample libsecret libgcrypt libbz2; do
  path="$(grep -oE "/[^ ]*${lib}[^ ]*" <<<"$MAPS" | sort -u | head -1 || true)"
  if [[ -z "$path" ]]; then
    printf '    %-14s %s\n' "$lib" "(pas chargée)"
  elif [[ "$path" == /tmp/.mount_* ]]; then
    printf '    %-14s ✓ depuis l'"'"'AppImage\n' "$lib"
  else
    printf '    %-14s ✗ %s\n' "$lib" "$path"; bad=1
  fi
done
[[ $bad -eq 0 ]] || die "une bibliothèque vient d'AILLEURS que de l'AppImage —
       sur la machine d'un utilisateur, ce chemin n'existera pas."

bold "OK — l'AppImage ne dépend d'aucun chemin de cette machine"
