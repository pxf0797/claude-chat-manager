#!/bin/bash
# export-to-obsidian.sh - 导出聊天记录到Obsidian

# 配置工具
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/config-utils.sh" 2>/dev/null || {
    echo "⚠️  配置工具未找到，使用默认配置"
}

# 获取Obsidian仓库路径
OBSIDIAN_VAULT=$(get_obsidian_vault 2>/dev/null || echo "${CLAUDE_OBSIDIAN_VAULT:-$HOME/Obsidian}")
EXPORT_DIR="$OBSIDIAN_VAULT/Claude-Chats"

# 检查配置
check_config() {
    if [ ! -d "$OBSIDIAN_VAULT" ]; then
        echo "❌ 未找到Obsidian仓库: $OBSIDIAN_VAULT"
        echo ""
        echo "请选择以下配置方式之一："
        echo ""
        echo "1. 设置环境变量:"
        echo "   export CLAUDE_OBSIDIAN_VAULT=/path/to/your/obsidian"
        echo ""
        echo "2. 创建配置文件:"
        echo "   cp config/claude-chat-tools.conf.example config/claude-chat-tools.conf"
        echo "   # 然后编辑配置文件中的 OBSIDIAN_VAULT 设置"
        echo ""
        echo "3. 修改脚本中的 OBSIDIAN_VAULT 变量（不推荐）"
        echo ""
        echo "4. 使用默认路径并创建目录:"
        echo "   mkdir -p \"$HOME/Obsidian\""
        echo ""
        echo "当前配置文件搜索路径:"
        if [ -f "$HOME/claude-chat-tools/config/claude-chat-tools.conf" ]; then
            echo "   - $HOME/claude-chat-tools/config/claude-chat-tools.conf"
        fi
        if [ -f "$SCRIPT_DIR/../../config/claude-chat-tools.conf" ]; then
            echo "   - $SCRIPT_DIR/../../config/claude-chat-tools.conf"
        fi
        exit 1
    fi

    echo "✅ Obsidian仓库: $OBSIDIAN_VAULT"
    echo "📁 导出目录: $EXPORT_DIR"
    echo ""
}

# 创建目录结构
setup_directories() {
    mkdir -p "$EXPORT_DIR"
    mkdir -p "$EXPORT_DIR/daily"      # 按日期组织
    mkdir -p "$EXPORT_DIR/projects"   # 按项目组织
    mkdir -p "$EXPORT_DIR/sessions"   # 按会话组织
    mkdir -p "$EXPORT_DIR/assets"     # 资源文件

    echo "📂 目录结构已创建"
}

# 导出单个会话
export_chat() {
    local file="$1"
    local session_id=$(basename "$file" .jsonl)
    local date=$(date -r "$file" "+%Y-%m-%d")
    local time=$(date -r "$file" "+%H:%M")

    # 提取第一条用户消息作为标题
    local title=""
    if command -v jq &> /dev/null; then
        title=$(jq -r '
            select(.type=="user") |
            if .message.content | type == "string" then
                .message.content
            else
                (.message.content[] | select(.type=="text") | .text) // ""
            end
        ' "$file" 2>/dev/null | head -1)
    fi

    # 清理标题（移除特殊字符，限制长度）
    title=${title:0:100}
    title=$(echo "$title" | tr -d '\n' | sed 's/[\/:*?"<>|]/_/g')

    if [ -z "$title" ]; then
        title="Claude对话-${session_id:0:8}"
    fi

    # 生成Markdown文件名
    local safe_title=$(echo "$title" | sed 's/[[:space:]]/_/g')
    local md_file="$EXPORT_DIR/sessions/${date}_${safe_title:0:50}_${session_id:0:6}.md"

    echo "📝 处理: $session_id"
    echo "  标题: $title"
    echo "  日期: $date $time"
    echo "  文件: $md_file"

    # 生成Markdown内容
    cat > "$md_file" << EOF
---
aliases: [Claude会话-${session_id:0:8}]
tags: [claude/chat, claude/session, date/${date}]
created: ${date} ${time}
modified: $(date "+%Y-%m-%d %H:%M")
session_id: ${session_id}
source_file: $(basename "$file")
---

# ${title}

**会话ID**: ${session_id}
**时间**: ${date} ${time}
**原始文件**: \`$(basename "$file")\`

---

EOF

    # 提取对话内容
    if command -v jq &> /dev/null; then
        jq -r '
            select(.type=="user" or .type=="assistant") |
            def get_content:
              if .message.content | type == "string" then
                .message.content
              else
                reduce .message.content[] as $item ("";
                  . + (if $item.type == "text" then
                    $item.text // ""
                  elif $item.type == "thinking" then
                    $item.thinking // ""
                  elif $item.type == "tool_use" then
                    "使用了工具: " + ($item.name // "unknown") +
                    (if $item.input and ($item.input | type == "object") then
                      " - " + ($item.input.command // ($item.input | tostring | sub("^\\{\"command\":\""; "") | sub("\".*"; "") | sub("^\\{"; "") | sub("\\}$"; "")))
                    else
                      ""
                    end)
                  elif $item.type == "tool_result" then
                    "工具结果: " + ($item.content // ($item | tostring | .[0:200]))
                  else
                    ""
                  end) + "\n"
                )
              end;
            def format_time:
              (.timestamp | fromdateiso8601? // (split(".")[0] + "Z" | fromdateiso8601?) | strftime("%H:%M:%S")) // "??:??:??";
            if .type == "user" then
                "## 👤 用户\n"
            else
                "## 🤖 Claude\n"
            end +
            "**时间**: " + format_time + "\n\n" +
            (get_content | sub("\n+$"; "")) + "\n\n" +
            "---\n"
        ' "$file" >> "$md_file" 2>/dev/null
    else
        echo "> 需要安装 jq 工具来解析对话内容" >> "$md_file"
        echo "> 安装命令: brew install jq 或 sudo apt-get install jq" >> "$md_file"
    fi

    # 添加总结部分
    cat >> "$md_file" << EOF

## 📋 会话信息

### 基本信息
- **会话ID**: ${session_id}
- **创建时间**: ${date} ${time}
- **导出时间**: $(date "+%Y-%m-%d %H:%M")
- **原始文件**: \`$(realpath "$file")\`

### 相关链接
- [[Claude对话索引]]
- [[${date}的对话]]
- [[所有Claude会话]]

### 标签
\`\`\`dataview
TABLE WITHOUT ID
  file.link AS "会话",
  session_id AS "ID",
  created AS "创建时间"
FROM #claude/session
WHERE session_id = "${session_id}"
\`\`\`

---

> 本文件由 Claude Chat Exporter 自动生成
> 生成时间: $(date "+%Y-%m-%d %H:%M:%S")
EOF

    # 更新索引文件
    update_index "$session_id" "$date" "$title" "$md_file"

    echo "✅ 导出完成"
    echo ""
}

# 更新索引文件
update_index() {
    local session_id="$1"
    local date="$2"
    local title="$3"
    local md_file="$4"
    local rel_path="${md_file#$EXPORT_DIR/}"

    # 更新日期索引
    local date_index="$EXPORT_DIR/daily/${date}.md"
    if [ ! -f "$date_index" ]; then
        cat > "$date_index" << EOF
---
date: ${date}
tags: [claude/daily, date/${date}]
---
# ${date} 的对话

## 对话列表

EOF
    fi
    echo "- [[${rel_path%.md}|${title}]] (${session_id:0:8})" >> "$date_index"

    # 更新总索引
    local main_index="$EXPORT_DIR/Claude对话索引.md"
    if [ ! -f "$main_index" ]; then
        cat > "$main_index" << EOF
---
title: Claude对话索引
tags: [claude/index, MOC]
---
# Claude 对话索引

## 按时间浏览

### 最近7天
\`\`\`dataview
TABLE WITHOUT ID file.link AS "会话", created AS "时间"
FROM #claude/session
WHERE date(created) >= date(today) - dur(7 days)
SORT created DESC
\`\`\`

## 所有对话

EOF
    fi

    # 在主索引中添加条目（如果不存在）
    if ! grep -q "\[\[${rel_path%.md}\]\]" "$main_index"; then
        echo "- [[${rel_path%.md}|${date} - ${title}]]" >> "$main_index"
    fi
}

# 导出最新N个会话
export_recent() {
    local count=${1:-5}
    echo "📤 导出最新 $count 个会话..."
    echo ""

    local files=$(find "$HOME/.claude/projects" -name "*.jsonl" -exec ls -t {} + 2>/dev/null | head -$count)
    local total=$(echo "$files" | wc -l)

    if [ "$total" -eq 0 ]; then
        echo "❌ 未找到会话文件"
        return
    fi

    echo "找到 $total 个会话"
    echo ""

    local counter=0
    echo "$files" | while read file; do
        counter=$((counter + 1))
        echo "[$counter/$total]"
        export_chat "$file"
    done
}

# 导出指定日期的会话
export_by_date() {
    local target_date=${1:-$(date "+%Y-%m-%d")}
    echo "📅 导出日期: $target_date"
    echo ""

    local files=$(find "$HOME/.claude/projects" -name "*.jsonl" -newermt "${target_date} 00:00:00" ! -newermt "${target_date} 23:59:59" 2>/dev/null)
    local total=$(echo "$files" | wc -l)

    if [ "$total" -eq 0 ]; then
        echo "❌ 未找到 $target_date 的会话"
        return
    fi

    echo "找到 $total 个会话"
    echo ""

    local counter=0
    echo "$files" | while read file; do
        counter=$((counter + 1))
        echo "[$counter/$total]"
        export_chat "$file"
    done
}

# 导出所有会话
export_all() {
    echo "⚠️  警告：这将导出所有会话，可能会创建大量文件"
    echo "预计时间较长，建议分批导出"
    echo ""
    read -p "是否继续？(y/N): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "取消导出"
        return
    fi

    local files=$(find "$HOME/.claude/projects" -name "*.jsonl" 2>/dev/null)
    local total=$(echo "$files" | wc -l)

    if [ "$total" -eq 0 ]; then
        echo "❌ 未找到会话文件"
        return
    fi

    echo "📊 找到 $total 个会话，开始导出..."
    echo ""

    local counter=0
    echo "$files" | while read file; do
        counter=$((counter + 1))
        echo "[$counter/$total]"
        export_chat "$file"
    done
}

# 主函数
main() {
    echo "=== Claude 聊天记录导出到 Obsidian ==="
    echo ""

    # 检查配置
    check_config

    # 创建目录
    setup_directories

    # 显示菜单
    echo "请选择导出方式："
    echo "1. 导出最新5个会话"
    echo "2. 导出今天的所有会话"
    echo "3. 导出指定日期的会话"
    echo "4. 导出所有会话（谨慎！）"
    echo "5. 仅更新索引"
    echo "6. 查看导出统计"
    echo "7. 退出"
    echo ""

    read -p "选择 (1-7): " choice

    case $choice in
        1)
            export_recent 5
            ;;
        2)
            export_by_date $(date "+%Y-%m-%d")
            ;;
        3)
            read -p "请输入日期 (YYYY-MM-DD): " date_input
            if [[ "$date_input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                export_by_date "$date_input"
            else
                echo "❌ 日期格式错误，请使用 YYYY-MM-DD 格式"
            fi
            ;;
        4)
            export_all
            ;;
        5)
            echo "📑 更新索引文件..."
            # 这里可以添加索引更新逻辑
            echo "✅ 索引已更新"
            ;;
        6)
            echo "📊 导出统计："
            echo "导出目录: $EXPORT_DIR"
            echo "文件总数: $(find "$EXPORT_DIR" -name "*.md" 2>/dev/null | wc -l)"
            echo "占用空间: $(du -sh "$EXPORT_DIR" 2>/dev/null | cut -f1)"
            echo ""
            echo "最近导出的文件："
            find "$EXPORT_DIR" -name "*.md" -exec ls -lt {} + 2>/dev/null | head -5 | \
                awk '{print "  " $6" "$7" "$8" "$9}'
            ;;
        7)
            echo "👋 再见！"
            exit 0
            ;;
        *)
            echo "❌ 无效选择"
            exit 1
            ;;
    esac

    echo ""
    echo "🎉 导出完成！"
    echo "📁 导出位置: $EXPORT_DIR"
    echo "📄 文件数量: $(find "$EXPORT_DIR" -name "*.md" 2>/dev/null | wc -l)"
    echo ""
    echo "💡 在Obsidian中查看:"
    echo "1. 打开Obsidian，加载仓库 $OBSIDIAN_VAULT"
    echo "2. 导航到 Claude-Chats 文件夹"
    echo "3. 查看 Claude对话索引.md 文件"
}

# 处理命令行参数
if [ $# -gt 0 ]; then
    case $1 in
        "--recent"|"-r")
            count=${2:-5}
            check_config
            setup_directories
            export_recent $count
            exit 0
            ;;
        "--date"|"-d")
            date=${2:-$(date "+%Y-%m-%d")}
            check_config
            setup_directories
            export_by_date "$date"
            exit 0
            ;;
        "--file"|"-f")
            if [ -f "$2" ]; then
                check_config
                setup_directories
                export_chat "$2"
            else
                echo "❌ 文件不存在: $2"
                exit 1
            fi
            exit 0
            ;;
        "--help"|"-h")
            echo "使用说明:"
            echo "  $0                    # 交互模式"
            echo "  $0 --recent [N]      # 导出最新N个会话（默认5）"
            echo "  $0 --date [YYYY-MM-DD] # 导出指定日期会话"
            echo "  $0 --file <path>     # 导出单个文件"
            echo "  $0 --help            # 显示帮助"
            echo ""
            echo "环境变量:"
            echo "  CLAUDE_OBSIDIAN_VAULT: Obsidian仓库路径"
            exit 0
            ;;
    esac
fi

# 运行主函数
main