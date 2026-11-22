#!/bin/bash
#
# diy-part1.sh — OpenWrt DIY script part 1 (before feeds update).
# Runs inside the OpenWrt tree.
#
# 1. Drop feeds nothing in the composition uses: telephony, video (the video
#    feed's qt5/qt6 Config.in also produces Kconfig recursive-dependency noise),
#    and the passwall LuCI feeds (luci-app-passwall/passwall2 are NOT selected).
#    NOTE: passwall_packages stays — it is the only source of the naiveproxy
#    binary (prebuilt klzgrad/naiveproxy); it is not "passwall the proxy app".
# 2. Switch git.openwrt.org feed URLs to GitHub mirrors, PRESERVING the
#    ";branch" suffix (the openwrt-25.12 tree pins feeds to ;openwrt-25.12 —
#    dropping the suffix would silently track the default branch instead).
# 3. Append passwall_packages (;main — the feed has no release branches).

set -e

sed -i '/^src-git telephony /d; /^src-git video /d' feeds.conf.default

sed -i 's|https://git.openwrt.org/feed/packages.git|https://github.com/openwrt/packages.git|' feeds.conf.default
sed -i 's|https://git.openwrt.org/project/luci.git|https://github.com/openwrt/luci.git|' feeds.conf.default
sed -i 's|https://git.openwrt.org/feed/routing.git|https://github.com/openwrt/routing.git|' feeds.conf.default

grep -q '^src-git passwall_packages ' feeds.conf.default || \
	echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' >> feeds.conf.default

cat feeds.conf.default
