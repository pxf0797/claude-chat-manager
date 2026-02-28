#!/bin/bash
# init-repo.sh - 初始化 Git 仓库并推送到 GitHub

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

# 检查是否在正确的目录
check_directory() {
    if [ ! -f "README.md" ] || [ ! -f "view-chats.sh" ]; then
        print_error "请在 claude-chat-manager 目录中运行此脚本"
        exit 1
    fi
    print_success "目录检查通过"
}

# 检查 Git 是否安装
check_git() {
    if ! command -v git &> /dev/null; then
        print_error "Git 未安装，请先安装 Git"
        exit 1
    fi
    print_success "Git 已安装: $(git --version)"
}

# 初始化本地仓库
init_local_repo() {
    if [ -d ".git" ]; then
        print_warning "Git 仓库已存在"
        return 0
    fi

    print_header "初始化 Git 仓库"
    git init
    git add .
    git commit -m "Initial commit: Claude Chat Manager v1.0"

    print_success "本地仓库初始化完成"
}

# 添加远程仓库
add_remote() {
    local repo_url=""

    print_header "添加远程仓库"
    echo "请提供 GitHub 仓库 URL（例如：https://github.com/yourusername/claude-chat-manager.git）"
    echo "留空则跳过此步骤"
    read -p "GitHub 仓库 URL: " repo_url

    if [ -n "$repo_url" ]; then
        git remote add origin "$repo_url"
        print_success "远程仓库已添加: $repo_url"

        # 询问是否推送
        read -p "是否推送到远程仓库？(y/N): " push_confirm
        if [[ "$push_confirm" =~ ^[Yy]$ ]]; then
            push_to_remote "$repo_url"
        fi
    else
        print_warning "跳过远程仓库设置"
    fi
}

# 推送到远程
push_to_remote() {
    local repo_url="$1"

    print_header "推送到远程仓库"

    # 检查远程连接
    if ! git ls-remote "$repo_url" &> /dev/null; then
        print_error "无法连接到远程仓库，请检查 URL 和权限"
        return 1
    fi

    # 尝试推送
    if git push -u origin main 2>/dev/null; then
        print_success "成功推送到 main 分支"
    elif git push -u origin master 2>/dev/null; then
        print_success "成功推送到 master 分支"
    else
        print_warning "推送失败，请手动推送"
        echo "可尝试以下命令："
        echo "  git push -u origin main"
        echo "  git push -u origin master"
        echo "或创建新的远程仓库后重试"
    fi
}

# 显示状态
show_status() {
    print_header "仓库状态"

    echo "当前分支: $(git branch --show-current 2>/dev/null || echo '未设置')"
    echo "远程仓库: $(git remote get-url origin 2>/dev/null || echo '未设置')"
    echo "提交数量: $(git rev-list --count HEAD 2>/dev/null || echo '0')"

    echo ""
    echo "本地文件状态:"
    git status --short
}

# 显示帮助
show_help() {
    cat << EOF
使用说明: $0 [命令]

命令:
  init     初始化本地仓库（默认）
  remote   添加远程仓库
  push     推送到远程
  status   显示状态
  help     显示帮助

示例:
  $0          # 初始化本地仓库
  $0 remote   # 添加远程仓库
  $0 push     # 推送到远程
  $0 status   # 显示状态

手动命令参考:
  git init                    # 初始化仓库
  git add .                   # 添加所有文件
  git commit -m "消息"        # 提交更改
  git remote add origin URL   # 添加远程仓库
  git push -u origin main     # 推送到 main 分支

GitHub 创建仓库步骤:
  1. 访问 https://github.com/new
  2. 输入仓库名称: claude-chat-manager
  3. 不要初始化 README、.gitignore、LICENSE
  4. 点击 "Create repository"
  5. 复制提供的仓库 URL
EOF
}

# 主函数
main() {
    local command="${1:-init}"

    print_header "Claude Chat Manager - Git 仓库初始化"
    echo ""

    # 检查环境
    check_directory
    check_git

    case $command in
        "init")
            init_local_repo
            show_status
            ;;
        "remote")
            add_remote
            show_status
            ;;
        "push")
            push_to_remote "$(git remote get-url origin 2>/dev/null || echo '')"
            show_status
            ;;
        "status")
            show_status
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            print_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac

    echo ""
    print_success "操作完成！"
    echo ""
    echo "下一步建议："
    echo "1. 访问 https://github.com/new 创建仓库"
    echo "2. 运行: $0 remote 添加远程仓库"
    echo "3. 运行: $0 push 推送到远程"
    echo "4. 查看 GITHUB_SETUP.md 获取详细指南"
}

# 运行主函数
main "$@"