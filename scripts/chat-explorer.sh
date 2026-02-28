#!/bin/bash
# chat-explorer.sh - 交互式查看聊天记录

CLAUDE_DIR="$HOME/.claude"
PROJECTS_DIR="$CLAUDE_DIR/projects"

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

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

source_chat() {
    local file="$1"
    local session_id=$(basename "$file" .jsonl)

    print_header "查看会话: $session_id"
    echo "文件: $file"
    echo "大小: $(ls -lh "$file" | awk '{print $5}')"
    echo "修改时间: $(date -r "$file" '+%Y-%m-%d %H:%M:%S')"
    echo ""

    if ! command -v jq &> /dev/null; then
        print_error "请先安装 jq: brew install jq 或 sudo apt-get install jq"
        echo "原始内容前10行:"
        head -10 "$file"
        return
    fi

    # 提取基本信息
    local project=$(jq -r '.project' "$file" 2>/dev/null | head -1 || echo "unknown")
    local first_message=$(jq -r 'select(.type=="user") | .message.content[0].text' "$file" 2>/dev/null | head -1)

    echo "📝 项目: $project"
    echo "💬 第一条消息: ${first_message:0:100}..."
    echo ""

    # 显示对话内容
    echo "📄 对话内容："
    echo "----------------------------------------"

    jq -r '
        select(.type=="user" or .type=="assistant") |
        if .type == "user" then
            "\033[0;34m👤 用户\033[0m"
        else
            "\033[0;32m🤖 Claude\033[0m"
        end +
        " [" + (.timestamp|strftime("%H:%M:%S")) + "]\n" +
        (.message.content[0].text? // .message.content[0].thinking? // "") + "\n" +
        "---\n"
    ' "$file" 2>/dev/null || echo "解析错误"

    echo ""

    # 显示统计信息
    local user_count=$(jq -r 'select(.type=="user") | .type' "$file" 2>/dev/null | wc -l)
    local assistant_count=$(jq -r 'select(.type=="assistant") | .type' "$file" 2>/dev/null | wc -l)
    local total_messages=$((user_count + assistant_count))

    echo "📊 统计："
    echo "  用户消息: $user_count"
    echo "  Claude回复: $assistant_count"
    echo "  总计: $total_messages"
}

list_sessions() {
    print_header "所有会话文件"

    if [ ! -d "$PROJECTS_DIR" ]; then
        print_error "未找到项目目录"
        return
    fi

    echo "按时间排序（最新在前）："
    echo ""

    find "$PROJECTS_DIR" -name "*.jsonl" -exec ls -lt {} + 2>/dev/null | \
        while read line; do
            # 解析ls输出
            file=$(echo "$line" | awk '{print $9}')
            date_part=$(echo "$line" | awk '{print $6" "$7" "$8}')
            size=$(echo "$line" | awk '{print $5}')

            if [ -n "$file" ]; then
                session_id=$(basename "$file" .jsonl)
                echo "🆔 ${session_id:0:12}... | 📅 $date_part | 📏 $size | 📍 $file"
            fi
        done | head -20

    echo ""
    echo "共找到 $(find "$PROJECTS_DIR" -name "*.jsonl" 2>/dev/null | wc -l) 个会话"
}

list_projects() {
    print_header "项目列表"

    if [ ! -d "$PROJECTS_DIR" ]; then
        print_error "未找到项目目录"
        return
    fi

    for project in "$PROJECTS_DIR"/*; do
        if [ -d "$project" ]; then
            project_name=$(basename "$project")
            session_count=$(find "$project" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
            size=$(du -sh "$project" 2>/dev/null | cut -f1)
            echo "📁 $project_name"
            echo "  会话数: $session_count | 大小: $size"

            # 显示该项目的最新会话
            latest=$(find "$project" -name "*.jsonl" -exec ls -t {} + 2>/dev/null | head -1)
            if [ -n "$latest" ]; then
                latest_time=$(date -r "$latest" '+%Y-%m-%d %H:%M')
                echo "  最新: $latest_time"
            fi
            echo ""
        fi
    done
}

search_content() {
    local keyword="$1"

    if [ -z "$keyword" ]; then
        read -p "🔍 请输入搜索关键词: " keyword
    fi

    if [ -z "$keyword" ]; then
        print_error "关键词不能为空"
        return
    fi

    print_header "搜索: $keyword"

    echo "正在搜索，请稍候..."
    echo ""

    # 搜索文件内容
    results=$(grep -r -l "$keyword" "$PROJECTS_DIR" --include="*.jsonl" 2>/dev/null)

    if [ -z "$results" ]; then
        print_error "未找到包含 '$keyword' 的会话"
        return
    fi

    echo "找到 $(echo "$results" | wc -l) 个相关会话:"
    echo ""

    count=0
    echo "$results" | while read file; do
        count=$((count + 1))
        session_id=$(basename "$file" .jsonl)
        date_str=$(date -r "$file" '+%Y-%m-%d %H:%M')

        # 显示匹配行
        echo "🔸 [$count] $session_id ($date_str)"
        echo "   文件: $file"

        # 显示匹配内容（前2个匹配）
        matches=$(grep -o ".{0,50}$keyword.{0,50}" "$file" 2>/dev/null | head -2)
        if [ -n "$matches" ]; then
            echo "   匹配内容:"
            echo "$matches" | while read match; do
                echo "     ...$match..."
            done
        fi
        echo ""
    done

    # 提供查看选项
    echo "输入数字查看对应会话，或按回车返回主菜单: "
    read selection

    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        file=$(echo "$results" | sed -n "${selection}p")
        if [ -n "$file" ]; then
            source_chat "$file"
            read -p "按回车继续..."
        fi
    fi
}

# 主菜单
main_menu() {
    while true; do
        clear
        print_header "Claude 聊天记录浏览器"
        echo ""
        echo "1. 📋 查看最新会话"
        echo "2. 📁 列出所有会话"
        echo "3. 📂 按项目查看"
        echo "4. 🔍 搜索内容"
        echo "5. 📊 统计信息"
        echo "6. 🛠️  工具选项"
        echo "7. 🚪 退出"
        echo ""
        read -p "选择操作 (1-7): " choice

        case $choice in
            1)
                clear
                latest_file=$(find "$PROJECTS_DIR" -name "*.jsonl" -exec ls -t {} + 2>/dev/null | head -1)
                if [ -n "$latest_file" ]; then
                    source_chat "$latest_file"
                else
                    print_error "未找到会话文件"
                fi
                read -p "按回车返回主菜单..."
                ;;
            2)
                clear
                list_sessions
                echo ""
                read -p "输入会话ID查看详情（或按回车返回）: " session_input
                if [ -n "$session_input" ]; then
                    # 查找匹配的文件
                    found_file=$(find "$PROJECTS_DIR" -name "*$session_input*.jsonl" 2>/dev/null | head -1)
                    if [ -n "$found_file" ]; then
                        source_chat "$found_file"
                    else
                        print_error "未找到会话: $session_input"
                    fi
                    read -p "按回车返回主菜单..."
                fi
                ;;
            3)
                clear
                list_projects
                echo ""
                read -p "输入项目名查看（或按回车返回）: " project_input
                if [ -n "$project_input" ]; then
                    project_path="$PROJECTS_DIR/$project_input"
                    if [ -d "$project_path" ]; then
                        echo "项目: $project_input"
                        find "$project_path" -name "*.jsonl" -exec ls -lt {} + 2>/dev/null | head -10
                    else
                        print_error "未找到项目: $project_input"
                    fi
                    read -p "按回车返回主菜单..."
                fi
                ;;
            4)
                clear
                search_content
                ;;
            5)
                clear
                print_header "统计信息"
                if [ -d "$PROJECTS_DIR" ]; then
                    total_sessions=$(find "$PROJECTS_DIR" -name "*.jsonl" 2>/dev/null | wc -l)
                    total_size=$(du -sh "$CLAUDE_DIR" 2>/dev/null | cut -f1)
                    echo "总会话数: $total_sessions"
                    echo "总大小: $total_size"

                    echo ""
                    echo "按项目统计:"
                    for project in "$PROJECTS_DIR"/*; do
                        if [ -d "$project" ]; then
                            project_name=$(basename "$project")
                            count=$(find "$project" -name "*.jsonl" 2>/dev/null | wc -l)
                            if [ $count -gt 0 ]; then
                                echo "  $project_name: $count 个会话"
                            fi
                        fi
                    done

                    echo ""
                    echo "最新5个会话:"
                    find "$PROJECTS_DIR" -name "*.jsonl" -exec ls -lt {} + 2>/dev/null | head -5 | \
                        awk '{print "  " $6" "$7" "$8": " $9}'
                fi
                read -p "按回车返回主菜单..."
                ;;
            6)
                clear
                print_header "工具选项"
                echo ""
                echo "a. 导出为文本文件"
                echo "b. 批量导出到Obsidian"
                echo "c. 清理旧会话"
                echo "d. 返回主菜单"
                echo ""
                read -p "选择: " tool_choice

                case $tool_choice in
                    a|A)
                        read -p "输入导出目录（默认: ~/claude-exports）: " export_dir
                        export_dir=${export_dir:-~/claude-exports}
                        mkdir -p "$export_dir"

                        echo "正在导出..."
                        find "$PROJECTS_DIR" -name "*.jsonl" -exec sh -c '
                            file="$1"
                            export_dir="$2"
                            session_id=$(basename "$file" .jsonl)
                            output="$export_dir/$session_id.txt"

                            echo "=== Claude Chat: $session_id ===" > "$output"
                            echo "导出时间: $(date)" >> "$output"
                            echo "" >> "$output"

                            if command -v jq &> /dev/null; then
                                jq -r "
                                    select(.type==\"user\" or .type==\"assistant\") |
                                    if .type == \"user\" then \"[用户] \" else \"[Claude] \" end +
                                    (.timestamp|strftime(\"%H:%M:%S\")) + \"\\n\" +
                                    (.message.content[0].text? // .message.content[0].thinking? // \"\") + \"\\n\\n\"
                                " "$file" >> "$output" 2>/dev/null
                            else
                                echo "原始JSON内容：" >> "$output"
                                head -50 "$file" >> "$output"
                            fi

                            echo "✅ 导出: $output"
                        ' _ {} "$export_dir" \;

                        echo "导出完成到: $export_dir"
                        read -p "按回车继续..."
                        ;;
                    b|B)
                        echo "请先配置 export-to-obsidian.sh 脚本"
                        echo "或运行: bash export-to-obsidian.sh"
                        read -p "按回车继续..."
                        ;;
                    c|C)
                        read -p "删除多少天前的会话？（默认: 30）: " days
                        days=${days:-30}

                        echo "将删除 $days 天前的会话"
                        read -p "确认删除？(y/N): " confirm

                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            find "$PROJECTS_DIR" -name "*.jsonl" -mtime +$days -delete
                            print_success "已删除 $days 天前的会话"
                        fi
                        read -p "按回车继续..."
                        ;;
                esac
                ;;
            7)
                print_success "再见！"
                exit 0
                ;;
            *)
                print_error "无效选择"
                sleep 1
                ;;
        esac
    done
}

# 检查依赖
if ! command -v jq &> /dev/null; then
    print_info "建议安装 jq 以获得更好的体验"
    echo "安装命令:"
    echo "  macOS: brew install jq"
    echo "  Ubuntu/Debian: sudo apt-get install jq"
    echo "  CentOS/RHEL: sudo yum install jq"
    echo ""
    read -p "是否继续？(Y/n): " continue_choice
    if [[ "$continue_choice" =~ ^[Nn]$ ]]; then
        exit 1
    fi
fi

# 启动主菜单
main_menu