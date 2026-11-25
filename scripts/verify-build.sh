#!/bin/bash
# verify-build.sh — post-build manifest verification.
# Usage: scripts/verify-build.sh <full|nand> <manifest-file>
# Checks that the expected packages are present and the removed/optional ones
# are absent. Exit code 1 on any mismatch.

set -u

VARIANT="${1:?usage: verify-build.sh <full|nand> <manifest>}"
MAN="${2:?usage: verify-build.sh <full|nand> <manifest>}"
[ -f "$MAN" ] || { echo "manifest not found: $MAN" >&2; exit 1; }

fail=0
need()   { grep -q "^$1 - " "$MAN" || { echo "MISSING: $1"; fail=1; }; }
absent() { if grep -q "^$1 - " "$MAN"; then echo "UNWANTED: $1"; fail=1; fi; }

if [ "$VARIANT" = full ]; then
	for p in podkop-engine-full xray-core luci-app-podkop luci-app-re-homeproxy luci-app-openclash \
	         zapret2 luci-app-zapret2 naiveproxy luci-app-naiveproxy mieru luci-app-mieru \
	         luci-app-geodata adguardhome luci-app-adguardhome \
	         kmod-amneziawg amneziawg-tools luci-proto-amneziawg \
	         wireguard-tools luci-proto-wireguard mwan3 luci-app-mwan3 \
	         luci-theme-argon luci-app-argon-config luci-app-xray \
	         sqm-scripts luci-app-sqm watchcat luci-app-watchcat nlbwmon luci-app-nlbwmon \
	         tcpdump iperf3 mtr-json collectd luci-app-statistics \
	         ip6tables-nft openssh-sftp-server luci-ssl-openssl \
	         kmod-fs-ext4 kmod-fs-ntfs3 \
	         parted fstrim smartmontools usbutils pciutils collectd-mod-smart luci-app-diskman \
	         luci-i18n-geodata-ru luci-i18n-mieru-ru luci-i18n-naiveproxy-ru; do
		need "$p"
	done
	# removed from the composition / must stay out of the image (=m or dropped)
	# sing-box/sing-box-tiny/podkop-engine are replaced by podkop-engine-full
	# (PROVIDES sing-box, adds XHTTP).
	for p in python3 ruantiblock smartdns microsocks https-dns-proxy \
	         luci-app-passwall luci-app-passwall2 \
	         sing-box sing-box-tiny podkop-engine \
	         docker dockerd docker-compose samba4-server samba4-libs luci-app-samba4 \
	         ntfs-3g ntfs-3g-utils btrfs-progs; do
		absent "$p"
	done
elif [ "$VARIANT" = nand ]; then
	for p in adguardhome luci-app-adguardhome zapret2 luci-app-zapret2 \
	         kmod-amneziawg amneziawg-tools luci-proto-amneziawg \
	         wireguard-tools luci-proto-wireguard luci-theme-argon ip6tables-nft parted; do
		need "$p"
	done
	for p in sing-box sing-box-tiny podkop-engine podkop-engine-full \
	         xray-core luci-app-podkop luci-app-re-homeproxy luci-app-openclash \
	         naiveproxy mieru luci-app-mieru luci-app-geodata luci-app-naiveproxy \
	         docker dockerd docker-compose mwan3 v2ray-geoip v2ray-geosite \
	         luci-app-diskman samba4-server; do
		absent "$p"
	done
else
	echo "unknown variant: $VARIANT" >&2
	exit 1
fi

if [ "$fail" -eq 0 ]; then
	echo "VERIFY OK ($VARIANT)"
else
	echo "VERIFY FAILED ($VARIANT)" >&2
	exit 1
fi
