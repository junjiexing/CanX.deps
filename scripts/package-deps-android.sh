#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Package one Android ABI dependency build (prefix/) into
# artifacts/deps/canx-deps-android-<abi>.tar.gz.
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
abi="${1:-}"
case "$abi" in
  arm64-v8a|x86_64) ;;
  *) echo "usage: $0 [arm64-v8a|x86_64] [dist-dir]" >&2; exit 2 ;;
esac
dist="${2:-$repository_root/artifacts/deps}"
root="${CANX_ANDROID_NATIVE_ROOT:-$repository_root/.cache/android-native/$abi}"

for library in libmpv.a libcanx_aria2.so libcanx_quickjs.a; do
  [[ -f "$root/prefix/lib/$library" ]] || {
    echo "Android dependency build output is missing: $root/prefix/lib/$library" >&2
    exit 2
  }
done
mkdir -p "$dist"

archive="$dist/canx-deps-android-$abi.tar.gz"
rm -f -- "$archive"
tar --sort=name --owner=0 --group=0 --numeric-owner \
  --create --gzip --file="$archive" \
  -C "$root" prefix
printf 'CANX_DEPS_PACKAGE_OK package=%s\n' "$archive"
