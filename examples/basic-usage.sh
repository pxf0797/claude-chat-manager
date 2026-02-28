#!/bin/bash
# 基本使用示例
# 假设从项目根目录运行

echo "=== Claude Chat Manager 基本使用示例 ==="
echo ""

# 1. 查看聊天记录
echo "1. 查看最近聊天:"
echo "   ./scripts/view/view-chats.sh"
echo ""

# 2. 交互式浏览
echo "2. 交互式浏览:"
echo "   ./scripts/view/chat-explorer.sh"
echo ""

# 3. 导出到Obsidian
echo "3. 导出最近3个对话到Obsidian:"
echo "   ./scripts/export/export-enhanced.sh --recent 3"
echo ""

# 4. 自动监控
echo "4. 启动一次性监控:"
echo "   ./scripts/monitor/chat-monitor.sh once"
echo ""

# 5. 安装工具
echo "5. 安装到系统:"
echo "   ./scripts/utils/install-chat-tools.sh install"
echo ""

echo "更多功能请查看 README.md 和 docs/ 目录中的文档。"