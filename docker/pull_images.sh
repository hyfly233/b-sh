#!/bin/bash

# 检查参数
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <image_list_file>"
    echo "Example: $0 images.txt"
    exit 1
fi

IMAGE_FILE="$1"

# 检查文件是否存在
if [ ! -f "$IMAGE_FILE" ]; then
    echo "Error: File $IMAGE_FILE not found!"
    exit 1
fi

# 检测是否需要 sudo
DOCKER_CMD="docker"
if ! docker info >/dev/null 2>&1; then
    if sudo docker info >/dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    else
        echo "错误: 无法连接到 Docker daemon，请检查 Docker 是否正在运行"
        exit 1
    fi
fi

echo "================================"

while IFS= read -r image || [ -n "$image" ]; do
    # 跳过空行和注释行
    if [[ -z "$image" || "$image" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    # 清理镜像名中的空格
    image=$(echo "$image" | xargs)

    echo "处理镜像: $image"

    if $DOCKER_CMD pull "$image"; then
      echo "  ✓ 拉取成功"
    else
        echo "  ✗ 拉取失败"
    fi

    echo "  --------------------------------"
done < "$IMAGE_FILE"