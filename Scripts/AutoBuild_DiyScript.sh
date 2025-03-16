#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions-BETA>
# AutoBuild DiyScript

Firmware_Diy_Core() {

	# 请在该函数内按需修改变量设置, 使用 case 语句控制不同预设变量的设置
	
	# 可用预设变量
	# ${OP_AUTHOR}  			OpenWrt 源码作者
	# ${OP_REPO}    			OpenWrt 仓库名称
	# ${OP_BRANCH}  			OpenWrt 源码分支
	# ${CONFIG_FILE}		配置文件
	
	Author=AUTO
	# 作者名称, AUTO: [自动识别]
	
	Author_URL=AUTO
	# 自定义作者网站或域名, AUTO: [自动识别]
	
	Default_Flag=AUTO
	# 固件标签 (名称后缀), 适用不同配置文件, AUTO: [自动识别]
	
	Default_IP="192.168.50.1"
	# 固件 IP 地址
	
	Default_Title="Powered by 抖音号：3D_K3_P3_P5_SSQ"
	# 固件终端首页显示的额外信息
	
	Short_Fw_Date=true
	# 简短的固件日期, true: [20210601]; false: [202106012359]
	
	x86_Full_Images=false
	# 额外上传已检测到的 x86 虚拟磁盘镜像, true: [上传]; false: [不上传]
	
	Fw_MFormat=AUTO
	# 自定义固件格式, AUTO: [自动识别]
	
	Regex_Skip="packages|buildinfo|sha256sums|manifest|kernel|rootfs|factory|itb|profile|ext4|json"
	# 输出固件时丢弃包含该内容的固件/文件
	
	AutoBuild_Features=true
	# 添加 AutoBuild 固件特性, true: [开启]; false: [关闭]
	
	AutoBuild_Features_Patch=false
	AutoBuild_Features_Kconfig=false
}

Firmware_Diy() {

	# 请在该函数内定制固件

	# 可用预设变量, 其他可用变量请参考运行日志
	# ${OP_AUTHOR}			OpenWrt 源码作者
	# ${OP_REPO}			OpenWrt 仓库名称
	# ${OP_BRANCH}			OpenWrt 源码分支
	# ${TARGET_PROFILE}		设备名称
	# ${TARGET_BOARD}		设备架构
	# ${TARGET_FLAG}		固件名称后缀
	# ${CONFIG_FILE}		配置文件

	# ${CustomFiles}		仓库中的 /CustomFiles 绝对路径
	# ${Scripts}			仓库中的 /Scripts 绝对路径

	# ${WORK}				OpenWrt 源码目录
	# ${FEEDS_CONF}			OpenWrt 源码目录下的 feeds.conf.default 文件
	# ${FEEDS_LUCI}			OpenWrt 源码目录下的 package/feeds/luci 目录
	# ${FEEDS_PKG}			OpenWrt 源码目录下的 package/feeds/packages 目录
	# ${BASE_FILES}			OpenWrt 源码目录下的 package/base-files/files 目录

	# AddPackage <package_path> <git_user> <git_repo> <git_branch>
	# ClashDL <platform> <core_type> [dev/tun/meta]
	# ReleaseDL <release_url> <file> <target_path>
	# Copy <cp_from> <cp_to > <rename>
	# merge_package <git_branch> <git_repo_url> <package_path> <target_path>..
	
	case "${OP_AUTHOR}/${OP_REPO}:${OP_BRANCH}" in
	coolsnowwolf/lede:master)
		cat >> ${Version_File} <<EOF
sed -i '/check_signature/d' /etc/opkg.conf
if [ -z "\$(grep "REDIRECT --to-ports 53" /etc/firewall.user 2> /dev/null)" ]
then
	echo '# iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
	echo '# iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
	echo '# [ -n "\$(command -v ip6tables)" ] && ip6tables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
	echo '# [ -n "\$(command -v ip6tables)" ] && ip6tables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
	echo 'iptables -t mangle -A PREROUTING -i pppoe -p icmp --icmp-type destination-unreachable -j DROP' >> /etc/firewall.user
	echo 'iptables -t mangle -A PREROUTING -i pppoe -p tcp -m tcp --tcp-flags ACK,RST RST -j DROP' >> /etc/firewall.user
	echo 'iptables -t mangle -A PREROUTING -i pppoe -p tcp -m tcp --tcp-flags PSH,FIN PSH,FIN -j DROP' >> /etc/firewall.user
	echo '[ -n "\$(command -v ip6tables)" ] && ip6tables -t mangle -A PREROUTING -i pppoe -p tcp -m tcp --tcp-flags PSH,FIN PSH,FIN -j DROP' >> /etc/firewall.user
	echo '[ -n "\$(command -v ip6tables)" ] && ip6tables -t mangle -A PREROUTING -i pppoe -p ipv6-icmp --icmpv6-type destination-unreachable -j DROP' >> /etc/firewall.user
	echo '[ -n "\$(command -v ip6tables)" ] && ip6tables -t mangle -A PREROUTING -i pppoe -p tcp -m tcp --tcp-flags ACK,RST RST -j DROP' >> /etc/firewall.user
fi
exit 0
EOF
		# sed -i "s?/bin/login?/usr/libexec/login.sh?g" ${FEEDS_PKG}/ttyd/files/ttyd.config
		# sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
		# sed -i '/uci commit luci/i\uci set luci.main.mediaurlbase="/luci-static/argon-mod"' $(PKG_Finder d package default-settings)/files/zzz-default-settings
		#sed -i "s?openwrt-23.05?master?g" ${FEEDS_CONF}
        WIFI_SCRIPT_PATH="package/kernel/mac80211/files/lib/wifi/mac80211.sh"
        # 调试路径
        echo "Checking file path: ${WORK}/${WIFI_SCRIPT_PATH}"
        ls -l ${WORK}/${WIFI_SCRIPT_PATH} || exit 1
        # 设置国家代码为 CN
        sed -i "s|country=US|country=CN|g" ${WORK}/${WIFI_SCRIPT_PATH}
        # 根据频段设置不同 SSID
        sed -i "/band=2g'/{n;s/ssid=LEDE/ssid=CandyTime_C9A700_2.4G/}" ${WORK}/${WIFI_SCRIPT_PATH}
        sed -i "/band=5g'/{n;s/ssid=LEDE/ssid=CandyTime_C9A700/}" ${WORK}/${WIFI_SCRIPT_PATH}
		git reset --hard 1627fd2c745e496134834a8fb8145ba0aa458ae9
		
		rm -r ${FEEDS_LUCI}/luci-theme-argon*
		AddPackage other vernesong OpenClash dev
		AddPackage other jerrykuku luci-app-argon-config master
		AddPackage other sbwml luci-app-mosdns v5-lua
		AddPackage themes jerrykuku luci-theme-argon 18.06
		AddPackage themes thinktip luci-theme-neobird main
		AddPackage msd_lite ximiTech luci-app-msd_lite main
		AddPackage msd_lite ximiTech msd_lite main
		AddPackage iptvhelper riverscn openwrt-iptvhelper master
		rm -r ${FEEDS_PKG}/mosdns
		rm -r ${FEEDS_LUCI}/luci-app-mosdns
		rm -r ${FEEDS_PKG}/curl
		rm -r ${FEEDS_PKG}/msd_lite
		Copy ${CustomFiles}/curl ${FEEDS_PKG}
		
		case "${TARGET_BOARD}" in
		ramips)
			sed -i "/DEVICE_COMPAT_VERSION := 1.1/d" target/linux/ramips/image/mt7621.mk
			Copy ${CustomFiles}/Depends/automount $(PKG_Finder d "package" automount)/files 15-automount
		;;
		esac

		case "${CONFIG_FILE}" in
		d-team_newifi-d2-Clash | xiaoyu_xy-c5-Clash)
			ClashDL mipsle-hardfloat tun
		;;
		esac
			
		case "${TARGET_PROFILE}" in
		d-team_newifi-d2)
			Copy ${CustomFiles}/${TARGET_PROFILE}_system ${BASE_FILES}/etc/config system
		;;
		xiaomi_redmi-router-ax6s)
			AddPackage passwall-depends xiaorouji openwrt-passwall-packages main
			AddPackage passwall-luci xiaorouji openwrt-passwall main
		;;
		esac
	;;
	immortalwrt/immortalwrt*)
		case "${TARGET_PROFILE}" in
		x86_64)
			sed -i -- 's:/bin/ash:'/bin/bash':g' ${BASE_FILES}/etc/passwd
			case "${CONFIG_FILE}" in
			x86_64)
				# sed -i "s?/bin/login?/usr/libexec/login.sh?g" ${FEEDS_PKG}/ttyd/files/ttyd.config
				AddPackage passwall xiaorouji openwrt-passwall main
				# AddPackage passwall xiaorouji openwrt-passwall2 main
				rm -r ${FEEDS_LUCI}/luci-app-passwall
				AddPackage other WROIATE luci-app-socat main
    				rm -r ${FEEDS_LUCI}/luci-app-socat
				AddPackage other sbwml luci-app-mosdns v5
				mosdns_version="5.3.3"
				wget --quiet --no-check-certificate -P /tmp \
					https://github.com/IrineSistiana/mosdns/releases/download/v${mosdns_version}/mosdns-linux-amd64.zip
				unzip /tmp/mosdns-linux-amd64.zip -d /tmp
				Copy /tmp/mosdns ${BASE_FILES}/usr/bin
				chmod +x ${BASE_FILES}/usr/bin
				sed -i "s?+mosdns ??g" ${WORK}/package/other/luci-app-mosdns/luci-app-mosdns/Makefile
				sed -i "s?+v2ray-geoip ??g" ${WORK}/package/other/luci-app-mosdns/luci-app-mosdns/Makefile
				sed -i "s?+v2ray-geosite ??g" ${WORK}/package/other/luci-app-mosdns/luci-app-mosdns/Makefile
				rm -r ${WORK}/package/other/luci-app-mosdns/mosdns
				
				Copy ${CustomFiles}/socat.Makefile ${FEEDS_PKG}/socat Makefile
				rm -r ${FEEDS_PKG}/socat/files
				Copy ${CustomFiles}/speedtest ${BASE_FILES}/usr/bin
				chmod +x ${BASE_FILES}/usr/bin/speedtest
				
				sed -i '/PKG_FIXUP/d' ${WORK}/feeds/packages/libs/libffi/Makefile
			;;
			esac
		;;
		esac
	;;
	padavanonly/immortalwrtARM*)
		case "${TARGET_PROFILE}" in
		xiaomi_redmi-router-ax6s)
			:
		;;
		esac
	;;
	hanwckf/immortalwrt-mt798x*)
		case "${TARGET_PROFILE}" in
		cmcc_rax3000m | jcg_q30)
			AddPackage passwall xiaorouji openwrt-passwall main
			rm -r ${FEEDS_LUCI}/luci-app-passwall
			patch < ${CustomFiles}/mt7981/0001-Add-iptables-socket.patch -p1 -d ${WORK}
			rm -r ${WORK}/package/network/services/dnsmasq
			Copy ${CustomFiles}/dnsmasq ${WORK}/package/network/services

			find ${WORK}/package/ | grep Makefile | grep v2ray-geodata | xargs rm -f
			find ${WORK}/package/ | grep Makefile | grep mosdns | xargs rm -f
			
			AddPackage other sbwml luci-app-mosdns v5
			AddPackage other sbwml v2ray-geodata master
		;;
		esac
	;;
	esac
	case "${TARGET_PROFILE}" in
	x86_64)
		Copy ${CustomFiles}/Depends/cpuset ${BASE_FILES}/bin
		ReleaseDL https://api.github.com/repos/nxtrace/NTrace-core/releases/latest nexttrace_linux_amd64 ${BASE_FILES}/bin nexttrace

		hysteria_version="2.6.1"
		wstunnel_version="9.2.3"
		taierspeed_version="1.7.2"
		
		wget --quiet --no-check-certificate -P /tmp \
			https://github.com/apernet/hysteria/releases/download/app%2Fv${hysteria_version}/hysteria-linux-amd64
			
		wget --quiet --no-check-certificate -P /tmp \
			https://github.com/erebe/wstunnel/releases/download/v${wstunnel_version}/wstunnel_${wstunnel_version}_linux_amd64.tar.gz
		wget --quiet --no-check-certificate -P /tmp \
			https://github.com/ztelliot/taierspeed-cli/releases/download/v${taierspeed_version}/taierspeed-cli_${taierspeed_version}_linux_amd64

		tar -xvzf /tmp/wstunnel_${wstunnel_version}_linux_amd64.tar.gz -C /tmp
		Copy /tmp/wstunnel ${BASE_FILES}/usr/bin
		Copy /tmp/hysteria-linux-amd64 ${BASE_FILES}/usr/bin hysteria
		Copy /tmp/taierspeed-cli_${taierspeed_version}_linux_amd64 ${BASE_FILES}/usr/bin taierspeed
		chmod +x ${BASE_FILES}/usr/bin/hysteria ${BASE_FILES}/usr/bin/wstunnel ${BASE_FILES}/usr/bin/taierspeed

		# ReleaseDL https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest geosite.dat ${BASE_FILES}/usr/v2ray
		# ReleaseDL https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest geoip.dat ${BASE_FILES}/usr/v2ray
	;;
	esac
Generate_Update_Logs() {
    LOG_PATH="${WORK}/bin/Firmware/Update_Logs.json"
    # 获取 OpenWrt 版本
    OPENWRT_VERSION=$(grep 'OPENWRT_VERSION=' ${WORK}/version | cut -d '=' -f2)
    # 获取 LUCI 版本
    LUCI_VERSION=$(grep 'LUCI_VERSION=' ${WORK}/feeds.conf.default | grep 'luci' | cut -d '=' -f2)
    # 获取内核版本（修正变量名）
    LINUX_VERSION=$(grep 'LINUX_VERSION-' ${WORK}/include/kernel-version.mk | cut -d '=' -f2 | tr -d ' ')
    # 编译日期 (UTC+8)
    BUILD_DATE=$(TZ=UTC-8 date +"%Y-%m-%d")
    # 更新内容（从环境变量读取，需在 workflow 中定义）
    UPDATE_CONTENT="${UPDATE_CONTENT:-默认更新描述}"

    # 生成 JSON 文件（修正格式）
    cat > ${LOG_PATH} <<EOF
{
    "OPENWRT版本": "${OPENWRT_VERSION}",
    "LUCI版本": "${LUCI_VERSION}",
    "内核版本": "${LINUX_VERSION}",
    "更新内容": "${UPDATE_CONTENT}",
    "编译日期": "${BUILD_DATE}"
}
EOF
}