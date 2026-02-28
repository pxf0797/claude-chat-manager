#!/bin/bash
# config-utils.sh - 配置工具函数库

# 加载配置文件
load_config() {
    local config_file="$1"
    local config_name="$2"

    # 如果未指定配置文件，尝试多个位置
    if [ -z "$config_file" ]; then
        # 优先级：1. 用户配置文件 2. 项目配置文件 3. 示例配置文件
        if [ -f "$HOME/claude-chat-tools/config/claude-chat-tools.conf" ]; then
            config_file="$HOME/claude-chat-tools/config/claude-chat-tools.conf"
        elif [ -f "$(dirname "${BASH_SOURCE[0]}")/../../config/claude-chat-tools.conf" ]; then
            config_file="$(dirname "${BASH_SOURCE[0]}")/../../config/claude-chat-tools.conf"
        elif [ -f "$(dirname "${BASH_SOURCE[0]}")/../../config/claude-chat-tools.conf.example" ]; then
            config_file="$(dirname "${BASH_SOURCE[0]}")/../../config/claude-chat-tools.conf.example"
        fi
    fi

    # 如果找到了配置文件，加载它
    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        # 安全地source配置文件
        if [ -r "$config_file" ]; then
            # 使用点号(.)来source配置文件
            . "$config_file" 2>/dev/null || true

            # 记录加载的配置
            if [ -n "$config_name" ]; then
                echo "📄 加载配置文件: $config_file ($config_name)" >&2
            else
                echo "📄 加载配置文件: $config_file" >&2
            fi
        fi
    fi
}

# 获取配置值，支持优先级：命令行参数 > 环境变量 > 配置文件 > 默认值
get_config_value() {
    local var_name="$1"
    local default_value="$2"
    local config_file="${3:-}"

    # 先尝试环境变量
    local env_var_name=$(echo "$var_name" | tr '[:lower:]' '[:upper:]')
    local env_value="${!env_var_name:-}"

    # 如果未找到环境变量，尝试从配置文件加载
    if [ -z "$env_value" ] && [ -n "$config_file" ] && [ -f "$config_file" ]; then
        load_config "$config_file" "get_config_value"
        # 重新尝试环境变量（可能已被配置文件设置）
        env_value="${!env_var_name:-}"
    fi

    # 返回优先级最高的值
    if [ -n "$env_value" ]; then
        echo "$env_value"
    else
        echo "$default_value"
    fi
}

# 获取Obsidian仓库路径（带优先级）
get_obsidian_vault() {
    local default_vault="${1:-$HOME/Obsidian}"
    local config_file="${2:-}"

    # 优先级：CLAUDE_OBSIDIAN_VAULT环境变量 > 配置文件 > 默认值
    local vault_path="${CLAUDE_OBSIDIAN_VAULT:-}"

    if [ -z "$vault_path" ]; then
        # 尝试从配置文件加载
        load_config "$config_file" "obsidian_vault"
        vault_path="${OBSIDIAN_VAULT:-}"
    fi

    if [ -n "$vault_path" ]; then
        # 展开路径中的变量（如 $HOME）
        eval "echo \"$vault_path\""
    else
        echo "$default_vault"
    fi
}

# 验证Obsidian仓库路径
validate_obsidian_vault() {
    local vault_path="$1"

    if [ ! -d "$vault_path" ]; then
        echo "❌ 错误: 未找到Obsidian仓库路径: $vault_path" >&2
        echo "" >&2
        echo "请执行以下操作之一：" >&2
        echo "1. 设置环境变量:" >&2
        echo "   export CLAUDE_OBSIDIAN_VAULT=/path/to/your/obsidian" >&2
        echo "" >&2
        echo "2. 创建配置文件:" >&2
        echo "   cp config/claude-chat-tools.conf.example config/claude-chat-tools.conf" >&2
        echo "   # 然后编辑配置文件中的 OBSIDIAN_VAULT 设置" >&2
        echo "" >&2
        echo "3. 使用默认路径: $HOME/Obsidian" >&2
        echo "   mkdir -p \"$HOME/Obsidian\"" >&2
        return 1
    fi

    echo "✅ Obsidian仓库路径有效: $vault_path" >&2
    return 0
}

# 显示配置信息
show_config() {
    echo "=== 当前配置信息 ==="
    echo ""

    local vault_path=$(get_obsidian_vault)
    echo "📁 Obsidian仓库: $vault_path"

    if [ -d "$vault_path" ]; then
        echo "   ✅ 存在"
    else
        echo "   ❌ 不存在"
    fi

    echo ""
    echo "🔧 导出目录: ${vault_path}/Claude-Chats"

    # 显示配置文件位置
    echo ""
    echo "📄 配置文件位置:"
    if [ -f "$HOME/claude-chat-tools/config/claude-chat-tools.conf" ]; then
        echo "   ✅ $HOME/claude-chat-tools/config/claude-chat-tools.conf"
    elif [ -f "$(dirname "${BASH_SOURCE[0]}")/../../config/claude-chat-tools.conf" ]; then
        echo "   ✅ $(dirname "${BASH_SOURCE[0]}")/../../config/claude-chat-tools.conf"
    else
        echo "   ⚠️  未找到配置文件"
        echo "   使用: cp config/claude-chat-tools.conf.example config/claude-chat-tools.conf"
    fi

    echo ""
    echo "🌍 环境变量:"
    if [ -n "${CLAUDE_OBSIDIAN_VAULT:-}" ]; then
        echo "   ✅ CLAUDE_OBSIDIAN_VAULT=${CLAUDE_OBSIDIAN_VAULT}"
    else
        echo "   ⚠️  CLAUDE_OBSIDIAN_VAULT 未设置"
    fi
}

# 初始化配置系统
init_config() {
    echo "🔧 初始化配置系统..."

    # 检查是否已有配置文件
    local project_config="$(dirname "${BASH_SOURCE[0]}")/../../config/claude-chat-tools.conf"
    local user_config="$HOME/claude-chat-tools/config/claude-chat-tools.conf"

    if [ ! -f "$project_config" ] && [ ! -f "$user_config" ]; then
        echo "📄 创建默认配置文件..."

        # 复制示例配置文件
        local example_config="$(dirname "${BASH_SOURCE[0]}")/../../config/claude-chat-tools.conf.example"
        if [ -f "$example_config" ]; then
            mkdir -p "$(dirname "$project_config")"
            cp "$example_config" "$project_config"
            echo "✅ 配置文件已创建: $project_config"
            echo "   请编辑此文件以配置您的Obsidian路径"
        else
            echo "⚠️  未找到示例配置文件"
        fi
    fi

    # 加载配置
    load_config "" "初始化"
}

# 如果脚本被直接执行，显示配置信息
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_config
fi