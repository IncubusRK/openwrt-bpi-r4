#!/bin/bash
#
# diy-part2.sh — OpenWrt DIY script part 2 (after feeds install).
# Runs inside the OpenWrt tree. VARIANT=full|nand (default full).
#
# 1. Clone the custom package repos (HEAD) needed by the variant:
#    NAND only needs zapret2 / awg / argon; FULL clones everything.
#    FULL also materializes package/podkop-engine — podkop's own sing-box build
#    with the XHTTP transport and Xray-compatible REALITY (stock sing-box has
#    no XHTTP, and the providers require it).
# 2. Mode safety net: strip group/other write (rpcd skips world-writable
#    ucode plugins), keep uci-defaults and libexec workers executable.
#    Git clones normally carry proper bits — this guards against regressions
#    (e.g. a repo committed from Windows with 644 uci-defaults).
# 3. Enforce the include/scan.mk marker: a Makefile without the literal
#    "call BuildPackage" is SILENTLY skipped by the package scanner.
# 4. FULL only: download Loyalsoldier geodata into files/usr/share/v2ray/
#    (never in git; runetfreedom fallback), record sha256.
# 5. Record repo HEADs for the release notes.

set -e

VARIANT="${VARIANT:-full}"
cd package

clone() {
	[ -d "$1" ] || git clone --depth 1 "$2" "$1"
}

# Full history for our own repos: luci.mk findrev stamps the i18n version
# from "git log -1 -- po"; a shallow clone whose HEAD did not touch po/
# falls back to version 0. (Third-party apps keep depth 1 — version 0 in
# their image-baked i18n is harmless, they have no external upgrade source.)
clone_full() {
	[ -d "$1" ] || git clone "$2" "$1"
}

# Needed by both FULL and NAND.
clone zapret2-openwrt  https://github.com/1andrevich/zapret2-openwrt
clone awg-openwrt      https://github.com/slava-shchipunov/awg-openwrt
clone luci-theme-argon https://github.com/jerrykuku/luci-theme-argon
CLONED="zapret2-openwrt awg-openwrt luci-theme-argon"

if [ "$VARIANT" = full ]; then
	clone OpenClash           https://github.com/vernesong/OpenClash
	clone podkop              https://github.com/itdoginfo/podkop
	clone homeproxy-hiddify   https://github.com/1andrevich/homeproxy-hiddify
	clone luci-app-xray       https://github.com/yichya/luci-app-xray
	clone podkop-engine-src   https://github.com/podkop-net/podkop-engine
	clone_full luci-app-geodata    https://github.com/IncubusRK/luci-app-geodata
	clone_full luci-app-naiveproxy https://github.com/IncubusRK/luci-app-naiveproxy
	clone_full openwrt-mieru       https://github.com/IncubusRK/openwrt-mieru

	# diskman: only the application subdir — the repo root carries its own
	# Parted.Makefile which conflicts with the official parted package.
	if [ ! -d luci-app-diskman ]; then
		rm -rf /tmp/diskman-src
		git clone --depth 1 --filter=blob:none --sparse https://github.com/lisaac/luci-app-diskman /tmp/diskman-src
		git -C /tmp/diskman-src sparse-checkout set applications/luci-app-diskman
		cp -a /tmp/diskman-src/applications/luci-app-diskman luci-app-diskman
	fi
	CLONED="$CLONED OpenClash podkop homeproxy-hiddify luci-app-xray luci-app-geodata luci-app-naiveproxy openwrt-mieru luci-app-diskman"
fi

# Repo HEADs for the release notes (diskman copy has no .git of its own).
: > ../repo-heads.txt
for d in $CLONED; do
	if [ -d "$d/.git" ]; then
		printf '%s %s\n' "$d" "$(git -C "$d" rev-parse HEAD)" >> ../repo-heads.txt
	elif [ "$d" = luci-app-diskman ]; then
		printf '%s %s\n' "$d" "$(git -C /tmp/diskman-src rev-parse HEAD)" >> ../repo-heads.txt
	fi
done

if [ "$VARIANT" = full ]; then
	# --- podkop-engine: skeleton + patches + version.mk -------------------
	# The repo ships only the package skeleton plus one patch set per sing-box
	# line; version.mk is generated here exactly like their scripts/sdk-build.sh
	# does it for the SDK. NaiveProxy inside sing-box stays OFF (no lld/cronet):
	# the standalone naiveproxy package already covers that protocol.
	PODKOP_ENGINE_LINE="${PODKOP_ENGINE_LINE:-1.14}"

	. podkop-engine-src/versions.env

	key=$(printf '%s' "$PODKOP_ENGINE_LINE" | tr . _)
	eval "SB_VERSION=\${SB_${key}_VERSION:-}"
	eval "SB_HASH=\${SB_${key}_HASH:-}"
	eval "SB_RELEASE=\${SB_${key}_RELEASE:-}"

	[ -n "$SB_VERSION" ] && [ -n "$SB_HASH" ] && [ -n "$SB_RELEASE" ] || {
		echo "ERROR: podkop-engine line $PODKOP_ENGINE_LINE is not defined in versions.env" >&2
		exit 1
	}
	[ -d "podkop-engine-src/patches/v$PODKOP_ENGINE_LINE" ] || {
		echo "ERROR: podkop-engine has no patches/v$PODKOP_ENGINE_LINE (bump PODKOP_ENGINE_LINE)" >&2
		exit 1
	}

	rm -rf podkop-engine
	cp -a podkop-engine-src/openwrt/podkop-engine podkop-engine
	mkdir -p podkop-engine/patches
	cp "podkop-engine-src/patches/v$PODKOP_ENGINE_LINE"/*.patch podkop-engine/patches/
	cat > podkop-engine/version.mk <<EOF
SB_VERSION:=$SB_VERSION
SB_HASH:=$SB_HASH
SB_RELEASE:=$SB_RELEASE
# NaiveProxy inside sing-box stays off: no lld/cronet in CI, the standalone
# naiveproxy package covers the protocol.
PODKOP_ENGINE_LLD:=
EOF
	printf 'podkop-engine %s-r%s (patches v%s, fork %s)\n' \
		"$SB_VERSION" "$SB_RELEASE" "$PODKOP_ENGINE_LINE" \
		"$(git -C podkop-engine-src rev-parse HEAD)" >> ../repo-heads.txt

	# Break the Kconfig cycle: podkop selects +sing-box, while podkop-engine
	# PROVIDES and CONFLICTS it. An image build cannot express "provides"
	# (unlike apk at install time), so defconfig silently drops the engine.
	# The engine installs /usr/bin/sing-box anyway.
	sed -i -E 's/(DEPENDS:=)\+sing-box[[:space:]]*/\1/' podkop/podkop/Makefile
	grep -q -- '+sing-box' podkop/podkop/Makefile && {
		echo "ERROR: podkop still selects sing-box (upstream DEPENDS changed?)" >&2
		exit 1
	}
	sed -i -E '/^[[:space:]]*CONFLICTS:=sing-box sing-box-tiny[[:space:]]*$/d' podkop-engine/Makefile
	grep -qE '^[[:space:]]*CONFLICTS:=sing-box sing-box-tiny[[:space:]]*$' podkop-engine/Makefile && {
		echo "ERROR: podkop-engine still conflicts with sing-box (upstream changed?)" >&2
		exit 1
	}

	rm -rf podkop-engine-src
	CLONED="$CLONED podkop-engine"
fi

cd ..

# Mode safety net (see header). One uci-defaults pattern covers both
# root/etc/... and etc/... layouts.
for d in $CLONED; do
	find "package/$d" -type f -perm /022 -exec chmod go-w {} +
done
find package -path '*/etc/uci-defaults/*' -type f -exec chmod 0755 {} +
find package -path '*/usr/libexec/*' -type f -exec chmod 0755 {} +

# scan.mk marker check (luci.mk evaluates BuildPackage itself; the literal
# marker comment is the luci-feed convention).
if [ "$VARIANT" = full ]; then
	for m in package/luci-app-geodata/Makefile \
	         package/luci-app-naiveproxy/Makefile \
	         package/openwrt-mieru/mieru/Makefile \
	         package/openwrt-mieru/luci-app-mieru/Makefile \
	         package/podkop-engine/Makefile \
	         package/luci-app-diskman/Makefile; do
		grep -q 'call BuildPackage' "$m" || { echo "ERROR: scan.mk marker missing in $m" >&2; exit 1; }
	done
fi

# Geodata: FULL only — the NAND installer must not carry geodata (files/
# lands in the rootfs regardless of package selection).
if [ "$VARIANT" = full ]; then
	mkdir -p files/usr/share/v2ray
	fetch() {
		curl -fL --retry 3 --connect-timeout 30 -o "$2" "$1"
	}
	fetch https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat \
	      files/usr/share/v2ray/geoip.dat || \
	fetch https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geoip.dat \
	      files/usr/share/v2ray/geoip.dat
	fetch https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat \
	      files/usr/share/v2ray/geosite.dat || \
	fetch https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geosite.dat \
	      files/usr/share/v2ray/geosite.dat
	for f in geoip geosite; do
		sz=$(stat -c%s "files/usr/share/v2ray/$f.dat")
		[ "$sz" -gt 1048576 ] || { echo "ERROR: $f.dat too small ($sz bytes)" >&2; exit 1; }
	done
	sha256sum files/usr/share/v2ray/*.dat | tee geodata-sha256.txt
fi

echo "diy-part2 OK ($VARIANT)"
