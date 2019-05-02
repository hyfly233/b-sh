#!/bin/bash

# 检查参数
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <images_tar_dir>"
    echo "Example: $0 ./images_tar_dir"
    exit 1
fi

IMAGE_TAR_DIR="$1"

# 检查目录是否存在
if [ ! -d "$IMAGE_TAR_DIR" ]; then
    echo "错误: 目录 $IMAGE_TAR_DIR 不存在!"
    exit 1
fi

# 检测是否需要 sudo
DOCKER_CMD="docker"
if ! docker info >/dev/null 2>&1; then
    if sudo docker info >/dev/null 2>&1; then
        echo "检测到需要 sudo 权限运行 Docker"
        DOCKER_CMD="sudo docker"
    else
        echo "错误: 无法连接到 Docker daemon，请检查 Docker 是否正在运行"
        exit 1
    fi
else
    echo "检测到可以直接运行 Docker"
fi

echo "使用命令: $DOCKER_CMD"
echo "================================"

# 计数器
success_count=0
failed_count=0

# 遍历目录中的所有 tar 文件
for tar_file in "$IMAGE_TAR_DIR"/*.tar; do
    # 检查是否存在 tar 文件
    if [ ! -f "$tar_file" ]; then
        echo " ✗ 目录中没有找到 .tar 文件"
        break
    fi

    echo "处理文件: $(basename "$tar_file")"

    if $DOCKER_CMD load -i "$tar_file"; then
        echo "  ✓ 导入成功"
        ((success_count++))
    else
        echo "  ✗ 导入失败"
        ((failed_count++))
    fi

    echo "  --------------------------------"
done

# 处理压缩的 tar 文件 (.tar.gz)
for tar_gz_file in "$IMAGE_TAR_DIR"/*.tar.gz; do
    if [ ! -f "$tar_gz_file" ]; then
        continue
    fi

    echo "处理压缩文件: $(basename "$tar_gz_file")"

    if gunzip -c "$tar_gz_file" | $DOCKER_CMD load; then
        echo "  ✓ 导入成功"
        ((success_count++))
    else
        echo "  ✗ 导入失败"
        ((failed_count++))
    fi

    echo "  --------------------------------"
done

echo "导入完成!"
echo "成功: $success_count"
echo "失败: $failed_count"