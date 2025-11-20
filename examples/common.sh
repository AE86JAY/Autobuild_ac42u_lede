#!/bin/bash
# 公共函数库 - 提供安全的通用功能

# 配置
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载配置
load_config() {
    local config_file="${1:-$PROJECT_ROOT/config/build.conf}"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
    else
        # 默认配置
        WGET_TIMEOUT=30
        WGET_RETRIES=3
        SSL_VERIFY=true
        DEFAULT_IP="192.168.1.1"
        DEFAULT_FLAG="Full"
    fi
}

# 日志函数
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
}

info() { log "INFO" "$@"; }
warn() { log "WARN" "$@"; }
error() { log "ERROR" "$@"; }

# 错误处理装饰器
run_with_error_handling() {
    local cmd="$1"
    local description="$2"
    local exit_on_error="${3:-true}"
    
    info "Starting: $description"
    if eval "$cmd"; then
        info "✓ Completed: $description"
        return 0
    else
        local exit_code=$?
        error "✗ Failed: $description (Exit code: $exit_code)"
        if [[ "$exit_on_error" == "true" ]]; then
            exit $exit_code
        fi
        return $exit_code
    fi
}

# 安全输入验证
validate_config_name() {
    local config="$1"
    if [[ ! "$config" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        error "Invalid config name: $config"
        return 1
    fi
    return 0
}

validate_ip_address() {
    local ip="$1"
    if [[ ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        error "Invalid IP address: $ip"
        return 1
    fi
    return 0
}

validate_url() {
    local url="$1"
    # 允许的域名列表
    local allowed_domains="${ALLOWED_DOMAINS:-github.com,githubusercontent.com,raw.githubusercontent.com}"
    
    if [[ ! "$url" =~ ^https:// ]]; then
        error "Only HTTPS URLs are allowed: $url"
        return 1
    fi
    
    for domain in $(echo "$allowed_domains" | tr ',' ' '); do
        if [[ "$url" == *"$domain"* ]]; then
            return 0
        fi
    done
    
    error "URL domain not allowed: $url"
    return 1
}

# 安全的wget包装器
safe_wget() {
    local url="$1"
    local output="$2"
    local timeout="${WGET_TIMEOUT:-30}"
    local retries="${WGET_RETRIES:-3}"
    local verify_ssl="${SSL_VERIFY:-true}"
    
    # 验证URL
    if ! validate_url "$url"; then
        return 1
    fi
    
    # 选择wget参数
    local wget_args=(
        "--timeout=$timeout"
        "--tries=$retries"
        "--progress=bar:force"
        "-O" "$output"
    )
    
    if [[ "$verify_ssl" == "true" ]]; then
        # 启用SSL验证
        wget_args+=("--ca-certificate=$SSL_CERT_PATH")
    else
        # 禁用SSL验证 (不推荐)
        wget_args+=("--no-check-certificate")
        warn "SSL verification disabled for: $url"
    fi
    
    # 记录下载
    info "Downloading: $url"
    info "Output: $output"
    
    # 执行下载
    if wget "${wget_args[@]}" "$url"; then
        local file_size=$(du -h "$output" | cut -f1)
        info "Download completed: $file_size"
        return 0
    else
        error "Download failed: $url"
        rm -f "$output"
        return 1
    fi
}

# 安全的git clone
safe_git_clone() {
    local url="$1"
    local target_dir="$2"
    local branch="${3:-main}"
    
    if ! validate_url "$url"; then
        return 1
    fi
    
    if [[ -d "$target_dir" ]]; then
        warn "Directory already exists, removing: $target_dir"
        rm -rf "$target_dir"
    fi
    
    info "Cloning: $url (branch: $branch)"
    run_with_error_handling "git clone --depth 1 -b \"$branch\" \"$url\" \"$target_dir\"" \
                           "Clone repository $url"
}

# 资源检查
check_system_resources() {
    local min_disk_space="${MIN_DISK_SPACE_MB:-2048}"  # 默认2GB
    local min_memory="${MIN_MEMORY_MB:-1024}"         # 默认1GB
    
    # 检查磁盘空间
    local available_space_mb=$(df . | awk 'NR==2 {printf "%.0f", $4/1024}')
    if [[ $available_space_mb -lt $min_disk_space ]]; then
        error "Insufficient disk space: ${available_space_mb}MB available, ${min_disk_space}MB required"
        return 1
    fi
    
    # 检查内存
    local available_memory_mb=$(free -m | awk 'NR==2{print $7}')
    if [[ $available_memory_mb -lt $min_memory ]]; then
        warn "Low memory available: ${available_memory_mb}MB free, ${min_memory}MB recommended"
    fi
    
    info "System resources OK - Disk: ${available_space_mb}MB, Memory: ${available_memory_mb}MB"
    return 0
}

# 创建临时目录并设置自动清理
create_temp_dir() {
    local temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" EXIT
    echo "$temp_dir"
}

# 文件大小检查
check_file_size() {
    local file="$1"
    local max_size="${MAX_FILE_SIZE_MB:-1024}"  # 默认1GB
    
    if [[ ! -f "$file" ]]; then
        error "File not found: $file"
        return 1
    fi
    
    local file_size_mb=$(du -m "$file" | cut -f1)
    if [[ $file_size_mb -gt $max_size ]]; then
        error "File too large: ${file_size_mb}MB (max: ${max_size}MB)"
        return 1
    fi
    
    info "File size OK: $file (${file_size_mb}MB)"
    return 0
}

# 缓存机制
get_cache_dir() {
    local cache_dir="${CACHE_DIR:-/tmp/build_cache}"
    mkdir -p "$cache_dir"
    echo "$cache_dir"
}

cache_get() {
    local url="$1"
    local cache_dir=$(get_cache_dir)
    local cache_file="$cache_dir/$(echo "$url" | md5sum | cut -d' ' -f1)"
    
    if [[ -f "$cache_file" ]]; then
        local age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
        local max_age="${CACHE_MAX_AGE_HOURS:-24}"
        
        if [[ $age -lt $((max_age * 3600)) ]]; then
            info "Using cached file: $cache_file"
            cat "$cache_file"
            return 0
        else
            info "Cache expired, removing: $cache_file"
            rm -f "$cache_file"
        fi
    fi
    return 1
}

cache_set() {
    local url="$1"
    local data="$2"
    local cache_dir=$(get_cache_dir)
    local cache_file="$cache_dir/$(echo "$url" | md5sum | cut -d' ' -f1)"
    
    echo "$data" > "$cache_file"
    info "Cached: $cache_file"
}

# 并行下载包装器
parallel_download() {
    local urls=("$@")
    local pids=()
    local results=()
    
    info "Starting parallel download of ${#urls[@]} files"
    
    download_single() {
        local url="$1"
        local result_file="$2"
        
        if cache_get "$url" > "$result_file"; then
            return 0
        fi
        
        local temp_file="$result_file.tmp"
        if safe_wget "$url" "$temp_file"; then
            mv "$temp_file" "$result_file"
            cache_set "$url" "$(cat "$result_file")"
            return 0
        else
            rm -f "$temp_file"
            return 1
        fi
    }
    
    # 启动并行下载
    for i in "${!urls[@]}"; do
        local result_file="/tmp/download_$i.result"
        (download_single "${urls[$i]}" "$result_file") &
        pids+=($!)
        results+=("$result_file")
    done
    
    # 等待所有下载完成
    local failed=0
    for i in "${!pids[@]}"; do
        if wait "${pids[$i]}"; then
            info "Download $i completed successfully"
        else
            error "Download $i failed"
            ((failed++))
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        info "All downloads completed successfully"
        # 输出结果
        for result in "${results[@]}"; do
            if [[ -f "$result" ]]; then
                cat "$result"
                rm -f "$result"
            fi
        done
        return 0
    else
        error "$failed downloads failed"
        return 1
    fi
}

# 清理函数
cleanup() {
    info "Performing cleanup..."
    
    # 清理缓存
    if [[ -n "${CLEANUP_CACHE:-true}" ]]; then
        local cache_dir=$(get_cache_dir)
        find "$cache_dir" -type f -mtime +7 -delete 2>/dev/null
        info "Cleaned up old cache files"
    fi
    
    # 清理临时文件
    find /tmp -name "build_*" -mtime +1 -delete 2>/dev/null
    
    info "Cleanup completed"
}

# 初始化
init_build_environment() {
    info "Initializing build environment..."
    
    # 加载配置
    load_config
    
    # 检查资源
    if ! check_system_resources; then
        error "System resource check failed"
        return 1
    fi
    
    # 设置清理陷阱
    trap cleanup EXIT
    
    info "Build environment initialized successfully"
    return 0
}