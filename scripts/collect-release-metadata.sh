#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Collect the release metadata bundle that CanX's packaging consumes instead
# of the original source checkouts:
#   metadata/sources-linux-x64.lock   pinned native source lock
#   metadata/quickjs-source.lock      pinned QuickJS lock
#   metadata/sources/<name>/...       license/notice files per locked source
#   metadata/sources-quickjs/...      license/notice files from QuickJS
#
# The sources*/ trees mirror the checkout layout closely enough for CanX's
# generate-release-metadata.py license scanner (name/depth/size filtered
# again there), so release notices stay identical to a from-source build.
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repository_root/scripts/support/linux-architecture.sh"
static_root="${CANX_STATIC_ROOT:-$repository_root/.cache/static-native/$linux_runtime}"
source_root="$static_root/sources"
metadata="$static_root/metadata"
lock_file="$repository_root/native/sources-linux-x64.lock"
quickjs_lock="$repository_root/native/quickjs-source.lock"
quickjs_source="$repository_root/.cache/native/quickjs/source"

[[ -d "$source_root" ]] || { echo "locked sources are missing: $source_root" >&2; exit 2; }
[[ -f "$quickjs_source/VERSION" ]] || {
  echo "QuickJS source is missing: $quickjs_source (run build-linux-shims.sh first)" >&2
  exit 2
}

# Copy license-family files (license/licence/copying/notice/copyright with an
# optional separator suffix), preserving paths relative to the scan root.
# Slightly broader than CanX's final filter on purpose; the release metadata
# generator applies its exact rules when consuming this bundle.
collect_licenses() {
  local scan_root="$1" destination="$2" depth="$3"
  [[ -d "$scan_root" ]] || { echo "metadata scan root is missing: $scan_root" >&2; exit 2; }
  find "$scan_root" -maxdepth "$depth" -type f -size -4M \
    \( -iname 'license*' -o -iname 'licence*' -o -iname 'copying*' \
       -o -iname 'notice*' -o -iname 'copyright*' \) -print0 |
    while IFS= read -r -d '' candidate; do
      relative="${candidate#"$scan_root"/}"
      mkdir -p "$destination/$(dirname "$relative")"
      cp "$candidate" "$destination/$relative"
    done
}

rm -rf "$metadata"
mkdir -p "$metadata/sources" "$metadata/sources-quickjs"
cp "$lock_file" "$metadata/sources-linux-x64.lock"
cp "$quickjs_lock" "$metadata/quickjs-source.lock"

while IFS='|' read -r name _repository _revision _license; do
  [[ -n "$name" && "${name:0:1}" != '#' ]] || continue
  collect_licenses "$source_root/$name" "$metadata/sources/$name" 3
done < "$lock_file"

collect_licenses "$quickjs_source" "$metadata/sources-quickjs" 2

printf 'CANX_RELEASE_METADATA_OK platform=%s metadata=%s\n' "$linux_runtime" "$metadata"
