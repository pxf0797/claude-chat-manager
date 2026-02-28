#!/bin/bash
# test-chat-tools.sh - 测试Claude聊天管理工具

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Claude Chat Tools 测试 ==="
echo ""

# 检查工具是否存在
echo "🔧 检查工具脚本..."
scripts=("$SCRIPT_DIR/../view/view-chats.sh" "$SCRIPT_DIR/../view/chat-explorer.sh" "$SCRIPT_DIR/../export/export-to-obsidian.sh" "$SCRIPT_DIR/../export/export-enhanced.sh" "$SCRIPT_DIR/../monitor/chat-monitor.sh")
missing=0

for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        echo "✅ $script"
    else
        echo "❌ $script"
        missing=$((missing + 1))
    fi
done

echo ""
if [ $missing -gt 0 ]; then
    echo "⚠️  缺少 $missing 个脚本文件"
else
    echo "✅ 所有脚本文件存在"
fi

echo ""
echo "📋 检查执行权限..."
for script in "${scripts[@]}"; do
    if [ -x "$script" ]; then
        echo "✅ $script 可执行"
    else
        echo "❌ $script 不可执行"
        chmod +x "$script" 2>/dev/null && echo "  → 已添加执行权限"
    fi
done

echo ""
echo "🔍 检查依赖..."
if command -v jq &> /dev/null; then
    echo "✅ jq 已安装"
else
    echo "❌ jq 未安装"
    echo "   安装命令: brew install jq 或 sudo apt-get install jq"
fi

echo ""
echo "📁 检查Claude目录..."
if [ -d "$HOME/.claude" ]; then
    echo "✅ Claude目录存在: $HOME/.claude"
    session_count=$(find "$HOME/.claude/projects" -name "*.jsonl" 2>/dev/null | wc -l)
    echo "   会话数量: $session_count"
else
    echo "❌ Claude目录不存在"
fi

echo ""
echo "🚀 快速测试..."
echo "1. 测试查看功能:"
"$SCRIPT_DIR/../view/view-chats.sh" 2>&1 | head -10

echo ""
echo "2. 测试导出功能（模拟）:"
if [ -d "$HOME/Obsidian" ]; then
    echo "✅ Obsidian目录存在"
    echo "   运行: ../export/export-to-obsidian.sh --help 查看导出选项"
else
    echo "⚠️  Obsidian目录不存在，请先设置:"
    echo "   export CLAUDE_OBSIDIAN_VAULT=/path/to/your/obsidian"
fi

echo ""
echo "📖 使用说明:"
echo "1. 查看聊天: ../view/view-chats.sh"
echo "2. 交互浏览: ../view/chat-explorer.sh"
echo "3. 导出到Obsidian: ../export/export-to-obsidian.sh"
echo "4. 增强导出: ../export/export-enhanced.sh"
echo "5. 自动监控: ../monitor/chat-monitor.sh daemon"
echo ""
echo "🔧 安装工具: ./install-chat-tools.sh"
echo ""
echo "✅ 测试完成"