#!/bin/bash
#
# diy-part2.sh — OpenWrt DIY script part 2 (after feeds install).
# Runs inside the OpenWrt tree. VARIANT=full|nand (default full).
#
# 1. Clone the custom package repos (HEAD) needed by the variant:
#    NAND only needs zapret2 / awg / argon; FULL clones everything.
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
