#!/bin/sh
# extra-packages.sh — build an archive of ONLY the .apk packages NOT included in the firmware image.
#
# Usage:
#   scripts/extra-packages.sh <manifest> <packages-dir> <out.tar.gz>
#     manifest     — bin/targets/.../openwrt-*.manifest (lines "name - version")
#     packages-dir — bin/packages (recursive search for *.apk)
#     out.tar.gz   — resulting archive of extra packages (docker/compose and =m dependencies)
#
# Logic: image composition = names+versions from the manifest. A package file name is
# "name-version[.arch].apk". A package is considered part of the image if its
# name-version (with or without the architecture suffix stripped) is in the manifest.
# All other .apk files are copied to staging and packed (flat layout, for apk add).

set -eu

MANIFEST="${1:?usage: extra-packages.sh <manifest> <packages-dir> <out.tar.gz>}"
PKGDIR="${2:?usage: extra-packages.sh <manifest> <packages-dir> <out.tar.gz>}"
OUT="${3:?usage: extra-packages.sh <manifest> <packages-dir> <out.tar.gz>}"

[ -f "$MANIFEST" ] || { echo "manifest not found: $MANIFEST" >&2; exit 1; }
[ -d "$PKGDIR" ] || { echo "packages dir not found: $PKGDIR" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Image composition keys: "name-version"
awk '$2 == "-" { print $1 "-" $3 }' "$MANIFEST" | sort -u > "$STAGE/image.keys"

# Select apk files not included in the image
find "$PKGDIR" -name '*.apk' -type f | sort | while read -r f; do
	base="$(basename "$f" .apk)"
	if grep -qxF "$base" "$STAGE/image.keys"; then
		continue
	fi
	# strip the architecture suffix (last ".segment"), if present
	trimmed="${base%.*}"
	if [ "$trimmed" != "$base" ] && grep -qxF "$trimmed" "$STAGE/image.keys"; then
		continue
	fi
	cp "$f" "$STAGE/"
done

COUNT="$(find "$STAGE" -name '*.apk' | wc -l)"
echo "extra packages: $COUNT"
if [ "$COUNT" -eq 0 ]; then
	echo "warning: no extra packages found" >&2
fi

tar -czf "$OUT" -C "$STAGE" .
echo "archive: $OUT ($(stat -c%s "$OUT" 2>/dev/null || stat -f%z "$OUT") bytes)"