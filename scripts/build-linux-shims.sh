#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Build the static CanX shim archives (libcanx_aria2.a, libcanx_quickjs.a)
# into <static root>/shims using the pinned dependency prefix produced by
# build-static-native-linux-x64.sh. The shims directory ships in the
# canx-deps-linux-<arch> package so the CanX repository links without a C
# toolchain invocation of its own.
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repository_root/scripts/support/linux-architecture.sh"
static_root="${CANX_STATIC_ROOT:-$repository_root/.cache/static-native/$linux_runtime}"
prefix_root="$static_root/prefix"
shims="$static_root/shims"
aria_install="$prefix_root/aria2"
quickjs_lock="$repository_root/native/quickjs-source.lock"
quickjs_root="$repository_root/.cache/native/quickjs"
quickjs_archive="$quickjs_root/quickjs.tar.xz"
quickjs_source="$quickjs_root/source"

[[ -f "$aria_install/lib/libaria2.a" ]] || {
  echo "libaria2.a was not found at $aria_install/lib; run build-static-native-linux-x64.sh first" >&2
  exit 2
}
for tool in cmake ninja curl sha256sum tar; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing build tool: $tool" >&2; exit 2; }
done

# shellcheck disable=SC1090
source "$quickjs_lock"
mkdir -p "$quickjs_root" "$quickjs_source" "$shims" "$static_root/build"

if [[ ! -f "$quickjs_archive" ]] || \
   ! printf '%s  %s\n' "$sha256" "$quickjs_archive" | sha256sum --check --status; then
  curl -fsSL "$url" --output "$quickjs_archive"
fi
printf '%s  %s\n' "$sha256" "$quickjs_archive" | sha256sum --check --status

if [[ ! -f "$quickjs_source/VERSION" ]] || [[ "$(<"$quickjs_source/VERSION")" != "$version" ]]; then
  tar -xJf "$quickjs_archive" -C "$quickjs_source" --strip-components=1
fi

quickjs_build="$static_root/build/quickjs-shim"
cmake -S "$repository_root/native/quickjs-shim" -B "$quickjs_build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCANX_QUICKJS_LIBRARY_TYPE=STATIC \
  -DQUICKJS_SOURCE_DIR="$quickjs_source"
cmake --build "$quickjs_build"
cp "$quickjs_build/libcanx_quickjs.a" "$shims/libcanx_quickjs.a"

aria_shim_build="$static_root/build/aria2-shim"
cmake -S "$repository_root/native/aria2-shim" -B "$aria_shim_build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCANX_ARIA2_LIBRARY_TYPE=STATIC \
  -DCANX_ARIA2_EXTENDED_API=ON \
  -DARIA2_INCLUDE_DIR="$aria_install/include" \
  -DARIA2_LIBRARY="$aria_install/lib/libaria2.a"
cmake --build "$aria_shim_build"
cp "$aria_shim_build/libcanx_aria2.a" "$shims/libcanx_aria2.a"

printf 'CANX_LINUX_SHIMS_OK platform=%s shims=%s\n' "$linux_runtime" "$shims"
