#!/bin/bash
# install-chat-tools.sh - 安装Claude聊天管理工具

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_step() {
    echo -e "${BLUE}➜ $1${NC}"
}

# 检查操作系统
detect_os() {
    case "$(uname -s)" in
        Darwin)
            echo "macos"
            ;;
        Linux)
            if [ -f /etc/debian_version ]; then
                echo "debian"
            elif [ -f /etc/redhat-release ]; then
                echo "rhel"
            elif [ -f /etc/arch-release ]; then
                echo "arch"
            else
                echo "linux"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# 安装依赖
install_dependencies() {
    local os=$(detect_os)

    print_step "检查依赖..."

    # 检查 jq
    if command -v jq &> /dev/null; then
        print_success "jq 已安装"
    else
        print_warning "jq 未安装，正在安装..."

        case $os in
            macos)
                if command -v brew &> /dev/null; then
                    brew install jq
                else
                    print_error "请先安装 Homebrew: https://brew.sh/"
                    return 1
                fi
                ;;
            debian|ubuntu)
                sudo apt-get update && sudo apt-get install -y jq
                ;;
            rhel|centos|fedora)
                sudo yum install -y jq
                ;;
            arch)
                sudo pacman -Sy jq
                ;;
            *)
                print_error "无法自动安装 jq，请手动安装: https://stedolan.github.io/jq/download/"
                return 1
                ;;
        esac

        if command -v jq &> /dev/null; then
            print_success "jq 安装成功"
        else
            print_error "jq 安装失败"
            return 1
        fi
    fi

    # 检查其他工具
    local missing_tools=""
    for tool in "find" "date" "awk" "sed" "grep"; do
        if ! command -v $tool &> /dev/null; then
            missing_tools="$missing_tools $tool"
        fi
    done

    if [ -n "$missing_tools" ]; then
        print_warning "缺少工具:$missing_tools"
        return 1
    fi

    print_success "所有依赖已满足"
    return 0
}

# 创建工具目录
create_tool_directory() {
    local TOOLS_DIR="${1:-$HOME/claude-chat-tools}"

    print_step "创建工具目录: $TOOLS_DIR"

    mkdir -p "$TOOLS_DIR"
    mkdir -p "$TOOLS_DIR/backups"
    mkdir -p "$TOOLS_DIR/logs"
    mkdir -p "$TOOLS_DIR/config"

    print_success "工具目录创建完成"
    echo "$TOOLS_DIR"
}

# 复制脚本文件
copy_scripts() {
    local TOOLS_DIR="$1"
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    print_step "复制脚本文件..."

    # 脚本列表
    local scripts=(
        "../view/view-chats.sh"
        "../view/chat-explorer.sh"
        "../export/export-to-obsidian.sh"
        "../export/export-enhanced.sh"
        "../monitor/chat-monitor.sh"
        "install-chat-tools.sh"
        "test-chat-tools.sh"
        "config-utils.sh"
    )

    local config_files=(
        "Claude-Code-Chat-Management-Scheme.md"
    )

    # 复制脚本
    for script in "${scripts[@]}"; do
        if [ -f "$SCRIPT_DIR/$script" ]; then
            cp "$SCRIPT_DIR/$script" "$TOOLS_DIR/"
            chmod +x "$TOOLS_DIR/$script"
            print_success "复制: $script"
        else
            print_warning "未找到: $script"
        fi
    done

    # 复制配置文件
    for config in "${config_files[@]}"; do
        if [ -f "$SCRIPT_DIR/../docs/$config" ]; then
            cp "$SCRIPT_DIR/../docs/$config" "$TOOLS_DIR/config/"
            print_success "复制: $config"
        fi
    done

    # 创建配置文件
    create_config_file "$TOOLS_DIR"

    print_success "脚本复制完成"
}

# 创建配置文件
create_config_file() {
    local TOOLS_DIR="$1"
    local CONFIG_FILE="$TOOLS_DIR/config/claude-chat-tools.conf"

    cat > "$CONFIG_FILE" << EOF
# Claude Chat Tools 配置文件
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# Obsidian 配置
OBSIDIAN_VAULT="\$HOME/Obsidian"

# 导出配置
EXPORT_FORMAT="enhanced"  # basic 或 enhanced
EXPORT_DIR="\${OBSIDIAN_VAULT}/Claude-Chats"

# 监控配置
MONITOR_INTERVAL=300  # 检查间隔（秒）
MONITOR_ENABLED=true

# 清理配置
CLEANUP_DAYS=30  # 保留天数
CLEANUP_ENABLED=true

# 日志配置
LOG_LEVEL="INFO"  # DEBUG, INFO, WARNING, ERROR
LOG_RETENTION_DAYS=7

# 工具路径
TOOLS_DIR="$TOOLS_DIR"
SCRIPTS_DIR="$TOOLS_DIR"
EOF

    print_success "配置文件创建: $CONFIG_FILE"
}

# 创建工具脚本
create_tool_wrappers() {
    local TOOLS_DIR="$1"

    print_step "创建工具包装脚本..."

    # view-chats
    cat > "$TOOLS_DIR/claude-view" << 'EOF'
#!/bin/bash
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$TOOLS_DIR/view-chats.sh" "$@"
EOF

    # chat-explorer
    cat > "$TOOLS_DIR/claude-explore" << 'EOF'
#!/bin/bash
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$TOOLS_DIR/chat-explorer.sh" "$@"
EOF

    # export-to-obsidian
    cat > "$TOOLS_DIR/claude-export" << 'EOF'
#!/bin/bash
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$TOOLS_DIR/export-enhanced.sh" "$@"
EOF

    # monitor
    cat > "$TOOLS_DIR/claude-monitor" << 'EOF'
#!/bin/bash
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$TOOLS_DIR/chat-monitor.sh" "$@"
EOF

    # 设置执行权限
    chmod +x "$TOOLS_DIR"/claude-*

    print_success "工具包装脚本创建完成"
}

# 创建系统链接
create_symlinks() {
    local TOOLS_DIR="$1"
    local BIN_DIR="${2:-$HOME/bin}"

    print_step "创建符号链接..."

    # 创建用户bin目录（如果不存在）
    mkdir -p "$BIN_DIR"

    # 系统bin目录备选
    local SYSTEM_BIN_DIRS=("/usr/local/bin" "/usr/bin" "$HOME/.local/bin")

    # 尝试创建符号链接
    local linked=false
    local target_dir=""

    for dir in "$BIN_DIR" "${SYSTEM_BIN_DIRS[@]}"; do
        if [ -d "$dir" ] && [[ ":$PATH:" == *":$dir:"* ]]; then
            target_dir="$dir"
            break
        fi
    done

    if [ -z "$target_dir" ]; then
        target_dir="$BIN_DIR"
        print_warning "未在PATH中找到合适的目录，使用: $target_dir"
        print_warning "请将 $target_dir 添加到PATH环境变量"
    fi

    # 创建符号链接
    for tool in "claude-view" "claude-explore" "claude-export" "claude-monitor"; do
        if [ -f "$TOOLS_DIR/$tool" ]; then
            ln -sf "$TOOLS_DIR/$tool" "$target_dir/$tool" 2>/dev/null || \
                sudo ln -sf "$TOOLS_DIR/$tool" "$target_dir/$tool" 2>/dev/null

            if [ $? -eq 0 ]; then
                print_success "链接: $target_dir/$tool → $TOOLS_DIR/$tool"
                linked=true
            else
                print_warning "无法创建链接: $tool"
            fi
        fi
    done

    if [ "$linked" = true ]; then
        print_success "符号链接创建完成"
        echo "工具可在以下位置使用: $target_dir/claude-*"
    else
        print_warning "符号链接创建失败，请手动添加: export PATH=\"\$PATH:$TOOLS_DIR\""
    fi

    echo "$target_dir"
}

# 创建shell配置文件
create_shell_config() {
    local TOOLS_DIR="$1"
    local BIN_DIR="$2"

    print_step "配置Shell环境..."

    local shell_config=""
    local shell_rc=""

    case "$SHELL" in
        */zsh)
            shell_config="$HOME/.zshrc"
            shell_rc="$HOME/.zprofile"
            ;;
        */bash)
            shell_config="$HOME/.bashrc"
            shell_rc="$HOME/.bash_profile"
            ;;
        *)
            shell_config="$HOME/.profile"
            shell_rc="$HOME/.profile"
            ;;
    esac

    # 添加工具目录到PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo "" >> "$shell_config"
        echo "# Claude Chat Tools" >> "$shell_config"
        echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$shell_config"
        print_success "已添加PATH到: $shell_config"
    fi

    # 创建别名
    cat >> "$shell_config" << 'EOF'

# Claude Chat Tools 别名
alias claude-view='claude-view'
alias claude-explore='claude-explore'
alias claude-export='claude-export'
alias claude-monitor='claude-monitor'
alias claude-status='claude-monitor status'
alias claude-log='claude-monitor log'
alias claude-cleanup='claude-monitor cleanup'
EOF

    print_success "Shell配置完成: $shell_config"
}

# 创建快速启动脚本
create_quick_start() {
    local TOOLS_DIR="$1"

    print_step "创建快速启动脚本..."

    cat > "$TOOLS_DIR/quick-start.sh" << 'EOF'
#!/bin/bash
# Claude Chat Tools 快速启动脚本

echo "=== Claude Chat Tools 快速启动 ==="
echo ""
echo "1. 查看聊天记录: claude-view"
echo "2. 交互式浏览器: claude-explore"
echo "3. 导出到Obsidian: claude-export"
echo "4. 启动监控器: claude-monitor daemon"
echo "5. 查看状态: claude-status"
echo "6. 查看日志: claude-log"
echo ""
echo "配置目录: $(dirname "$0")/config"
echo "日志目录: $(dirname "$0")/logs"
echo ""

# 检查配置
if [ -z "$CLAUDE_OBSIDIAN_VAULT" ]; then
    echo "⚠️  环境变量 CLAUDE_OBSIDIAN_VAULT 未设置"
    echo "   默认使用: \$HOME/Obsidian"
    echo "   设置方法: export CLAUDE_OBSIDIAN_VAULT=/path/to/your/obsidian"
    echo ""
fi

echo "使用 'claude-export --help' 查看导出选项"
echo "使用 'claude-monitor help' 查看监控器帮助"
EOF

    chmod +x "$TOOLS_DIR/quick-start.sh"

    print_success "快速启动脚本创建完成"
}

# 创建卸载脚本
create_uninstall_script() {
    local TOOLS_DIR="$1"
    local BIN_DIR="$2"

    print_step "创建卸载脚本..."

    cat > "$TOOLS_DIR/uninstall.sh" << EOF
#!/bin/bash
# Claude Chat Tools 卸载脚本

set -e

echo "=== Claude Chat Tools 卸载 ==="
echo ""

# 确认
read -p "确定要卸载 Claude Chat Tools？(y/N): " confirm
if [[ ! "\$confirm" =~ ^[Yy]$ ]]; then
    echo "取消卸载"
    exit 0
fi

# 删除符号链接
echo "删除符号链接..."
for tool in claude-view claude-explore claude-export claude-monitor; do
    if [ -L "$BIN_DIR/\$tool" ]; then
        rm -f "$BIN_DIR/\$tool"
        echo "✓ 删除: $BIN_DIR/\$tool"
    fi
done

# 删除shell配置
echo "清理Shell配置..."
sed -i '' '/^# Claude Chat Tools/,/^alias claude-/d' ~/.zshrc 2>/dev/null || true
sed -i '' '/^# Claude Chat Tools/,/^alias claude-/d' ~/.bashrc 2>/dev/null || true
sed -i '' '/^# Claude Chat Tools/,/^alias claude-/d' ~/.profile 2>/dev/null || true

echo ""
echo "✅ 卸载完成"
echo ""
echo "注意: 工具目录 $TOOLS_DIR 仍保留，如需完全删除请手动执行:"
echo "  rm -rf $TOOLS_DIR"
EOF

    chmod +x "$TOOLS_DIR/uninstall.sh"

    print_success "卸载脚本创建完成"
}

# 显示安装总结
show_summary() {
    local TOOLS_DIR="$1"
    local BIN_DIR="$2"

    print_header "安装完成！"
    echo ""
    echo "📁 工具目录: $TOOLS_DIR"
    echo "🔗 命令位置: $BIN_DIR"
    echo "📋 配置文件: $TOOLS_DIR/config/"
    echo "📝 日志文件: $TOOLS_DIR/logs/"
    echo ""
    echo "🚀 快速开始:"
    echo "  1. 设置Obsidian仓库路径:"
    echo "     export CLAUDE_OBSIDIAN_VAULT=/path/to/your/obsidian"
    echo ""
    echo "  2. 查看聊天记录:"
    echo "     claude-view"
    echo ""
    echo "  3. 导出到Obsidian:"
    echo "     claude-export"
    echo ""
    echo "  4. 启动自动监控:"
    echo "     claude-monitor daemon"
    echo ""
    echo "📖 详细文档:"
    echo "  $TOOLS_DIR/config/Claude-Code-Chat-Management-Scheme.md"
    echo ""
    echo "🔄 重新加载Shell配置:"
    echo "  source ~/.zshrc  或  source ~/.bashrc"
    echo ""
    echo "❌ 卸载工具:"
    echo "  $TOOLS_DIR/uninstall.sh"
}

# 主安装函数
main_install() {
    local TOOLS_DIR="$HOME/claude-chat-tools"
    local BIN_DIR="$HOME/bin"

    print_header "Claude Chat Tools 安装程序"
    echo ""

    # 检查依赖
    if ! install_dependencies; then
        print_error "依赖安装失败"
        exit 1
    fi

    # 创建工具目录
    TOOLS_DIR=$(create_tool_directory "$TOOLS_DIR")

    # 复制脚本
    copy_scripts "$TOOLS_DIR"

    # 创建工具包装
    create_tool_wrappers "$TOOLS_DIR"

    # 创建符号链接
    BIN_DIR=$(create_symlinks "$TOOLS_DIR" "$BIN_DIR")

    # 配置Shell
    create_shell_config "$TOOLS_DIR" "$BIN_DIR"

    # 创建快速启动
    create_quick_start "$TOOLS_DIR"

    # 创建卸载脚本
    create_uninstall_script "$TOOLS_DIR" "$BIN_DIR"

    # 显示总结
    show_summary "$TOOLS_DIR" "$BIN_DIR"

    # 最后提示
    echo ""
    print_success "安装完成！请重启终端或重新加载Shell配置"
}

# 主函数
main() {
    local command="${1:-install}"

    case $command in
        "install")
            main_install
            ;;
        "uninstall")
            if [ -f "$HOME/claude-chat-tools/uninstall.sh" ]; then
                bash "$HOME/claude-chat-tools/uninstall.sh"
            else
                print_error "未找到卸载脚本"
            fi
            ;;
        "help"|"--help"|"-h")
            echo "使用说明:"
            echo "  $0 install     # 安装工具"
            echo "  $0 uninstall   # 卸载工具"
            echo "  $0 help        # 显示帮助"
            ;;
        *)
            print_error "未知命令: $command"
            echo "使用: $0 [install|uninstall|help]"
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"