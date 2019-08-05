#!/bin/bash

# git-downloader-monitor.sh - 监控脚本

monitor_progress() {
    local progress_file="$1"

    while [[ -f "$progress_file" ]]; do
        clear
        echo "Git 下载进度监控 - $(date)"
        echo "=================================="

        local total=$(grep -c ":" "$progress_file" 2>/dev/null || echo 0)
        local completed=$(grep -c "^COMPLETED:" "$progress_file" 2>/dev/null || echo 0)
        local failed=$(grep -c "^FAILED:" "$progress_file" 2>/dev/null || echo 0)
        local pending=$(grep -c "^PENDING:" "$progress_file" 2>/dev/null || echo 0)

        local percent=0
        if [[ $total -gt 0 ]]; then
            percent=$((completed * 100 / total))
        fi

        echo "总计: $total"
        echo "完成: $completed ($percent%)"
        echo "失败: $failed"
        echo "待下载: $pending"

        # 进度条
        local bar_length=50
        local filled=$((percent * bar_length / 100))
        local empty=$((bar_length - filled))

        printf "进度: ["
        printf "%${filled}s" | tr ' ' '='
        printf "%${empty}s" | tr ' ' '-'
        printf "] %d%%\n" $percent

        echo ""
        echo "最近完成的文件:"
        grep "^COMPLETED:" "$progress_file" | tail -5 | cut -d: -f2 | sed 's/^/  /'

        sleep 5
    done
}

# 启动监控
if [[ $# -eq 1 ]]; then
    monitor_progress "$1"
else
    echo "用法: $0 <progress_file>"
    echo "例如: $0 ./downloads/.download-progress"
fi