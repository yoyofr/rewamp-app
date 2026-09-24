#!/usr/bin/env bash
# Assemble l'AppImage Linux de Rewamp.
#
#   scripts/appimage/build_ffmpeg_minimal.sh   # une fois par machine
#   scripts/appimage/build_appimage.sh
#
# Le bundle Flutter est DÉJÀ relogeable ($ORIGIN/lib dans le RPATH): un AppDir
# n'est donc presque rien de plus que ce bundle, plus les trois bibliothèques
# que la distribution de l'utilisateur ne peut pas fournir de façon fiable.
#
# ── LA RÈGLE DE PARTAGE, et c'est tout le sujet ──────────────────────────────
#
# Un AppImage échoue de deux façons opposées, et il faut viser entre les deux:
#
#   - trop peu embarqué  → `.so` introuvable chez l'utilisateur, l'app ne démarre
#                          pas (ou, pour FFmpeg, démarre et ne joue RIEN — le
#                          `backend=""` du §3 de docs/BUILD_LINUX_WSL.md);
#   - trop embarqué      → une copie de glib/GTK/GL chargée À CÔTÉ de celle du
#                          système. Ça ne produit pas de message clair: ça plante
#                          ailleurs, plus tard.
#
# D'où trois tiroirs, décidés par MESURE (2026-09-21) et pas par habitude:
#
#   SYSTÈME, jamais embarqué : GTK3 + gdk/pango/cairo/atk/gdk-pixbuf/harfbuzz,
#     glib/gio/gobject, EGL, GLESv2, libasound, libc/libstdc++/libm/libz.
#     Présents partout où il y a un bureau, et les dupliquer est le piège ci-dessus.
#
#   NOUS, toujours embarqué : libav*/libswresample — le SONAME de FFmpeg change à
#     chaque millésime de distribution (58 sur Ubuntu 22.04, 60 sur 24.04, 61 sur
#     25.04); en dépendre, c'est mourir sur une distribution sur deux. Le nôtre
#     est bâti sans AUCUNE bibliothèque externe (voir build_ffmpeg_minimal.sh).
#
#   NOUS, par prudence : libsecret + libgcrypt + libgpg-error. libsecret est
#     exigée par flutter_secure_storage_linux, donc son absence empêche le
#     DÉMARRAGE. ⚠️ On embarque libsecret mais PAS sa pile glib: elle résout
#     glib/gio/gobject depuis le système, qui est exactement celle que GTK
#     utilise déjà. C'est la ligne de partage, et elle est volontaire.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP="$SRC/app"
WORK="$APP/build/appimage"
FFMPEG_DIR="$WORK/ffmpeg"
APPID=app.rewamp.Rewamp

bold() { printf '\033[1m==> %s\033[0m\n' "$1"; }
die()  { printf '\033[31mERREUR: %s\033[0m\n' "$1" >&2; exit 1; }

case "$(uname -m)" in
  x86_64)  FLUTTER_ARCH=x64;   ARCH=x86_64 ;;
  aarch64) FLUTTER_ARCH=arm64; ARCH=aarch64 ;;
  *) die "architecture non gérée: $(uname -m)" ;;
esac
export ARCH                      # appimagetool le lit

# ⚠️ Pas de TUBE vers un lecteur qui s'arrête tôt (`head`, `awk … exit`): celui
# qui écrit reçoit SIGPIPE, le tube rend 141, et sous `set -e` + pipefail le
# script MEURT — d'autant plus volontiers que la sortie est grosse ou la machine
# lente. Payé le 2026-09-24: la CI aarch64 est morte à 141 sur le contrôle des
# RUNPATH (`objdump | awk … exit`) là où la machine de dev passait. Partout où
# l'on ne veut que la PREMIÈRE ligne, on lit la source directement ou on passe
# par une chaîne déjà capturée (`<<<`), jamais par un tube.
VERSION_FULL="$(awk -F': *' '/^version:/{print $2; exit}' "$APP/pubspec.yaml")"
VERSION="${VERSION_FULL%%+*}"
[[ -n "$VERSION" ]] || die "version introuvable dans app/pubspec.yaml"

# ── 1. FFmpeg minimal ────────────────────────────────────────────────────────
[[ -f "$FFMPEG_DIR/lib/libavcodec.so" ]] \
  || "$SRC/scripts/appimage/build_ffmpeg_minimal.sh"

# ── 2. Le bundle, bâti sur l'HÔTE et contre NOTRE FFmpeg ─────────────────────
# ⚠️ Pas le bundle du SDK flatpak: celui-là est lié à glibc 2.38 et au FFmpeg du
# runtime. Le marqueur dit quelle chaîne a écrit le dossier de build; une
# chaîne différente le fait effacer, sinon les objets se mélangeraient.
BUNDLE="$APP/build/linux/$FLUTTER_ARCH/release/bundle"
MARKER="$APP/build/linux/.toolchain"
WANT="host-appimage-$ARCH"

if [[ ! -x "$BUNDLE/rewamp" || "$(cat "$MARKER" 2>/dev/null)" != "$WANT" ]]; then
  bold "Chaîne d'outils différente — reconstruction complète du bundle"
  rm -rf "$APP/build/linux"
  mkdir -p "$APP/build/linux"
  # ⚠️ `app/build/flutter_assets` est PARTAGÉ avec le mode debug: un seul
  # `flutter run` y laisse kernel_blob.bin (97 Mo, MORT en release) et
  # l'installation copie le dossier entier. Voir docs/FLATPAK.md §6.
  rm -f "$APP/build/flutter_assets/kernel_blob.bin"
  # REWAMP_FFMPEG_DIR passe par l'ENVIRONNEMENT, ce que CMake ne sait pas faire
  # seul — voir `rewamp_option` dans cmake/rewamp.cmake.
  ( cd "$APP" && REWAMP_FFMPEG_DIR="$FFMPEG_DIR" flutter build linux --release )
  echo "$WANT" > "$MARKER"
fi
[[ -x "$BUNDLE/rewamp" ]] || die "bundle absent: $BUNDLE"
[[ -e "$BUNDLE/data/flutter_assets/kernel_blob.bin" ]] \
  && die "kernel_blob.bin (blob JIT debug, ~97 Mo) est dans le bundle release"

# Le contrôle qui compte: c'est bien NOTRE FFmpeg qui est lié, pas celui du système.
NEEDED_FF="$(objdump -p "$BUNDLE/lib/librewamp_audio.so" | awk '/NEEDED/{print $2}' \
             | grep -E '^lib(av|sw)' || true)"
[[ -n "$NEEDED_FF" ]] || die "librewamp_audio.so ne réclame AUCUNE bibliothèque FFmpeg —
       vgmstream a été bâti sans, et la perte de formats serait SILENCIEUSE."

# ── 3. L'AppDir ──────────────────────────────────────────────────────────────
APPDIR="$WORK/Rewamp.AppDir"
bold "AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/metainfo" "$APPDIR/usr/share/applications"

cp -a "$BUNDLE" "$APPDIR/usr/rewamp"

# Les bibliothèques qu'on embarque, à côté des siennes: le RPATH $ORIGIN/lib du
# binaire les trouve sans qu'on ait à toucher LD_LIBRARY_PATH — ce qui serait
# justement le moyen de contaminer GTK.
bold "Bibliothèques embarquées"
for so in "$FFMPEG_DIR"/lib/lib*.so.*; do
  [[ -f "$so" && ! -L "$so" ]] || continue
  cp -a "$so" "$APPDIR/usr/rewamp/lib/"
  ( cd "$APPDIR/usr/rewamp/lib" && ln -sfn "$(basename "$so")" \
      "$(basename "$so" | sed 's/\(\.so\.[0-9]*\).*/\1/')" )
done
# libbz2: réclamée par librewamp_audio (libarchive). C'est une FEUILLE — rien
# derrière elle que libc, mesuré — donc aucun risque de conflit, et elle manque
# sur un système minimal.
LDCONFIG_CACHE="$(ldconfig -p)"   # lu UNE fois; voir la note sur les tubes
for name in libsecret-1.so.0 libgcrypt.so.20 libgpg-error.so.0 libbz2.so.1.0; do
  f="$(awk -v n="$name" '$1==n{print $NF; exit}' <<<"$LDCONFIG_CACHE")"
  [[ -n "$f" ]] || die "$name introuvable sur cette machine"
  cp -L "$f" "$APPDIR/usr/rewamp/lib/$name"
done
( cd "$APPDIR/usr/rewamp/lib" && for f in *; do
    [[ -L "$f" ]] && continue
    printf '    %-44s %8s\n' "$f" "$(du -h "$f" | cut -f1)"
  done )

# Intégration bureau. ⚠️ Le .desktop ET l'icône doivent être à la RACINE de
# l'AppDir (c'est là qu'appimagetool les lit), en plus de usr/share pour les
# systèmes qui intègrent l'AppImage.
PKG="$APP/linux/packaging"
install -Dm644 "$PKG/$APPID.desktop"       "$APPDIR/usr/share/applications/$APPID.desktop"
install -Dm644 "$PKG/$APPID.metainfo.xml"  "$APPDIR/usr/share/metainfo/$APPID.metainfo.xml"
for s in 48 64 128 256 512; do
  install -Dm644 "$PKG/icons/hicolor/${s}x${s}/apps/$APPID.png" \
          "$APPDIR/usr/share/icons/hicolor/${s}x${s}/apps/$APPID.png"
done
install -Dm644 "$PKG/icons/hicolor/scalable/apps/$APPID.svg" \
        "$APPDIR/usr/share/icons/hicolor/scalable/apps/$APPID.svg"
cp "$PKG/$APPID.desktop" "$APPDIR/$APPID.desktop"
cp "$PKG/icons/hicolor/256x256/apps/$APPID.png" "$APPDIR/$APPID.png"
ln -sf "$APPID.png" "$APPDIR/.DirIcon"

install -Dm755 "$SRC/scripts/appimage/AppRun" "$APPDIR/AppRun"
ln -sf ../rewamp/rewamp "$APPDIR/usr/bin/rewamp"

# ── 4. Relocalisation: tous les RUNPATH ramenés à $ORIGIN ────────────────────
# ⚠️ C'est l'étape sans laquelle l'AppImage ne marche QUE sur la machine qui l'a
# compilé, en silence — payé le 2026-09-21.
#
# Le gabarit Flutter installe les bibliothèques de greffons par
# `install(FILES ...)` et non `install(TARGETS ...)`: CMake ne réécrit donc
# jamais leur RUNPATH, et les NEUF y partent avec celui de l'arbre de build
# (`…/app/build/…`, `…/linux/flutter/ephemeral`). Seul l'EXÉCUTABLE reçoit
# `$ORIGIN/lib`.
#
# ⚠️ Et un `DT_RUNPATH` ne s'HÉRITE PAS: pour résoudre `libavcodec.so.61`,
# réclamée par `librewamp_audio.so`, l'éditeur de liens dynamique lit le RUNPATH
# de CETTE bibliothèque — pas celui de l'exécutable. Constaté en mesurant
# /proc/<pid>/maps de l'AppImage qui tournait: elle chargeait son FFmpeg depuis
# le dossier de build.
#
# ⚠️ On ne pose PAS LD_LIBRARY_PATH dans l'AppRun à la place. Ça marcherait,
# mais la variable est HÉRITÉE par les processus enfants — et url_launcher lance
# `xdg-open`, donc le navigateur du système hériterait de nos bibliothèques.
PATCHELF="$WORK/patchelf"
if [[ ! -x "$PATCHELF" ]]; then
  bold "Téléchargement de patchelf"
  PE_VER="${REWAMP_PATCHELF_VERSION:-0.18.0}"
  curl -fL --retry 3 -o "$WORK/patchelf.tar.gz" \
    "https://github.com/NixOS/patchelf/releases/download/${PE_VER}/patchelf-${PE_VER}-${ARCH}.tar.gz"
  tar xzf "$WORK/patchelf.tar.gz" -C "$WORK" ./bin/patchelf
  mv "$WORK/bin/patchelf" "$PATCHELF"
  rmdir "$WORK/bin" 2>/dev/null || true
  chmod +x "$PATCHELF"
fi

bold "Relocalisation des RUNPATH"
n=0
while read -r f; do
  "$PATCHELF" --set-rpath '$ORIGIN' "$f" && n=$((n+1))
done < <(find "$APPDIR/usr/rewamp/lib" -name '*.so*' -type f)
echo "    $n bibliothèques ramenées à \$ORIGIN"

# ── 5. Le contrôle de partage ────────────────────────────────────────────────
# L'oracle de ce script: TOUT soname externe doit être soit embarqué, soit dans
# la liste sanctionnée du système. Une dépendance nouvelle qui apparaît un jour
# (mise à jour d'un greffon Flutter, moteur ajouté) sort ici et pas chez
# l'utilisateur.
bold "Contrôle du partage embarqué / système"
# ⚠️ libepoxy est dans le tiroir SYSTÈME et pas dans le nôtre, alors qu'elle
# n'est ni glib ni GTK: `libgtk-3.so.0` la réclame elle-même (vérifié), donc
# elle est présente partout où GTK3 l'est — et c'est la couche de dispatch GL,
# qui doit correspondre au GL du système. L'embarquer serait activement faux.
#
# ⚠️ libfontconfig / libfreetype: MÊME raisonnement, et la question s'est posée
# pour de bon le 2026-09-24 — `libfontconfig.so.1` est sortie « INATTENDU » sur
# le job x86_64 et PAS sur aarch64 (les greffons Flutter ne la réclament pas
# directement partout). Tiroir SYSTÈME: c'est la pile de POLICES, réclamée par
# pango/cairo donc présente partout où GTK3 l'est, et elle lit la configuration
# et les caches de fontes de la MACHINE. En embarquer une autre version, c'est
# se retrouver avec deux moteurs de rendu de texte dont un ne voit pas les
# polices du système.
SYSTEM_OK='^(libc|libm|libdl|libpthread|librt|libz|libstdc\+\+|libgcc_s|ld-linux.*|linux-vdso|libgtk-3|libgdk-3|libgdk_pixbuf-2\.0|libpango-1\.0|libpangocairo-1\.0|libcairo|libcairo-gobject|libatk-1\.0|libharfbuzz|libglib-2\.0|libgio-2\.0|libgobject-2\.0|libgmodule-2\.0|libEGL|libGLESv2|libepoxy|libasound|libfontconfig|libfreetype)\.so'
BUNDLED="$(cd "$APPDIR/usr/rewamp/lib" && ls)"
unknown=0
while read -r so; do
  [[ -n "$so" ]] || continue
  grep -qx "$so" <<<"$BUNDLED" && continue
  [[ "$so" =~ $SYSTEM_OK ]] && continue
  echo "    INATTENDU: $so"
  unknown=1
done < <(for f in "$APPDIR/usr/rewamp/rewamp" "$APPDIR/usr/rewamp/lib"/*.so*; do
           [[ -f "$f" && ! -L "$f" ]] && objdump -p "$f" 2>/dev/null | awk '/NEEDED/{print $2}'
         done | sort -u)
[[ $unknown -eq 0 ]] || die "dépendance hors des deux tiroirs — décider laquelle, ne pas l'ignorer"
echo "    tout est soit embarqué, soit dans la pile système sanctionnée ✓"

# ⚠️ Le contrôle ci-dessus dit que la bibliothèque est PRÉSENTE. Il ne dit pas
# qu'elle sera TROUVÉE — et c'est un piège distinct, payé le 2026-09-21:
# `librewamp_audio.so` partait avec le RUNPATH de l'arbre de BUILD, parce que le
# gabarit Flutter installe les greffons par `install(FILES)`, ce qui ne réécrit
# aucun RPATH. L'AppImage tournait ici en chargeant son FFmpeg depuis
# `…/app/build/…`, un chemin qui n'existe sur aucune autre machine — et un
# `DT_RUNPATH` ne s'HÉRITE PAS, donc le `$ORIGIN/lib` de l'exécutable ne
# rattrape pas les dépendances de ses bibliothèques.
bold "Contrôle des RUNPATH"
bad=0
while read -r f; do
  hdr="$(objdump -p "$f" 2>/dev/null || true)"
  rp="$(awk '/R(UN)?PATH/{print $2; exit}' <<<"$hdr")"
  [[ -z "$rp" ]] && continue
  IFS=: read -ra parts <<<"$rp"
  for part in "${parts[@]}"; do
    case "$part" in \$ORIGIN*|'$ORIGIN'*) ;; *)
      echo "    $(basename "$f"): $rp"; bad=1 ;;
    esac
  done
done < <(find "$APPDIR/usr/rewamp" -name '*.so*' -type f; echo "$APPDIR/usr/rewamp/rewamp")
[[ $bad -eq 0 ]] || die "un RUNPATH sort de \$ORIGIN — le bundle ne marcherait que sur CETTE machine"
echo "    tous relatifs à \$ORIGIN ✓"

# ── 6. appimagetool ──────────────────────────────────────────────────────────
TOOL="$WORK/appimagetool-$ARCH.AppImage"
if [[ ! -x "$TOOL" ]]; then
  bold "Téléchargement d'appimagetool"
  curl -fL --retry 3 -o "$TOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
  chmod +x "$TOOL"
fi

OUT="$WORK/Rewamp-$VERSION-$ARCH.AppImage"
rm -f "$OUT"
bold "appimagetool"
# appimagetool est lui-même un AppImage, donc il voudrait FUSE pour se monter.
# ⚠️ `--appimage-extract-run` NE MARCHE PAS avec son runtime « continuous »
# (« is not yet implemented in version … »), contrairement à ce que la plupart
# des recettes en ligne racontent. On essaie donc l'exécution directe, et on
# retombe sur une extraction UNE fois si FUSE manque — ce qui rend ce script
# utilisable dans un conteneur de CI sans FUSE, où l'exécution directe échoue.
if "$TOOL" --version >/dev/null 2>&1; then
  "$TOOL" "$APPDIR" "$OUT"
else
  bold "FUSE indisponible — extraction d'appimagetool"
  EX="$WORK/appimagetool-extracted"
  if [[ ! -x "$EX/AppRun" ]]; then
    rm -rf "$WORK/squashfs-root" "$EX"
    ( cd "$WORK" && "$TOOL" --appimage-extract >/dev/null )
    mv "$WORK/squashfs-root" "$EX"
  fi
  "$EX/AppRun" "$APPDIR" "$OUT"
fi

[[ -f "$OUT" ]] || die "appimagetool n'a rien produit"
chmod +x "$OUT"

bold "OK — $OUT  ($(du -h "$OUT" | cut -f1))"
# ⚠️ Ce que l'utilisateur doit avoir — MESURÉ sur l'artefact, pas repris des
# recettes en ligne, qui datent et se trompent deux fois:
#
#   * le runtime embarqué est `static-pie` (vérifié par `file`): il ne dépend
#     d'AUCUNE libfuse dynamique. Le vieux « installez libfuse2 » ne s'applique
#     pas à un AppImage bâti avec cet appimagetool. Il lui faut `fusermount3`
#     et /dev/fuse, présents sur tout bureau moderne.
#   * `--appimage-extract-run` N'EXISTE PAS dans ce runtime — il répond
#     « is not yet implemented in version … ». Le repli qui marche est
#     `--appimage-extract`, qui écrit un dossier `squashfs-root/`.
cat <<EOF

Notes pour les utilisateurs (mesuré sur cet artefact, $(date +%Y-%m-%d)):
  · le runtime est statiquement lié — PAS besoin de libfuse2; il lui faut
    fusermount3 et /dev/fuse, présents sur tout bureau moderne;
  · si le montage échoue malgré tout, le repli est:
        ./$(basename "$OUT") --appimage-extract && ./squashfs-root/AppRun
    (⚠️ et NON --appimage-extract-run, que ce runtime n'implémente pas).
EOF
