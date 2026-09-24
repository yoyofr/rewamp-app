#!/usr/bin/env bash
# Oracle du fondu de fin PSF (tag `fade`), deux niveaux:
#   1. la RAMPE elle-même et ses trois exceptions (pure, sans moteur);
#   2. le CÂBLAGE sur un vrai .psf, si on lui en donne un — RMS par seconde,
#      qui doit descendre en fin de piste et NE PAS descendre sous crossfade
#      ni sous repeat infini.
#   scripts/verify_psf_fade.sh [fichier.psf]
set -euo pipefail
pkg="$(cd "$(dirname "$0")/.." && pwd)"
out="${TMPDIR:-/tmp}/verify_psf_fade"
mkdir -p "$out" 2>/dev/null || true
cc -std=gnu11 -O1 -Wall -I"$pkg/src" "$pkg/scripts/verify_psf_fade.c" -o "$out/pure" -lm
"$out/pure"

[ $# -ge 1 ] || { echo "(pas de .psf fourni: câblage non vérifié)"; exit 0; }

he="$pkg/third_party/highlyexperimental"; psf="$pkg/third_party/libpsflib"
cat > "$out/globals.c" <<'G'
int    g_force_loop_mode = 0, g_force_loop_count = 0;
int    g_force_loop_native_veto = 0, g_force_fadeout_enabled = 0;
double g_force_fadeout_seconds = 0.0, g_force_base_duration_secs = 0.0;
double g_crossfade_seconds = 0.0;
volatile int g_seek_cancel = 0, g_is_seeking = 0;
volatile double g_seek_progress_s = 0.0;
/* ⚠️ TROIS arguments, dont la valeur PAR DÉFAUT — un stub à deux arguments
   rendait 0 et coupait le SPU (spu_enable_main(0)): piste entièrement muette,
   et le harnais accusait le fondu. */
double rewamp_get_engine_param(const char* e, const char* k, double def) {
    (void)e; (void)k; return def;
}
G
flags=(-std=gnu11 -O1 -w -I"$pkg/src" -I"$pkg/third_party" -I"$psf"
       -DEMU_COMPILE -DEMU_LITTLE_ENDIAN -DHAVE_STDINT_H -DREWAMP_WITH_HIGHLYEXP=1)
for c in "$he"/Core/{psx,ioptimer,iop,bios,r3000dis,r3000asm,r3000,vfs,spucore,spu,mkhebios}.c \
         "$psf"/psflib.c "$psf"/psf2fs.c "$pkg"/src/rewamp_plugin_highlyexp.c; do
  o="$out/$(basename "$c").o"
  [ "$o" -nt "$c" ] || cc "${flags[@]}" -c "$c" -o "$o"
done
build() {  # $1 = suffixe, $2… = defines de contexte
  cc "${flags[@]}" "$@" "$pkg/scripts/verify_psf_fade_real.c" "$out/globals.c" \
     "$out"/*.o "$pkg/src/rewamp_channel_data.c" "$pkg/src/rewamp_loaded_files.c" \
     -o "$out/real" -lz -lm -liconv
}
echo; echo "── lecture normale (le fondu doit s'entendre)"; build; "$out/real" "$1"
echo; echo "── crossfade actif (aucun fondu natif)"
sed -i '' 's/g_crossfade_seconds = 0.0/g_crossfade_seconds = 4.0/' "$out/globals.c"
build; "$out/real" "$1" | tail -2 || true   # sortie 4 attendue: pas de fondu
echo; echo "── repeat infini (aucun fondu natif)"
sed -i '' 's/g_crossfade_seconds = 4.0/g_crossfade_seconds = 0.0/; s/g_force_loop_mode = 0/g_force_loop_mode = 2/' "$out/globals.c"
build; "$out/real" "$1" | tail -2 || true   # sortie 4 attendue: pas de fondu
