#!/bin/bash

# start_vllm.sh
set -e  # 遇到错误时退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 默认配置
DEFAULT_HOST="0.0.0.0"
DEFAULT_PORT="23333"
DEFAULT_MODEL_NAME="Qwen3-32B"
DEFAULT_MODEL_PATH="/models/Qwen3-32B"
DEFAULT_MAX_MODEL_LEN="12288"
DEFAULT_API_KEY="sk-xxxxxxxxxxxxxx"
DEFAULT_DTYPE="auto"
DEFAULT_PP_SIZE="1"
DEFAULT_TP_SIZE="1"

# 信号处理
trap 'echo "Received SIGTERM, shutting down gracefully..."; exit 0' SIGTERM
trap 'echo "Received SIGINT, shutting down gracefully..."; exit 0' SIGINT

# 使用说明
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    --host HOST                 Server host (default: $DEFAULT_HOST)
    --port PORT                 Server port (default: $DEFAULT_PORT)
    --model-name NAME           Served model name (default: $DEFAULT_MODEL_NAME)
    --model-path PATH           Model path (default: $DEFAULT_MODEL_PATH)
    --max-model-len LEN         Max model length (default: $DEFAULT_MAX_MODEL_LEN)
    --api-key KEY               API key (default: from env or $DEFAULT_API_KEY)
    --dtype TYPE                Data type (default: $DEFAULT_DTYPE)
    --pp-size SIZE              Pipeline parallel size (default: $DEFAULT_PP_SIZE)
    --tp-size SIZE              Tensor parallel size (default: $DEFAULT_TP_SIZE)
    -h, --help                  Show this help message

Environment Variables:
    VLLM_HOST                   Server host
    VLLM_PORT                   Server port
    VLLM_MODEL_NAME             Served model name
    VLLM_MODEL_PATH             Model path
    VLLM_MAX_MODEL_LEN          Max model length
    VLLM_API_KEY                API key
    VLLM_DTYPE                  Data type
    VLLM_PP_SIZE                Pipeline parallel size
    VLLM_TP_SIZE                Tensor parallel size

Priority (highest to lowest):
    1. Command line arguments
    2. Environment variables
    3. Default values

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --host)
                if [[ -z "$2" ]]; then
                    echo "Error: --host requires a value"
                    exit 1
                fi
                HOST="$2"
                shift 2
                ;;
            --port)
                if [[ -z "$2" ]]; then
                    echo "Error: --port requires a value"
                    exit 1
                fi
                PORT="$2"
                shift 2
                ;;
            --model-name)
                if [[ -z "$2" ]]; then
                    echo "Error: --model-name requires a value"
                    exit 1
                fi
                MODEL_NAME="$2"
                shift 2
                ;;
            --model-path)
                if [[ -z "$2" ]]; then
                    echo "Error: --model-path requires a value"
                    exit 1
                fi
                MODEL_PATH="$2"
                shift 2
                ;;
            --max-model-len)
                if [[ -z "$2" ]]; then
                    echo "Error: --max-model-len requires a value"
                    exit 1
                fi
                MAX_MODEL_LEN="$2"
                shift 2
                ;;
            --api-key)
                if [[ -z "$2" ]]; then
                    echo "Error: --api-key requires a value"
                    exit 1
                fi
                API_KEY="$2"
                shift 2
                ;;
            --dtype)
                if [[ -z "$2" ]]; then
                    echo "Error: --dtype requires a value"
                    exit 1
                fi
                DTYPE="$2"
                shift 2
                ;;
            --pp-size)
                if [[ -z "$2" ]]; then
                    echo "Error: --pp-size requires a value"
                    exit 1
                fi
                PP_SIZE="$2"
                shift 2
                ;;
            --tp-size)
                if [[ -z "$2" ]]; then
                    echo "Error: --tp-size requires a value"
                    exit 1
                fi
                TP_SIZE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# 设置变量 - 优先级：命令行参数 > 环境变量 > 默认值
set_variables() {
    HOST=${HOST:-${VLLM_HOST:-$DEFAULT_HOST}}
    PORT=${PORT:-${VLLM_PORT:-$DEFAULT_PORT}}
    MODEL_NAME=${MODEL_NAME:-${VLLM_MODEL_NAME:-$DEFAULT_MODEL_NAME}}
    MODEL_PATH=${MODEL_PATH:-${VLLM_MODEL_PATH:-$DEFAULT_MODEL_PATH}}
    MAX_MODEL_LEN=${MAX_MODEL_LEN:-${VLLM_MAX_MODEL_LEN:-$DEFAULT_MAX_MODEL_LEN}}
    API_KEY=${API_KEY:-${VLLM_API_KEY:-$DEFAULT_API_KEY}}
    DTYPE=${DTYPE:-${VLLM_DTYPE:-$DEFAULT_DTYPE}}
    PP_SIZE=${PP_SIZE:-${VLLM_PP_SIZE:-$DEFAULT_PP_SIZE}}
    TP_SIZE=${TP_SIZE:-${VLLM_TP_SIZE:-$DEFAULT_TP_SIZE}}
}

# 验证参数
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

    # 检查数值参数
    if ! [[ "$MAX_MODEL_LEN" =~ ^[0-9]+$ ]]; then
        echo "Error: Max model length must be a number"
        exit 1
    fi

    if ! [[ "$PP_SIZE" =~ ^[0-9]+$ ]]; then
        echo "Error: Pipeline parallel size must be a number"
        exit 1
    fi

    if ! [[ "$TP_SIZE" =~ ^[0-9]+$ ]]; then
        echo "Error: Tensor parallel size must be a number"
        exit 1
    fi

    # 检查模型目录是否存在
    if [[ ! -d "$MODEL_PATH" ]]; then
        echo "Error: Model directory $MODEL_PATH does not exist"
        exit 1
    fi

    # 检查API密钥格式
    if [[ -z "$API_KEY" ]]; then
        echo "Error: API key cannot be empty"
        exit 1
    fi
}

# 打印配置信息
print_config() {
    echo "Starting VLLM OpenAI API Server with configuration:"
    echo "Host: $HOST"
    echo "Port: $PORT"
    echo "Model Name: $MODEL_NAME"
    echo "Model Path: $MODEL_PATH"
    echo "Max Model Length: $MAX_MODEL_LEN"
    echo "Data Type: $DTYPE"
    echo "Pipeline Parallel Size: $PP_SIZE"
    echo "Tensor Parallel Size: $TP_SIZE"
    echo "API Key: ${API_KEY:0:10}..."
    echo "=========================="
}

# 主函数
main() {
    echo "VLLM OpenAI API Server Startup Script"
    echo "======================================"

    # 解析命令行参数
    parse_args "$@"

    # 设置变量
    set_variables

    # 验证参数
    validate_params

    # 打印配置
    print_config

    echo "Launching VLLM..."
    # 启动命令
    exec python3 -m vllm.entrypoints.openai.api_server \
        --host "$HOST" \
        --port "$PORT" \
        --uvicorn-log-level warning \
        --served-model-name "$MODEL_NAME" \
        --enforce-eager \
        --model "$MODEL_PATH" \
        --max-model-len "$MAX_MODEL_LEN" \
        --api-key "$API_KEY" \
        --dtype "$DTYPE" \
        --pipeline-parallel-size "$PP_SIZE" \
        --tensor-parallel-size "$TP_SIZE"
}

# 执行主函数
main "$@"