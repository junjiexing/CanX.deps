#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Package the Ubuntu 22.04 static dependency build into distributable
# tarballs under artifacts/deps:
#   canx-deps-linux-<arch>.tar.gz   prefix/ + shims/ + metadata/
#   canx-deps-source.tar.gz         locked upstream sources (x64 host only;
#                                   sources are architecture independent)
#
# Run on the Docker host after build-static-native-linux-x64.sh,
# build-linux-shims.sh and collect-release-metadata.sh completed inside the
# Ubuntu 22.04 container.
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repository_root/scripts/support/linux-architecture.sh"
static_root="${CANX_STATIC_ROOT:-$repository_root/.cache/static-native-ubuntu22.04/$linux_runtime}"
dist="${1:-$repository_root/artifacts/deps}"

for directory in prefix shims metadata; do
  [[ -d "$static_root/$directory" ]] || {
    echo "dependency build output is missing: $static_root/$directory" >&2
    exit 2
  }
done
mkdir -p "$dist"

binary_archive="$dist/canx-deps-linux-$linux_architecture.tar.gz"
rm -f -- "$binary_archive"
tar --sort=name --owner=0 --group=0 --numeric-owner \
  --create --gzip --file="$binary_archive" \
  -C "$static_root" prefix shims metadata
printf 'CANX_DEPS_PACKAGE_OK package=%s\n' "$binary_archive"

if [[ "${CANX_DEPS_SOURCE_PACKAGE:-1}" == 1 ]]; then
  if [[ "$linux_architecture" == x64 ]]; then
    source_root="$static_root/sources"
    [[ -d "$source_root" ]] || { echo "locked sources are missing: $source_root" >&2; exit 2; }
    source_archive="$dist/canx-deps-source.tar.gz"
    staging="$(mktemp -d "$dist/.source-staging.XXXXXX")"
    trap 'rm -rf -- "$staging"' EXIT
    tar_path="$staging/source.tar"
    cp "$repository_root/native/sources-linux-x64.lock" "$staging/native-sources.lock"
    cp "$repository_root/native/quickjs-source.lock" "$staging/quickjs-source.lock"
    : > "$tar_path"
    while IFS='|' read -r name _repository _revision _license; do
      [[ -n "$name" && "${name:0:1}" != '#' ]] || continue
      [[ -d "$source_root/$name" ]] || { echo "locked source is missing: $source_root/$name" >&2; exit 2; }
      tar --format=gnu --sort=name --owner=0 --group=0 --numeric-owner \
        --exclude-vcs \
        --exclude='./externals/skia/out' --exclude='./externals/skia/out/*' \
        --transform="s#^\./#native/$name/#" \
        --append --file="$tar_path" -C "$source_root/$name" .
    done < "$repository_root/native/sources-linux-x64.lock"
    quickjs_source="$repository_root/.cache/native/quickjs/source"
    [[ -f "$quickjs_source/VERSION" ]] || { echo "QuickJS source is missing: $quickjs_source" >&2; exit 2; }
    tar --format=gnu --sort=name --owner=0 --group=0 --numeric-owner \
      --exclude-vcs \
      --transform='s#^\./#native/quickjs/#' \
      --append --file="$tar_path" -C "$quickjs_source" .
    rm -f -- "$source_archive"
    gzip -n < "$tar_path" > "$source_archive"
    printf 'CANX_DEPS_PACKAGE_OK package=%s\n' "$source_archive"
  else
    echo 'source package is produced by the x64 job only; skipping'
  fi
fi
