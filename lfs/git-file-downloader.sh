#!/bin/bash

# git-file-downloader.sh - Git 仓库文件断点续传下载器

set -e

# 配置参数
REPO_URL=""
TARGET_DIR=""
PROGRESS_FILE=""
CONFIG_FILE="git-downloader.config"
TEMP_DIR=""
MAX_RETRIES=3
RETRY_DELAY=5

# 显示帮助信息
show_help() {
    cat << EOF
Git 文件断点续传下载器

用法: $0 [选项]

选项:
    -r, --repo URL          Git 仓库 URL (必需)
    -d, --dir PATH          下载目录 (默认: ./downloads)
    -c, --config FILE       配置文件 (默认: git-downloader.config)
    -t, --temp PATH         临时目录 (默认: /tmp/git-downloader)
    --max-retries NUM       最大重试次数 (默认: 3)
    --retry-delay SEC       重试延迟秒数 (默认: 5)
    --resume                从上次中断处继续
    --reset                 重置进度重新开始
    -h, --help              显示帮助信息

示例:
    $0 -r https://github.com/user/repo.git -d ./my-downloads
    $0 --resume  # 继续上次的下载
    $0 --reset   # 重新开始下载

EOF
}

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$PROGRESS_FILE.log"
}

# 错误处理
error_exit() {
    log "错误: $1"
    exit 1
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--repo)
                REPO_URL="$2"
                shift 2
                ;;
            -d|--dir)
                TARGET_DIR="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -t|--temp)
                TEMP_DIR="$2"
                shift 2
                ;;
            --max-retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            --retry-delay)
                RETRY_DELAY="$2"
                shift 2
                ;;
            --resume)
                RESUME_MODE=true
                shift
                ;;
            --reset)
                RESET_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error_exit "未知选项: $1"
                ;;
        esac
    done
}

# 加载或创建配置
load_config() {
    if [[ -f "$CONFIG_FILE" ]] && [[ "$RESUME_MODE" == true ]]; then
        log "加载配置文件: $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        # 验证必需参数
        [[ -z "$REPO_URL" ]] && error_exit "必须指定仓库 URL (-r 选项)"

        # 设置默认值
        TARGET_DIR="${TARGET_DIR:-./downloads}"
        TEMP_DIR="${TEMP_DIR:-/tmp/git-downloader-$$}"
        PROGRESS_FILE="$TARGET_DIR/.download-progress"

        # 保存配置
        cat > "$CONFIG_FILE" << EOF
REPO_URL="$REPO_URL"
TARGET_DIR="$TARGET_DIR"
TEMP_DIR="$TEMP_DIR"
PROGRESS_FILE="$PROGRESS_FILE"
MAX_RETRIES=$MAX_RETRIES
RETRY_DELAY=$RETRY_DELAY
EOF
        log "配置已保存到: $CONFIG_FILE"
    fi
}

# 初始化环境
init_environment() {
    # 创建目录
    mkdir -p "$TARGET_DIR"
    mkdir -p "$TEMP_DIR"

    # 初始化进度文件
    if [[ "$RESET_MODE" == true ]] || [[ ! -f "$PROGRESS_FILE" ]]; then
        cat > "$PROGRESS_FILE" << EOF
# Git 文件下载进度
# 格式: 状态:文件路径:时间戳
# 状态: PENDING(待下载), DOWNLOADING(下载中), COMPLETED(已完成), FAILED(失败)
EOF
        log "进度文件已初始化: $PROGRESS_FILE"
    fi
}

# 获取仓库文件列表
get_file_list() {
    local repo_dir="$TEMP_DIR/repo"

    log "克隆仓库以获取文件列表..."

    if [[ -d "$repo_dir" ]]; then
        cd "$repo_dir"
        git pull origin HEAD || error_exit "更新仓库失败"
    else
        git clone --depth 1 "$REPO_URL" "$repo_dir" || error_exit "克隆仓库失败"
        cd "$repo_dir"
    fi

    # 获取所有文件路径（排除目录）
    git ls-tree -r --name-only HEAD > "$TEMP_DIR/file_list.txt"

    local file_count=$(wc -l < "$TEMP_DIR/file_list.txt")
    log "发现 $file_count 个文件"

    # 将未记录的文件添加到进度文件
    while IFS= read -r file_path; do
        if ! grep -q ":$file_path:" "$PROGRESS_FILE" 2>/dev/null; then
            echo "PENDING:$file_path:$(date +%s)" >> "$PROGRESS_FILE"
        fi
    done < "$TEMP_DIR/file_list.txt"
}

# 下载单个文件
download_file() {
    local file_path="$1"
    local repo_dir="$TEMP_DIR/repo"
    local target_file="$TARGET_DIR/$file_path"
    local target_dir=$(dirname "$target_file")

    # 创建目标目录
    mkdir -p "$target_dir"

    # 更新状态为下载中
    update_file_status "$file_path" "DOWNLOADING"

    # 复制文件
    if cp "$repo_dir/$file_path" "$target_file" 2>/dev/null; then
        update_file_status "$file_path" "COMPLETED"
        log "✅ 下载完成: $file_path"
        return 0
    else
        update_file_status "$file_path" "FAILED"
        log "❌ 下载失败: $file_path"
        return 1
    fi
}

# 更新文件状态
update_file_status() {
    local file_path="$1"
    local status="$2"
    local timestamp=$(date +%s)

    # 创建临时文件
    local temp_file="$PROGRESS_FILE.tmp"

    # 更新状态
    if grep -q ":$file_path:" "$PROGRESS_FILE"; then
        sed "s/:$file_path:.*/$status:$file_path:$timestamp/" "$PROGRESS_FILE" > "$temp_file"
    else
        cp "$PROGRESS_FILE" "$temp_file"
        echo "$status:$file_path:$timestamp" >> "$temp_file"
    fi

    mv "$temp_file" "$PROGRESS_FILE"
}

# 获取下载统计
get_download_stats() {
    local total=$(grep -c ":" "$PROGRESS_FILE" 2>/dev/null || echo 0)
    local completed=$(grep -c "^COMPLETED:" "$PROGRESS_FILE" 2>/dev/null || echo 0)
    local failed=$(grep -c "^FAILED:" "$PROGRESS_FILE" 2>/dev/null || echo 0)
    local pending=$(grep -c "^PENDING:" "$PROGRESS_FILE" 2>/dev/null || echo 0)
    local downloading=$(grep -c "^DOWNLOADING:" "$PROGRESS_FILE" 2>/dev/null || echo 0)

    echo "$total $completed $failed $pending $downloading"
}

# 显示进度
show_progress() {
    read total completed failed pending downloading <<< $(get_download_stats)

    local percent=0
    if [[ $total -gt 0 ]]; then
        percent=$((completed * 100 / total))
    fi

    log "进度统计: 总计=$total, 完成=$completed, 失败=$failed, 待下载=$pending, 下载中=$downloading ($percent%)"
}

# 主下载循环
download_files() {
    log "开始下载文件..."

    local retry_count=0

    while true; do
        # 获取待下载的文件
        local pending_files=$(grep "^PENDING:" "$PROGRESS_FILE" 2>/dev/null | cut -d: -f2 || true)

        if [[ -z "$pending_files" ]]; then
            log "所有文件下载完成!"
            break
        fi

        local has_success=false

        # 下载每个待处理的文件
        while IFS= read -r file_path; do
            [[ -z "$file_path" ]] && continue

            log "正在下载: $file_path"

            if download_file "$file_path"; then
                has_success=true
            fi

            # 显示进度
            show_progress

            # 小延迟避免过度使用系统资源
            sleep 0.1

        done <<< "$pending_files"

        # 如果这轮没有成功下载任何文件
        if [[ "$has_success" == false ]]; then
            retry_count=$((retry_count + 1))
            if [[ $retry_count -ge $MAX_RETRIES ]]; then
                log "达到最大重试次数，退出"
                break
            fi
            log "第 $retry_count 次重试，等待 $RETRY_DELAY 秒..."
            sleep $RETRY_DELAY
        else
            retry_count=0
        fi
    done
}

# 生成下载报告
generate_report() {
    local report_file="$TARGET_DIR/download_report.txt"

    cat > "$report_file" << EOF
Git 文件下载报告
生成时间: $(date)
仓库地址: $REPO_URL
下载目录: $TARGET_DIR

=== 统计信息 ===
EOF

    read total completed failed pending downloading <<< $(get_download_stats)

    cat >> "$report_file" << EOF
总文件数: $total
已完成: $completed
失败: $failed
待下载: $pending
下载中: $downloading

=== 失败文件列表 ===
EOF

    grep "^FAILED:" "$PROGRESS_FILE" 2>/dev/null | cut -d: -f2 >> "$report_file" || echo "无失败文件" >> "$report_file"

    log "报告已生成: $report_file"
}

# 清理函数
cleanup() {
    log "正在清理临时文件..."
    if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# 信号处理
trap cleanup EXIT
trap 'log "收到中断信号，正在保存进度..."; cleanup; exit 1' INT TERM

# 主函数
main() {
    echo "Git 文件断点续传下载器 v1.0"
    echo "================================"

    parse_args "$@"
    load_config
    init_environment

    log "开始下载任务"
    log "仓库: $REPO_URL"
    log "目标目录: $TARGET_DIR"

    get_file_list
    show_progress
    download_files
    generate_report

    log "下载任务完成"
}

# 执行主函数
main "$@"