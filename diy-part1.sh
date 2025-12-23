#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
#echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
#echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default

# Switch mirrors
sed -i 's|src-git packages https://git.openwrt.org/feed/packages.git|src-git packages https://github.com/openwrt/packages.git|' feeds.conf.default
sed -i 's|src-git luci https://git.openwrt.org/project/luci.git|src-git luci https://github.com/openwrt/luci.git|' feeds.conf.default
sed -i 's|src-git routing https://git.openwrt.org/feed/routing.git|src-git routing https://github.com/openwrt/routing.git|' feeds.conf.default
sed -i 's|src-git telephony https://git.openwrt.org/feed/telephony.git|src-git telephony https://github.com/openwrt/telephony.git|' feeds.conf.default
