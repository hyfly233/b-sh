#!/bin/bash

# start_simple_vllm.sh
set -e  # 遇到错误时退出

# 默认配置
DEFAULT_HOST="0.0.0.0"
DEFAULT_PORT="23333"
DEFAULT_MODEL_PATH="/models/Qwen3-32B"

# 信号处理
trap 'echo "Received SIGTERM, shutting down gracefully..."; exit 0' SIGTERM
trap 'echo "Received SIGINT, shutting down gracefully..."; exit 0' SIGINT

# 使用说明
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [ADDITIONAL_VLLM_ARGS...]

Basic Options:
    --host HOST                 Server host (default: $DEFAULT_HOST)
    --port PORT                 Server port (default: $DEFAULT_PORT)
    --model MODEL_PATH          Model path (default: $DEFAULT_MODEL_PATH)
    -h, --help                  Show this help message

Additional Arguments:
    Any other arguments will be passed directly to vLLM

Examples:
    $0 --host "0.0.0.0" --port "8080" --max-model-len 4096
    $0 --model "/path/to/model" --dtype auto --tensor-parallel-size 2
    $0 --port 8080 --api-key "sk-xxx" --trust-remote-code

Environment Variables:
    VLLM_HOST                   Server host
    VLLM_PORT                   Server port
    VLLM_MODEL                  Model path

Priority: Command line > Environment variables > Defaults

EOF
}

# 解析参数
parse_args() {
    # 初始化额外参数数组
    EXTRA_ARGS=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            --host)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --host requires a value"
                    exit 1
                fi
                HOST="$2"
                shift 2
                ;;
            --port)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --port requires a value"
                    exit 1
                fi
                PORT="$2"
                shift 2
                ;;
            --model)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --model requires a value"
                    exit 1
                fi
                MODEL_PATH="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                # 将未识别的参数添加到额外参数中
                EXTRA_ARGS+=("$1")
                # 检查下一个参数是否是值（不以 -- 开头）
                if [[ $# -gt 1 && "$2" != --* ]]; then
                    EXTRA_ARGS+=("$2")
                    shift 2
                else
                    shift 1
                fi
                ;;
        esac
    done
}

# 设置变量
set_variables() {
    HOST=${HOST:-${VLLM_HOST:-$DEFAULT_HOST}}
    PORT=${PORT:-${VLLM_PORT:-$DEFAULT_PORT}}
    MODEL_PATH=${MODEL_PATH:-${VLLM_MODEL:-$DEFAULT_MODEL_PATH}}
}

# 基础验证
validate_params() {
    # 检查端口是否为数字
    if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
        echo "Error: Port must be a number"
        exit 1
    fi

    # 检查端口范围
    if [[ $PORT -lt 1 || $PORT -gt 65535 ]]; then
        echo "Error: Port must be between 1 and 65535"
        exit 1
    fi

    # 检查模型路径（如果是目录路径）
    if [[ "$MODEL_PATH" == /* && ! -d "$MODEL_PATH" && ! -f "$MODEL_PATH" ]]; then
        echo "Warning: Model path $MODEL_PATH does not exist locally (might be a model name)"
    fi
}

# 打印配置
print_config() {
    echo "VLLM OpenAI API Server Startup"
    echo "==============================="
    echo "Host: $HOST"
    echo "Port: $PORT"
    echo "Model: $MODEL_PATH"

    if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
        echo "Additional Arguments: ${EXTRA_ARGS[*]}"
    fi
    echo "==============================="
}

# 主函数
main() {
    # 解析命令行参数
    parse_args "$@"

    # 设置变量
    set_variables

    # 验证参数
    validate_params

    # 打印配置
    print_config

    # 构建启动命令
    VLLM_CMD=(
        python3 -m vllm.entrypoints.openai.api_server
        --host "$HOST"
        --port "$PORT"
        --model "$MODEL_PATH"
    )

    # 添加额外参数
    if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
        VLLM_CMD+=("${EXTRA_ARGS[@]}")
    fi

    echo "Executing: ${VLLM_CMD[*]}"
    echo "Starting VLLM..."

    # 执行命令
    exec "${VLLM_CMD[@]}"
}

# 执行主函数
main "$@"