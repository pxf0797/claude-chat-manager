#!/bin/bash
# view-chats.sh - 查看Claude Code聊天记录

CLAUDE_DIR="$HOME/.claude"
PROJECTS_DIR="$CLAUDE_DIR/projects"
HISTORY_FILE="$CLAUDE_DIR/history.jsonl"

echo "=== Claude Code 聊天记录查看器 ==="
echo ""

# 检查目录是否存在
if [ ! -d "$CLAUDE_DIR" ]; then
    echo "❌ 未找到Claude目录: $CLAUDE_DIR"
    exit 1
fi

# 1. 显示会话索引
echo "📋 最近会话列表："
echo "----------------------------------------"

if command -v jq &> /dev/null; then
    # 使用jq显示格式化列表
    if [ -f "$HISTORY_FILE" ]; then
        # 读取最后20条记录
        tail -20 "$HISTORY_FILE" | jq -r '
            def todate(ts):
                (ts/1000) | strftime("%Y-%m-%d %H:%M");
            "\(todate(.timestamp)) | \(.display) | \(.project)"
        ' | awk '{printf "%-20s | %-40s | %s\n", $1" "$2, substr($5,1,40), $7}'
    else
        echo "未找到历史索引文件"
    fi
else
    echo "⚠️  请安装 jq 工具以获得更好的显示效果"
    echo "安装命令: brew install jq 或 sudo apt-get install jq"
    echo ""
    echo "原始列表（最后10条）:"
    tail -10 "$HISTORY_FILE" 2>/dev/null || echo "无法读取历史文件"
fi

echo ""
echo "📁 项目目录："
if [ -d "$PROJECTS_DIR" ]; then
    for project in "$PROJECTS_DIR"/*; do
        if [ -d "$project" ]; then
            project_name=$(basename "$project")
            session_count=$(find "$project" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
            size=$(du -sh "$project" 2>/dev/null | cut -f1)
            echo "  📂 $project_name ($session_count 个会话, $size)"
        fi
    done
else
    echo "未找到项目目录"
fi

echo ""
echo "📊 统计信息："
echo "----------------------------------------"
if [ -d "$PROJECTS_DIR" ]; then
    total_sessions=$(find "$PROJECTS_DIR" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
    total_size=$(du -sh "$CLAUDE_DIR" 2>/dev/null | cut -f1)
    echo "总会话数: $total_sessions"
    echo "总大小: $total_size"

    # 显示最新会话
    echo ""
    echo "最新会话文件："
    find "$PROJECTS_DIR" -name "*.jsonl" -exec ls -lt {} + 2>/dev/null | head -5 | \
        awk '{printf "  %s %s %s: %s\n", $6, $7, $8, $9}'
fi

echo ""
echo "🔧 工具命令："
echo "1. 查看原始JSON文件: cat ~/.claude/projects/-Users-xfpan-claude/文件名.jsonl"
echo "2. 使用jq解析: cat 文件.jsonl | jq -r '.message.content[0].text'"
echo "3. 搜索内容: grep -r \"关键词\" ~/.claude/projects/"
echo "4. 按时间查找: find ~/.claude/projects/ -name \"*.jsonl\" -newermt \"2024-01-01\""

echo ""
echo "💡 提示：使用 chat-explorer.sh 进行交互式查看"