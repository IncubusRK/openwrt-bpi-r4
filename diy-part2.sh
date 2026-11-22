#!/bin/bash
#
# diy-part2.sh — OpenWrt DIY script part 2 (after feeds install).
# Runs inside the OpenWrt tree.
#
# 1. Clone the custom package repos (HEAD) used by the FULL/NAND composition.
# 2. Normalize file modes (rpcd skips world-writable ucode plugins; NTFS copies
#    used to arrive 0777 — git clones keep proper bits, this is a safety net).
# 3. Enforce the include/scan.mk marker: a Makefile without the literal
#    "call BuildPackage" is SILENTLY skipped by the package scanner.
# 4. Download Loyalsoldier geodata into files/usr/share/v2ray/ (never in git;
#    runetfreedom fallback), record sha256 + repo HEADs for the release notes.

set -e

cd package

clone() {
	[ -d "$1" ] || git clone --depth 1 "$2" "$1"
}

clone OpenClash            https://github.com/vernesong/OpenClash
clone podkop               https://github.com/itdoginfo/podkop
clone homeproxy-hiddify    https://github.com/1andrevich/homeproxy-hiddify
clone luci-app-xray        https://github.com/yichya/luci-app-xray
clone luci-theme-argon     https://github.com/jerrykuku/luci-theme-argon
clone zapret2-openwrt      https://github.com/1andrevich/zapret2-openwrt
clone awg-openwrt          https://github.com/slava-shchipunov/awg-openwrt
clone luci-app-geodata     https://github.com/IncubusRK/luci-app-geodata
clone luci-app-naiveproxy  https://github.com/IncubusRK/luci-app-naiveproxy
clone openwrt-mieru        https://github.com/IncubusRK/openwrt-mieru

# diskman: only the application subdir — the repo root carries its own
# Parted.Makefile which conflicts with the official parted package.
if [ ! -d luci-app-diskman ]; then
	rm -rf /tmp/diskman-src
	git clone --depth 1 --filter=blob:none --sparse https://github.com/lisaac/luci-app-diskman /tmp/diskman-src
	git -C /tmp/diskman-src sparse-checkout set applications/luci-app-diskman
	cp -a /tmp/diskman-src/applications/luci-app-diskman luci-app-diskman
fi

# Repo HEADs for the release notes.
: > ../repo-heads.txt
for d in OpenClash podkop homeproxy-hiddify luci-app-xray luci-theme-argon \
         zapret2-openwrt awg-openwrt luci-app-geodata luci-app-naiveproxy openwrt-mieru; do
	printf '%s %s\n' "$d" "$(git -C "$d" rev-parse HEAD)" >> ../repo-heads.txt
done
printf '%s %s\n' "luci-app-diskman" "$(git -C /tmp/diskman-src rev-parse HEAD)" >> ../repo-heads.txt

cd ..

# Mode safety net: strip group/other write everywhere in the cloned packages;
# keep uci-defaults and libexec workers executable.
find package/OpenClash package/podkop package/homeproxy-hiddify package/luci-app-xray \
     package/luci-theme-argon package/zapret2-openwrt package/awg-openwrt \
     package/luci-app-geodata package/luci-app-naiveproxy package/openwrt-mieru \
     package/luci-app-diskman \
     -type f -perm /022 -exec chmod go-w {} +
find package -path '*/root/etc/uci-defaults/*' -type f -exec chmod 0755 {} +
find package -path '*/etc/uci-defaults/*' -type f -exec chmod 0755 {} +
find package -path '*/usr/libexec/*' -type f -exec chmod 0755 {} +

# scan.mk marker check (our packages + diskman; luci.mk evaluates BuildPackage
# itself, the literal marker comment is the luci-feed convention).
for m in package/luci-app-geodata/Makefile \
         package/luci-app-naiveproxy/Makefile \
         package/openwrt-mieru/mieru/Makefile \
         package/openwrt-mieru/luci-app-mieru/Makefile \
         package/luci-app-diskman/Makefile; do
	grep -q 'call BuildPackage' "$m" || { echo "ERROR: scan.mk marker missing in $m" >&2; exit 1; }
done

# Geodata: Loyalsoldier (default), runetfreedom fallback. Size sanity > 1 MiB.
# FULL only — the NAND installer must not carry geodata (files/ lands in the
# rootfs regardless of package selection).
if [ "${VARIANT:-full}" = full ]; then
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

echo "diy-part2 OK"
