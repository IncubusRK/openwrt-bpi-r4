#!/bin/bash
#
# diy-part1.sh — OpenWrt DIY script part 1 (before feeds update).
# Runs inside the OpenWrt tree.
#
# Switch git.openwrt.org feed URLs to GitHub mirrors, PRESERVING the ";branch"
# suffix (the openwrt-25.12 tree pins its feeds to ;openwrt-25.12 — dropping
# the suffix would silently track the default branch instead).
# Then append the passwall feeds (they have no release branches; ;main is
# used for both master and 25.12 builds).

set -e

sed -i 's|https://git.openwrt.org/feed/packages.git|https://github.com/openwrt/packages.git|' feeds.conf.default
sed -i 's|https://git.openwrt.org/project/luci.git|https://github.com/openwrt/luci.git|' feeds.conf.default
sed -i 's|https://git.openwrt.org/feed/routing.git|https://github.com/openwrt/routing.git|' feeds.conf.default
sed -i 's|https://git.openwrt.org/feed/telephony.git|https://github.com/openwrt/telephony.git|' feeds.conf.default
sed -i 's|https://git.openwrt.org/feed/video.git|https://github.com/openwrt/video.git|' feeds.conf.default

grep -q '^src-git passwall_packages ' feeds.conf.default || \
	echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' >> feeds.conf.default
grep -q '^src-git passwall_luci ' feeds.conf.default || \
	echo 'src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main' >> feeds.conf.default
grep -q '^src-git passwall2_luci ' feeds.conf.default || \
	echo 'src-git passwall2_luci https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main' >> feeds.conf.default

cat feeds.conf.default
