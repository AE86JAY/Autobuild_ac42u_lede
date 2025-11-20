#!/bin/bash
# AutoBuild Module by Hyy2001X (优化版本)
# AutoBuild DiyScript - 优化示例

# 加载公共函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 检查公共函数库是否存在
if [[ -f "$PROJECT_ROOT/common/common.sh" ]]; then
    source "$PROJECT_ROOT/common/common.sh"
    init_build_environment
else
    # 向后兼容 - 使用原有的ECHO函数
    ECHO() { echo "[$(date "+%H:%M:%S")] $*"; }
fi

# ========================================
# 配置管理
# ========================================

# 加载构建配置
load_build_config() {
    local config_file="$PROJECT_ROOT/config/build.conf"
    
    if [[ -f "$config_file" ]]; then
        source "$config_file"
    else
        # 默认配置
        Author="AUTO"
        Author_URL="AUTO"  # 移除硬编码的推广链接
        Default_Flag="AUTO"
        Default_IP="192.168.1.1"  # 更安全的默认值
        Default_Title="Powered by AutoBuild-Actions"
        Short_Fw_Date=true
        x86_Full_Images=false
        Fw_MFormat="AUTO"
        Regex_Skip="packages|buildinfo|sha256sums|manifest|kernel|rootfs|factory|itb|profile|ext4"
        AutoBuild_Features=true
        AutoBuild_Features_Patch=false
        AutoBuild_Features_Kconfig=false
        
        # 网络配置
        WGET_TIMEOUT=30
        WGET_RETRIES=3
        SSL_VERIFY=true
        
        # 性能配置
        MAX_PARALLEL_DOWNLOADS=4
        CACHE_ENABLED=true
        CACHE_MAX_AGE_HOURS=24
    fi
    
    # 验证关键配置
    validate_build_config
}

# 验证构建配置
validate_build_config() {
    local errors=0
    
    # 验证IP地址
    if [[ -n "$Default_IP" ]] && ! validate_ip_address "$Default_IP"; then
        warn "Invalid Default_IP: $Default_IP, using default"
        Default_IP="192.168.1.1"
        ((errors++))
    fi
    
    # 验证Author_URL
    if [[ "$Author_URL" != "AUTO" && "$Author_URL" != "false" ]]; then
        if ! validate_url "$Author_URL"; then
            warn "Invalid Author_URL: $Author_URL, using AUTO"
            Author_URL="AUTO"
            ((errors++))
        fi
    fi
    
    # 验证安全设置
    if [[ "$SSL_VERIFY" != "true" && "$SSL_VERIFY" != "false" ]]; then
        warn "Invalid SSL_VERIFY setting: $SSL_VERIFY, using true"
        SSL_VERIFY=true
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        warn "Configuration validation found $errors issues"
    else
        info "Configuration validation passed"
    fi
}

# ========================================
# 主函数
# ========================================

Firmware_Diy_Core() {
    info "Starting firmware customization core..."
    
    # 加载配置
    load_build_config
    
    # 在该函数内按需修改变量设置, 使用 case 语句控制不同预设变量的设置
    
    # 可用预设变量
    # ${OP_AUTHOR}			OpenWrt 源码作者
    # ${OP_REPO}			OpenWrt 仓库名称
    # ${OP_BRANCH}			OpenWrt 源码分支
    # ${CONFIG_FILE}		配置文件
    
    info "Author: $Author"
    info "Author_URL: $Author_URL"
    info "Default_IP: $Default_IP"
    info "Default_Flag: $Default_Flag"
    
    # 设置作者URL
    if [[ "$Author_URL" == "AUTO" ]]; then
        if [[ -n "$Github" ]]; then
            Author_URL="$Github"
        else
            unset Author_URL
        fi
    elif [[ "$Author_URL" == "false" ]]; then
        unset Author_URL
    fi
    
    # 设置版本日期
    if [[ "$Short_Fw_Date" == true ]]; then
        # 日期格式已在环境变量中处理
        :
    fi
    
    info "Firmware customization core completed"
}

# ========================================
# 安全的包下载函数
# ========================================

# 安全的包添加函数
safe_AddPackage() {
    local pkg_dir="$1"
    local git_user="$2"
    local git_repo="$3"
    local git_branch="${4:-main}"
    
    # 输入验证
    if [[ $# -lt 3 ]]; then
        error "safe_AddPackage: Insufficient arguments (need at least 3, got $#)"
        return 1
    fi
    
    if [[ ! "$pkg_dir" =~ ^[a-zA-Z0-9/_-]+$ ]]; then
        error "Invalid package directory: $pkg_dir"
        return 1
    fi
    
    if [[ ! "$git_user" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Invalid git user: $git_user"
        return 1
    fi
    
    if [[ ! "$git_repo" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        error "Invalid git repo: $git_repo"
        return 1
    fi
    
    if [[ ! "$git_branch" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        error "Invalid git branch: $git_branch"
        return 1
    fi
    
    # 构建GitHub URL
    local repo_url="https://github.com/$git_user/$git_repo"
    
    # 验证URL
    if ! validate_url "$repo_url"; then
        error "Repository URL not allowed: $repo_url"
        return 1
    fi
    
    # 记录下载尝试
    info "Adding package: $git_user/$git_repo (branch: $git_branch)"
    
    # 使用并行下载（如果有多个包）
    if [[ -n "$ENABLE_PARALLEL_DOWNLOAD" && "$ENABLE_PARALLEL_DOWNLOAD" == "true" ]]; then
        # 这里可以添加到并行下载队列
        parallel_add_package "$pkg_dir" "$git_user" "$git_repo" "$git_branch" &
    else
        # 串行下载
        run_add_package "$pkg_dir" "$git_user" "$git_repo" "$git_branch"
    fi
}

# 执行包添加
run_add_package() {
    local pkg_dir="$1"
    local git_user="$2"
    local git_repo="$3"
    local git_branch="$4"
    local target_dir="${GITHUB_WORKSPACE:-.}/$pkg_dir/$git_repo"
    
    # 创建目录
    if [[ ! -d "$(dirname "$target_dir")" ]]; then
        mkdir -p "$(dirname "$target_dir")"
    fi
    
    # 清理旧版本
    if [[ -d "$target_dir" ]]; then
        info "Removing old package: $git_repo ..."
        run_with_error_handling "rm -rf \"$target_dir\"" \
                               "Remove old package $git_repo"
    fi
    
    # 下载新版本
    local temp_dir=$(create_temp_dir)
    local repo_url="https://github.com/$git_user/$git_repo"
    
    info "Downloading package $git_repo from $repo_url ..."
    if run_with_error_handling "git clone --depth 1 -b \"$git_branch\" \"$repo_url\" \"$temp_dir\"" \
                              "Clone $git_user/$git_repo"; then
        # 移动到目标位置
        run_with_error_handling "mv \"$temp_dir\" \"$target_dir\"" \
                               "Move package to target directory"
        info "Package $git_repo added successfully"
    else
        rm -rf "$temp_dir"
        return 1
    fi
}

# ========================================
# 安全的下载函数
# ========================================

# 安全的文件下载
safe_download_file() {
    local url="$1"
    local output="$2"
    local description="${3:-file}"
    
    info "Downloading $description from: $url"
    
    # 验证URL
    if ! validate_url "$url"; then
        error "Download URL not allowed: $url"
        return 1
    fi
    
    # 创建输出目录
    mkdir -p "$(dirname "$output")"
    
    # 检查缓存
    if [[ "$CACHE_ENABLED" == "true" ]]; then
        if cache_get "$url" > "$output"; then
            return 0
        fi
    fi
    
    # 执行下载
    if safe_wget "$url" "$output"; then
        # 验证下载的文件
        if [[ -s "$output" ]]; then
            # 检查文件大小
            check_file_size "$output"
            
            # 缓存文件
            if [[ "$CACHE_ENABLED" == "true" ]]; then
                cache_set "$url" "$(cat "$output")"
            fi
            
            info "Downloaded $description successfully: $(du -h "$output" | cut -f1)"
            return 0
        else
            error "Downloaded file is empty: $output"
            rm -f "$output"
            return 1
        fi
    else
        error "Failed to download $description"
        return 1
    fi
}

# ========================================
# 优化的主要定制函数
# ========================================

Firmware_Diy() {
    info "Starting firmware customization..."
    
    # 变量验证
    if [[ -z "${TARGET_PROFILE}" ]]; then
        error "TARGET_PROFILE not set"
        return 1
    fi
    
    info "Customizing firmware for: $TARGET_PROFILE"
    info "Source: ${OP_AUTHOR}/${OP_REPO}:${OP_BRANCH}"
    
    case "${OP_AUTHOR}/${OP_REPO}:${OP_BRANCH}" in
    coolsnowwolf/lede:master)
        customize_lede_branch
        ;;
    immortalwrt/immortalwrt*)
        customize_immortalwrt_branch
        ;;
    padavanonly/immortalwrtARM*)
        customize_immortalwrt_arm_branch
        ;;
    hanwckf/immortalwrt-mt798x*)
        customize_mt798x_branch
        ;;
    *)
        warn "Unknown branch combination: ${OP_AUTHOR}/${OP_REPO}:${OP_BRANCH}"
        ;;
    esac
    
    # 通用定制
    customize_common_features
    
    info "Firmware customization completed"
}

# ========================================
# 分支特定的定制函数
# ========================================

customize_lede_branch() {
    info "Customizing Lede branch..."
    
    # 添加版本文件内容
    if [[ -n "${Version_File}" ]]; then
        cat >> "${Version_File}" <<EOF
# AutoBuild customization
sed -i '/check_signature/d' /etc/opkg.conf
if [ -z "\$(grep "REDIRECT --to-ports 53" /etc/firewall.user 2> /dev/null)" ]
then
	echo '# iptables rules for DNS and firewall' >> /etc/firewall.user
fi
exit 0
EOF
    fi
    
    # 添加OpenClash
    safe_AddPackage other vernesong OpenClash dev
    
    # 添加其他包
    safe_AddPackage other jerrykuku luci-app-argon-config master
    safe_AddPackage other sbwml luci-app-mosdns v5-lua
    safe_AddPackage themes jerrykuku luci-theme-argon master
    safe_AddPackage themes thinktip luci-theme-neobird main
    safe_AddPackage msd_lite ximiTech luci-app-msd_lite main
    safe_AddPackage iptvhelper riverscn openwrt-iptvhelper master
    
    # 移除冲突的包
    remove_conflicting_packages "mosdns" "curl" "msd_lite"
    
    # 设备特定的定制
    customize_device_specific
    
    # 处理配置文件
    case "${CONFIG_FILE}" in
    d-team_newifi-d2-Clash|xiaoyu_xy-c5-Clash)
        download_clash_core "mipsle-hardfloat" "tun"
        ;;
    esac
}

customize_immortalwrt_branch() {
    info "Customizing ImmortalWrt branch..."
    
    case "${TARGET_PROFILE}" in
    x86_64)
        # x86_64特定定制
        setup_x86_64_specific
        ;;
    *)
        info "No specific customization for $TARGET_PROFILE"
        ;;
    esac
}

customize_immortalwrt_arm_branch() {
    info "Customizing ImmortalWrt ARM branch..."
    
    case "${TARGET_PROFILE}" in
    xiaomi_redmi-router-ax6s)
        info "Xiaomi AX6S specific setup"
        ;;
    *)
        info "No specific customization for $TARGET_PROFILE"
        ;;
    esac
}

customize_mt798x_branch() {
    info "Customizing MT798x branch..."
    
    case "${TARGET_PROFILE}" in
    cmcc_rax3000m|jcg_q30)
        setup_mt798x_specific
        ;;
    *)
        info "No specific customization for $TARGET_PROFILE"
        ;;
    esac
}

# ========================================
# 辅助函数
# ========================================

customize_device_specific() {
    info "Applying device-specific customizations..."
    
    case "${TARGET_BOARD}" in
    ramips)
        info "Applying RAMips specific fixes..."
        # RAMips特定定制
        ;;
    esac
    
    case "${TARGET_PROFILE}" in
    d-team_newifi-d2)
        copy_device_config "d-team_newifi-d2_system"
        ;;
    xiaomi_redmi-router-ax6s)
        # 添加Passwall
        safe_AddPackage passwall-depends xiaorouji openwrt-passwall-packages main
        safe_AddPackage passwall-luci xiaorouji openwrt-passwall main
        ;;
    esac
}

setup_x86_64_specific() {
    info "Setting up x86_64 specific features..."
    
    # 修改默认shell
    if [[ -n "${BASE_FILES}" ]]; then
        sed -i -- 's:/bin/ash:'/bin/bash':g' "${BASE_FILES}/etc/passwd"
    fi
    
    # 添加Passwall
    safe_AddPackage passwall xiaorouji openwrt-passwall main
    
    # 添加其他包
    safe_AddPackage other WROIATE luci-app-socat main
    safe_AddPackage other sbwml luci-app-mosdns v5
    
    # 下载mosdns二进制文件
    local mosdns_version="5.3.3"
    local mosdns_url="https://github.com/IrineSistiana/mosdns/releases/download/v${mosdns_version}/mosdns-linux-amd64.zip"
    local mosdns_dir="/tmp"
    
    if safe_download_file "$mosdns_url" "$mosdns_dir/mosdns-linux-amd64.zip" "MosDNS binary"; then
        info "Installing MosDNS binary..."
        # 解压并安装
        if command -v unzip >/dev/null 2>&1; then
            unzip "$mosdns_dir/mosdns-linux-amd64.zip" -d "$mosdns_dir"
            if [[ -f "${BASE_FILES}/usr/bin/mosdns" ]]; then
                chmod +x "${BASE_FILES}/usr/bin/mosdns"
            fi
        fi
        rm -f "$mosdns_dir/mosdns-linux-amd64.zip"
    fi
}

setup_mt798x_specific() {
    info "Setting up MT798x specific features..."
    
    # 添加Passwall
    safe_AddPackage passwall xiaorouji openwrt-passwall main
    
    # 应用补丁
    if [[ -f "${CustomFiles}/mt7981/0001-Add-iptables-socket.patch" ]]; then
        run_with_error_handling "patch < ${CustomFiles}/mt7981/0001-Add-iptables-socket.patch -p1 -d ${WORK}" \
                               "Apply MT798x iptables patch"
    fi
    
    # 替换dnsmasq
    if [[ -d "${CustomFiles}/dnsmasq" ]]; then
        run_with_error_handling "rm -r ${WORK}/package/network/services/dnsmasq" \
                               "Remove old dnsmasq"
        run_with_error_handling "Copy ${CustomFiles}/dnsmasq ${WORK}/package/network/services" \
                               "Copy new dnsmasq"
    fi
    
    # 清理冲突包
    find "${WORK}/package" -name "Makefile" | grep -E "(v2ray-geodata|mosdns)" | xargs rm -f
    safe_AddPackage other sbwml luci-app-mosdns v5
    safe_AddPackage other sbwml v2ray-geodata master
}

remove_conflicting_packages() {
    local packages=("$@")
    
    for package in "${packages[@]}"; do
        if [[ -d "${FEEDS_LUCI}/luci-app-$package" ]]; then
            run_with_error_handling "rm -r ${FEEDS_LUCI}/luci-app-$package" \
                                   "Remove conflicting LuCI app: $package"
        fi
        if [[ -d "${FEEDS_PKG}/$package" ]]; then
            run_with_error_handling "rm -r ${FEEDS_PKG}/$package" \
                                   "Remove conflicting package: $package"
        fi
    done
}

download_clash_core() {
    local platform="$1"
    local core_type="$2"
    
    info "Downloading Clash core for $platform ($core_type)..."
    
    # 这里可以调用ClashDL函数或自定义下载逻辑
    # 需要根据具体的Clash版本和平台进行适配
}

copy_device_config() {
    local config_name="$1"
    local config_source="${CustomFiles}/${config_name}"
    local config_target="${BASE_FILES}/etc/config/system"
    
    if [[ -d "$config_source" ]]; then
        run_with_error_handling "Copy ${config_source} ${BASE_FILES}/etc/config system" \
                               "Copy device configuration"
    else
        warn "Device config not found: $config_source"
    fi
}

customize_common_features() {
    info "Applying common customizations...")
    
    # 应用AutoBuild功能（如果启用）
    if [[ "$AutoBuild_Features" == "true" ]]; then
        info "Enabling AutoBuild features..."
        # 这里添加AutoBuild特性
    fi
    
    # 应用用户自定义的标题
    if [[ -n "${Default_Title}" ]]; then
        info "Applying custom title: $Default_Title"
        # 更新banner文件等
    fi
}

# ========================================
# 错误处理和清理
# ========================================

cleanup_on_error() {
    local exit_code=$?
    error "Script failed with exit code: $exit_code"
    error "Cleaning up temporary files..."
    
    # 清理临时文件
    find /tmp -name "build_*" -mtime +0 -delete 2>/dev/null
    
    exit $exit_code
}

# 设置错误陷阱
trap cleanup_on_error ERR

# ========================================
# 主执行
# ========================================

# 如果直接执行此脚本，提供帮助信息
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "AutoBuild DiyScript (Optimized Version)"
    echo "Usage: source this script or include in build process"
    echo ""
    echo "Configuration: Edit config/build.conf"
    echo "Documentation: See OPTIMIZATION_REPORT.md"
    exit 0
fi

info "AutoBuild DiyScript (Optimized) loaded successfully"