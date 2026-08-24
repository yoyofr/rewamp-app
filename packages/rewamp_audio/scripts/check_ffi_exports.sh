#!/usr/bin/env bash
# Guard against the recurring "silently mangled FFI export" bug.
#
# REWAMP_EXPORT alone does NOT give a C++ TU C linkage: it only sets symbol
# visibility. A function defined in a .cpp/.mm and neither marked extern "C"
# nor declared inside the extern "C" block of a header ends up as
# `_Z31rewamp_..i` in the binary, so `lib.lookupFunction('rewamp_..')` throws —
# and every one of those lookups sits in a try/catch, so the feature just
# silently does nothing.
#
# Cost so far: four debug sessions (set_pixel_scale, set_layout, set_opaque_bg
# + future_seconds). Run this instead of paying a fifth:
#
#   packages/rewamp_audio/scripts/check_ffi_exports.sh
#
# Checks, per name Dart looks up:
#   1. its definition is in a .c file, or is marked extern "C", or is declared
#      in a C API header (src/*.h) that the defining TU includes;
#   2. if a built Android .so is present, that no rewamp_* symbol is mangled
#      (the ground truth — a header declaration the defining TU never includes
#      still yields a mangled symbol).
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
src="$root/packages/rewamp_audio/src"

names=$( { grep -rhoE "lookupFunction<[^>]*>\(\s*'[A-Za-z0-9_]+'" \
             "$root/packages/rewamp_audio/lib" "$root/app/lib" 2>/dev/null \
           | grep -oE "'[A-Za-z0-9_]+'$"
         # multi-line form: lookupFunction<...>(\n    'name')
         grep -rhoE "^[[:space:]]*'[A-Za-z0-9_]*rewamp_[A-Za-z0-9_]+'\)" \
             "$root/packages/rewamp_audio/lib" "$root/app/lib" 2>/dev/null \
           | grep -oE "'[A-Za-z0-9_]+'"
         } | tr -d "'" | sort -u )

bad=0
for n in $names; do
  # Declared in a C API header → C linkage for any TU that includes it.
  if grep -qE "(^|[^A-Za-z0-9_])$n[[:space:]]*\(" "$src"/*.h; then continue; fi
  # Definition site: a .c file is C already; a .cpp/.mm needs an explicit
  # extern "C" on (or just above) the definition.
  def=$(grep -rn "(^|[^A-Za-z0-9_])$n[[:space:]]*\(" -E \
          --include='*.c' --include='*.cpp' --include='*.mm' "$src" \
        | grep -vE ":[[:space:]]*(//|\*)" | head -1)
  case "$def" in
    *.c:*) continue ;;
    "")    echo "NOT FOUND: $n — Dart looks it up, no definition in src/"; bad=1; continue ;;
  esac
  if printf '%s' "$def" | grep -q 'extern "C"'; then continue; fi
  echo "MANGLED: $n — defined in C++ without extern \"C\" and undeclared in src/*.h"
  echo "         $def"
  bad=1
done

so=$(ls "$root"/app/build/rewamp_audio/intermediates/library_jni/*/*/jni/arm64-v8a/librewamp_audio.so 2>/dev/null | head -1)
if [ -n "$so" ]; then
  # rewamp_gl_android_set_window is C++-internal (JNI side), never looked up by Dart.
  sym=$(nm -D --defined-only "$so" 2>/dev/null | grep " T _Z" | grep -i rewamp \
        | grep -v rewamp_gl_android_set_window || true)
  if [ -n "$sym" ]; then
    echo "MANGLED IN BINARY ($so):"
    printf '%s\n' "$sym"
    bad=1
  fi
else
  echo "note: no Android .so built — source check only (build once for the symbol-table check)"
fi

[ "$bad" = 0 ] && echo "OK: every Dart FFI lookup resolves to a C-linkage symbol"
exit "$bad"
