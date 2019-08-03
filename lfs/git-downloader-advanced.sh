#!/bin/bash

# git-downloader-advanced.sh - 增强版本

# 并发下载函数
download_files_parallel() {
    local max_jobs=5  # 最大并发数
    local job_count=0

    log "开始并发下载 (最大并发: $max_jobs)"

    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue

        # 等待作业槽位
        while [[ $job_count -ge $max_jobs ]]; do
            wait -n  # 等待任意后台作业完成
            job_count=$((job_count - 1))
        done

        # 启动后台下载
        {
            download_file "$file_path"
        } &

        job_count=$((job_count + 1))

    done < <(grep "^PENDING:" "$PROGRESS_FILE" 2>/dev/null | cut -d: -f2)

    # 等待所有后台作业完成
    wait

    log "并发下载完成"
}

# 文件过滤函数
filter_files() {
    local filter_pattern="$1"
    local temp_progress="$PROGRESS_FILE.filtered"

    if [[ -n "$filter_pattern" ]]; then
        log "应用文件过滤: $filter_pattern"
        grep "$filter_pattern" "$PROGRESS_FILE" > "$temp_progress"
        mv "$temp_progress" "$PROGRESS_FILE"
    fi
}

# 断点续传验证函数
verify_resume() {
    local config_age=$(stat -c %Y "$CONFIG_FILE" 2>/dev/null || echo 0)
    local progress_age=$(stat -c %Y "$PROGRESS_FILE" 2>/dev/null || echo 0)

    if [[ $progress_age -lt $config_age ]]; then
        log "警告: 进度文件比配置文件旧，可能需要重置"
        read -p "是否重置进度? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            RESET_MODE=true
        fi
    fi
}