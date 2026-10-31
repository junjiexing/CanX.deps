#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Package the macOS dependency build into
# artifacts/deps/canx-deps-macos-arm64.tar.gz. The tarball mirrors the
# CanX .cache layout so the fetch script extracts it in one step:
#   macos/mpv-frameworks/                 libmpv + bundled playback dylibs
#   native/quickjs/macos-build/           libcanx_quickjs.dylib
#   mac-native/aria2-shim/                libcanx_aria2.dylib
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="${1:-$repository_root/artifacts/deps}"
frameworks="$repository_root/.cache/macos/mpv-frameworks"
quickjs_library="$repository_root/.cache/native/quickjs/macos-build/libcanx_quickjs.dylib"
aria2_library="$repository_root/.cache/mac-native/aria2-shim/libcanx_aria2.dylib"

[[ -d "$frameworks" && -f "$frameworks/libmpv.2.dylib" ]] || {
  echo "macOS mpv frameworks are missing: $frameworks (run build-macos-mpv-frameworks.sh)" >&2
  exit 2
}
[[ -f "$quickjs_library" && -f "$aria2_library" ]] || {
  echo "macOS shim dylibs are missing (run build-macos-shims.sh)" >&2
  exit 2
}
mkdir -p "$dist"

staging="$(mktemp -d "$repository_root/.cache/.deps-staging.XXXXXX")"
trap 'rm -rf -- "$staging"' EXIT
mkdir -p "$staging/macos" "$staging/native/quickjs/macos-build" "$staging/mac-native/aria2-shim"
cp -R "$frameworks" "$staging/macos/"
cp "$quickjs_library" "$staging/native/quickjs/macos-build/"
cp "$aria2_library" "$staging/mac-native/aria2-shim/"

archive="$dist/canx-deps-macos-arm64.tar.gz"
rm -f -- "$archive"
tar --create --gzip --file="$archive" -C "$staging" macos native mac-native
printf 'CANX_DEPS_PACKAGE_OK package=%s\n' "$archive"
