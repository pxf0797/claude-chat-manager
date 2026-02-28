# Claude Code 聊天记录管理方案

## 📋 目标
1. **查看原始聊天记录**：快速访问和搜索历史会话
2. **导出到笔记工具**：将对话内容整理到 Obsidian、Logseq 等双链笔记
3. **自动化流程**：减少手动操作，提高效率

## 🏗️ 整体架构

```
原始数据 (JSONL) → 提取转换 → 输出格式 → 笔记集成
    ↓              ↓          ↓
 查看工具       转换脚本     Markdown      Obsidian
```

## 🔍 第一部分：查看原始聊天记录

### 1.1 快速查看工具

创建 `view-chats.sh` 脚本：
```bash
#!/bin/bash
# view-chats.sh - 查看Claude Code聊天记录

CLAUDE_DIR="$HOME/.claude"
PROJECTS_DIR="$CLAUDE_DIR/projects"

echo "=== Claude Code 聊天记录查看器 ==="
echo ""

# 1. 显示会话索引
echo "📋 最近会话列表："
echo "----------------------------------------"
jq -r '.[-10:] | reverse[] | "\(.timestamp|strftime("%Y-%m-%d %H:%M")) | \(.display) | \(.project)"' \
    <(cat "$CLAUDE_DIR/history.jsonl" | jq -s '.') 2>/dev/null || \
    echo "请安装 jq: brew install jq"

echo ""
echo "📁 项目目录："
ls "$PROJECTS_DIR" | sed 's/^/  /'
```

### 1.2 交互式查看器

创建 `chat-explorer.sh` 交互式脚本：
```bash
#!/bin/bash
# chat-explorer.sh - 交互式查看聊天记录

source_chat() {
    local file="$1"
    echo "=== 查看会话: $(basename "$file" .jsonl) ==="
    echo ""

    # 提取对话内容
    jq -r '
        select(.type=="user" or .type=="assistant") |
        "【\(.type|ascii_upcase)】 \(.timestamp|strftime("%H:%M:%S"))\n" +
        (.message.content[0].text? // .message.content[0].thinking? // "") +
        "\n---\n"
    ' "$file" 2>/dev/null || \
    echo "无法解析文件，请安装 jq"
}

# 主菜单
while true; do
    echo ""
    echo "1. 查看最新会话"
    echo "2. 列出所有会话"
    echo "3. 按项目查看"
    echo "4. 搜索内容"
    echo "5. 退出"
    read -p "选择: " choice

    case $choice in
        1) find "$HOME/.claude/projects" -name "*.jsonl" -exec ls -t {} + | head -1 | xargs -I {} source_chat {} ;;
        2) find "$HOME/.claude/projects" -name "*.jsonl" -exec ls -lt {} \; ;;
        3) echo "项目列表:"; ls "$HOME/.claude/projects"; read -p "输入项目名: " proj; find "$HOME/.claude/projects/$proj" -name "*.jsonl" -exec ls -lt {} \; ;;
        4) read -p "搜索关键词: " keyword; grep -r -l "$keyword" "$HOME/.claude/projects" --include="*.jsonl" ;;
        5) exit 0 ;;
        *) echo "无效选择" ;;
    esac
done
```

## 📤 第二部分：导出到 Obsidian

### 2.1 基础导出脚本

创建 `export-to-obsidian.sh`：
```bash
#!/bin/bash
# export-to-obsidian.sh - 导出聊天记录到Obsidian

OBSIDIAN_VAULT="$HOME/Obsidian"  # 修改为你的Obsidian仓库路径
EXPORT_DIR="$OBSIDIAN_VAULT/Claude-Chats"

# 创建导出目录
mkdir -p "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR/daily"   # 按日期组织
mkdir -p "$EXPORT_DIR/projects" # 按项目组织
mkdir -p "$EXPORT_DIR/tags"    # 标签目录

export_chat() {
    local file="$1"
    local session_id=$(basename "$file" .jsonl)
    local date=$(date -r "$file" "+%Y-%m-%d")
    local title=$(jq -r 'select(.type=="user") | .message.content[0].text' "$file" | head -1 | cut -c1-50)

    # 生成Markdown文件名
    local md_file="$EXPORT_DIR/daily/${date}-${session_id:0:8}.md"

    # 生成Markdown内容
    cat > "$md_file" << EOF
---
aliases: [Claude会话-${session_id:0:8}]
tags: [claude-chat, ${date}]
created: $(date -r "$file" "+%Y-%m-%d %H:%M")
session_id: ${session_id}
---

# Claude 对话记录
**时间**: $(date -r "$file" "+%Y-%m-%d %H:%M")
**会话ID**: ${session_id}
**主题**: ${title:-无标题}

---

EOF

    # 提取对话内容
    jq -r '
        select(.type=="user" or .type=="assistant") |
        "## " + (.type|ascii_upcase) + "\n" +
        "**时间**: " + (.timestamp|strftime("%H:%M:%S")) + "\n\n" +
        (.message.content[0].text? // .message.content[0].thinking? // "") + "\n\n" +
        "---\n"
    ' "$file" >> "$md_file" 2>/dev/null

    # 添加标签和链接
    cat >> "$md_file" << EOF

## 🔗 相关链接
- [[Claude 对话索引]]
- [[${date} 的对话]]

## 🏷️ 标签
\`\`\`dataview
LIST
FROM #claude-chat
WHERE session_id = "${session_id}"
\`\`\`
EOF

    echo "✅ 已导出: $md_file"
}

# 导出最新N个会话
export_recent() {
    local count=${1:-5}
    echo "导出最新 $count 个会话..."

    find "$HOME/.claude/projects" -name "*.jsonl" -exec ls -t {} + | head -$count | while read file; do
        export_chat "$file"
    done
}

# 按日期导出
export_by_date() {
    local target_date=${1:-$(date "+%Y-%m-%d")}
    echo "导出日期: $target_date"

    find "$HOME/.claude/projects" -name "*.jsonl" -newermt "${target_date} 00:00:00" ! -newermt "${target_date} 23:59:59" | while read file; do
        export_chat "$file"
    done
}

# 主菜单
echo "=== Claude 聊天记录导出到 Obsidian ==="
echo "1. 导出最新5个会话"
echo "2. 导出今天的所有会话"
echo "3. 导出指定日期的会话"
echo "4. 导出所有会话（谨慎！）"
read -p "选择: " choice

case $choice in
    1) export_recent 5 ;;
    2) export_by_date $(date "+%Y-%m-%d") ;;
    3) read -p "输入日期 (YYYY-MM-DD): " date_input; export_by_date "$date_input" ;;
    4) echo "开始导出所有会话..."; find "$HOME/.claude/projects" -name "*.jsonl" | while read file; do export_chat "$file"; done ;;
    *) echo "无效选择" ;;
esac

echo ""
echo "📊 导出统计："
echo "Obsidian目录: $EXPORT_DIR"
find "$EXPORT_DIR" -name "*.md" | wc -l | xargs echo "已导出文件数:"
```

### 2.2 增强版导出（支持双链笔记）

创建 `export-enhanced.sh`：
```bash
#!/bin/bash
# export-enhanced.sh - 增强版导出，支持双链笔记特性

VAULT_PATH="$HOME/Obsidian"  # 你的Obsidian仓库
EXPORT_BASE="$VAULT_PATH/Claude-Chats"

# 确保目录存在
mkdir -p "$EXPORT_BASE/Conversations"
mkdir -p "$EXPORT_BASE/Projects"
mkdir -p "$EXPORT_BASE/Topics"
mkdir -p "$EXPORT_BASE/People"
mkdir -p "$EXPORT_BASE/Weekly"

generate_conversation() {
    local file="$1"
    local session_id=$(basename "$file" .jsonl)
    local date=$(date -r "$file" "+%Y-%m-%d")
    local week=$(date -r "$file" "+%Y-W%W")

    # 提取对话主题（第一条用户消息）
    local first_message=$(jq -r 'select(.type=="user") | .message.content[0].text' "$file" 2>/dev/null | head -1)
    local topic=$(echo "$first_message" | grep -o "#[^ ]*" | head -1 | sed 's/#//' || echo "general")

    # 生成文件名
    local md_file="$EXPORT_BASE/Conversations/${date}-${topic}-${session_id:0:6}.md"

    # 创建Frontmatter
    cat > "$md_file" << EOF
---
id: ${session_id}
date: ${date}
time: $(date -r "$file" "+%H:%M")
week: "${week}"
project: $(jq -r '.project' "$file" 2>/dev/null | head -1 || echo "unknown")
tags: [claude/conversation, date/${date}, week/${week}]
topic: ${topic}
participants: [user, claude]
links:
  - "[[Claude Conversations Index]]"
  - "[[Weekly/${week}]]"
  - "[[Topics/${topic}]]"
---
EOF

    # 添加标题
    echo -e "\n# 💬 ${first_message:0:100}\n" >> "$md_file"
    echo "**会话ID**: ${session_id} | **日期**: ${date} | **话题**: ${topic}\n" >> "$md_file"

    # 提取对话内容（更友好的格式）
    jq -r '
        select(.type=="user" or .type=="assistant") |
        if .type == "user" then
            "## 👤 用户\n"
        else
            "## 🤖 Claude\n"
        end +
        "> *" + (.timestamp|strftime("%H:%M")) + "*\n\n" +
        (.message.content[0].text? // .message.content[0].thinking? // "") + "\n\n" +
        "---\n"
    ' "$file" >> "$md_file" 2>/dev/null

    # 添加总结和行动项
    echo -e "\n## 📝 总结\n" >> "$md_file"
    echo "- 对话主题: ${topic}" >> "$md_file"
    echo "- 对话时长: $(jq -r 'select(.type=="user" or .type=="assistant") | .timestamp' "$file" 2>/dev/null | sort | sed -n '1p;$p' | xargs echo)" >> "$md_file"
    echo "- 消息数量: $(jq -r 'select(.type=="user" or .type=="assistant") | .type' "$file" 2>/dev/null | wc -l)" >> "$md_file"

    # 创建反向链接
    update_index_files "$session_id" "$date" "$week" "$topic" "$md_file"

    echo "✅ $md_file"
}

update_index_files() {
    local session_id="$1"
    local date="$2"
    local week="$3"
    local topic="$4"
    local md_file="$5"

    # 更新日期索引
    local date_index="$EXPORT_BASE/Daily/${date}.md"
    mkdir -p "$(dirname "$date_index")"
    if [[ ! -f "$date_index" ]]; then
        cat > "$date_index" << EOF
---
date: ${date}
tags: [claude/daily]
---
# ${date} 的对话

EOF
    fi
    echo "- [[${md_file#$EXPORT_BASE/}]]" >> "$date_index"

    # 更新周索引
    local week_index="$EXPORT_BASE/Weekly/${week}.md"
    mkdir -p "$(dirname "$week_index")"
    if [[ ! -f "$week_index" ]]; then
        cat > "$week_index" << EOF
---
week: "${week}"
tags: [claude/weekly]
---
# 第 ${week#*-} 周对话汇总

EOF
    fi
    echo "- [[${md_file#$EXPORT_BASE/}]]" >> "$week_index"

    # 更新话题索引
    local topic_index="$EXPORT_BASE/Topics/${topic}.md"
    mkdir -p "$(dirname "$topic_index")"
    if [[ ! -f "$topic_index" ]]; then
        cat > "$topic_index" << EOF
---
topic: ${topic}
tags: [claude/topic]
---
# ${topic} 相关对话

EOF
    fi
    echo "- [[${md_file#$EXPORT_BASE/}]]" >> "$topic_index"
}

# 主函数
main() {
    echo "=== Claude 对话导出到双链笔记 ==="

    # 导出今天的所有对话
    today=$(date "+%Y-%m-%d")
    echo "导出今天的对话 ($today)..."

    find "$HOME/.claude/projects" -name "*.jsonl" -newermt "${today} 00:00:00" ! -newermt "${today} 23:59:59" | while read file; do
        generate_conversation "$file"
    done

    # 创建总索引
    create_main_index

    echo ""
    echo "🎉 导出完成！"
    echo "位置: $EXPORT_BASE"
    find "$EXPORT_BASE" -name "*.md" | wc -l | xargs echo "总文件数:"
}

create_main_index() {
    cat > "$EXPORT_BASE/Claude Conversations Index.md" << EOF
---
title: Claude 对话索引
tags: [claude/index, MOC]
---
# Claude 对话总索引

## 按时间浏览
### [[Daily/最近7天|最近7天]]
### [[Weekly/最近4周|最近4周]]
### [[Monthly/本月|本月]]

## 按话题浏览
\`\`\`dataview
TABLE WITHOUT ID file.link AS "对话", topic AS "话题", date AS "日期"
FROM #claude/conversation
SORT date DESC
LIMIT 50
\`\`\`

## 统计
- 总对话数: \`\`\`dataview\`\`\`js
dv.pages('#claude/conversation').length
\`\`\`\`\`\`
- 最近活跃话题: \`\`\`dataview\`\`\`js
dv.pages('#claude/conversation').groupBy(p => p.topic).sort(p => p.rows.length, 'desc').limit(5)
\`\`\`\`\`\`
EOF
}

main
```

## 🤖 第三部分：自动化方案

### 3.1 监控脚本（自动导出新对话）

创建 `chat-monitor.sh`：
```bash
#!/bin/bash
# chat-monitor.sh - 监控新对话并自动导出

# 配置
OBSIDIAN_DIR="$HOME/Obsidian/Claude-Chats"
LAST_CHECK_FILE="$HOME/.claude-chat-last-check"
LOG_FILE="$HOME/.claude-chat-monitor.log"

# 初始化
mkdir -p "$(dirname "$LAST_CHECK_FILE")"
touch "$LAST_CHECK_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

export_new_chats() {
    local last_check=$(cat "$LAST_CHECK_FILE" 2>/dev/null || echo "0")
    local current_time=$(date +%s)

    # 查找上次检查后修改的文件
    find "$HOME/.claude/projects" -name "*.jsonl" -newermt "@$last_check" | while read file; do
        log "发现新对话: $file"

        # 导出到Obsidian
        "$HOME/claude/export-to-obsidian.sh" --file "$file" --auto

        # 可选：发送通知
        osascript -e 'display notification "新的Claude对话已导出到Obsidian" with title "Claude Chat Monitor"' 2>/dev/null || true
    done

    # 更新检查时间
    echo "$current_time" > "$LAST_CHECK_FILE"
}

# 运行模式
case "$1" in
    "daemon")
        echo "启动监控守护进程..."
        while true; do
            export_new_chats
            sleep 300  # 每5分钟检查一次
        done
        ;;
    "once")
        echo "执行单次检查..."
        export_new_chats
        ;;
    "log")
        tail -f "$LOG_FILE"
        ;;
    *)
        echo "用法: $0 [daemon|once|log]"
        ;;
esac
```

### 3.2 系统服务（macOS LaunchAgent）

创建 `com.user.claudechatmonitor.plist`：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.claudechatmonitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/xfpan/claude/chat-monitor.sh</string>
        <string>daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/claude-monitor.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/claude-monitor.err</string>
    <key>StartInterval</key>
    <integer>300</integer>
</dict>
</plist>
```

安装服务：
```bash
# 复制到LaunchAgents目录
cp com.user.claudechatmonitor.plist ~/Library/LaunchAgents/

# 加载服务
launchctl load ~/Library/LaunchAgents/com.user.claudechatmonitor.plist

# 查看状态
launchctl list | grep claude
```

## 🔧 第四部分：安装与使用

### 4.1 快速安装

创建安装脚本 `install-chat-tools.sh`：
```bash
#!/bin/bash
# install-chat-tools.sh - 安装聊天管理工具

echo "=== 安装 Claude 聊天管理工具 ==="

# 检查依赖
if ! command -v jq &> /dev/null; then
    echo "安装 jq..."
    brew install jq || sudo apt-get install jq || echo "请手动安装 jq: https://stedolan.github.io/jq/"
fi

# 创建工具目录
TOOLS_DIR="$HOME/claude-chat-tools"
mkdir -p "$TOOLS_DIR"

# 复制脚本
cp view-chats.sh chat-explorer.sh export-to-obsidian.sh export-enhanced.sh chat-monitor.sh "$TOOLS_DIR/"

# 设置权限
chmod +x "$TOOLS_DIR"/*.sh

# 创建软链接到PATH
ln -sf "$TOOLS_DIR/view-chats.sh" /usr/local/bin/view-claude-chats 2>/dev/null || \
ln -sf "$TOOLS_DIR/view-chats.sh" ~/bin/view-claude-chats 2>/dev/null

echo ""
echo "✅ 安装完成！"
echo "工具位置: $TOOLS_DIR"
echo ""
echo "📖 使用说明:"
echo "1. 查看聊天: view-claude-chats 或 $TOOLS_DIR/view-chats.sh"
echo "2. 导出到Obsidian: $TOOLS_DIR/export-to-obsidian.sh"
echo "3. 启动监控: $TOOLS_DIR/chat-monitor.sh daemon"
```

### 4.2 简化使用别名

添加到 `~/.zshrc` 或 `~/.bashrc`：
```bash
# Claude Chat Management
alias claude-view='bash ~/claude-chat-tools/view-chats.sh'
alias claude-export='bash ~/claude-chat-tools/export-to-obsidian.sh'
alias claude-sync='bash ~/claude-chat-tools/chat-monitor.sh once'
alias claude-search='grep -r'
```

## 📊 第五部分：维护与优化

### 5.1 定期清理脚本

创建 `cleanup-chats.sh`：
```bash
#!/bin/bash
# cleanup-chats.sh - 清理旧聊天记录

# 保留最近N天的原始记录
KEEP_DAYS=30
# 保留最近N天的导出记录
EXPORT_KEEP_DAYS=90

echo "=== Claude 聊天记录清理 ==="

# 清理原始JSONL文件（保留30天）
echo "清理原始记录（保留${KEEP_DAYS}天）..."
find "$HOME/.claude/projects" -name "*.jsonl" -mtime +$KEEP_DAYS -delete

# 清理导出的Markdown（保留90天）
if [[ -d "$HOME/Obsidian/Claude-Chats" ]]; then
    echo "清理导出记录（保留${EXPORT_KEEP_DAYS}天）..."
    find "$HOME/Obsidian/Claude-Chats" -name "*.md" -mtime +$EXPORT_KEEP_DAYS -delete
fi

# 更新索引
echo "更新索引..."
"$HOME/claude-chat-tools/export-enhanced.sh" --update-index-only

echo "✅ 清理完成"
```

### 5.2 统计报告

创建 `chat-stats.sh`：
```bash
#!/bin/bash
# chat-stats.sh - 生成统计报告

echo "=== Claude 聊天记录统计 ==="
echo "生成时间: $(date)"

echo ""
echo "📈 原始数据统计:"
echo "总会话数: $(find "$HOME/.claude/projects" -name "*.jsonl" | wc -l)"
echo "总大小: $(du -sh "$HOME/.claude/projects" | cut -f1)"
echo "项目数: $(ls "$HOME/.claude/projects" | wc -l)"

echo ""
echo "📊 最近活跃:"
find "$HOME/.claude/projects" -name "*.jsonl" -exec ls -lt {} + | head -5 | \
    awk '{print $6" "$7" "$8": "$9}'

echo ""
echo "🏷️ 话题分布（前10）:"
find "$HOME/.claude/projects" -name "*.jsonl" -exec jq -r 'select(.type=="user") | .message.content[0].text' {} \; | \
    grep -o "#[^ ]*" | sort | uniq -c | sort -rn | head -10

if [[ -d "$HOME/Obsidian/Claude-Chats" ]]; then
    echo ""
    echo "📤 导出统计:"
    echo "导出文件数: $(find "$HOME/Obsidian/Claude-Chats" -name "*.md" | wc -l)"
    echo "导出大小: $(du -sh "$HOME/Obsidian/Claude-Chats" | cut -f1)"
fi

echo ""
echo "💡 建议:"
echo "1. 当前占用空间正常"
echo "2. 建议每周执行一次导出"
echo "3. 每月执行一次清理"
```

## 🚀 快速开始

### 第一步：安装工具
```bash
# 下载本方案文档
# 创建工具脚本
chmod +x *.sh

# 运行安装
./install-chat-tools.sh
```

### 第二步：测试查看功能
```bash
# 查看最近聊天
view-claude-chats

# 交互式查看
bash chat-explorer.sh
```

### 第三步：导出到Obsidian
```bash
# 修改脚本中的Obsidian路径
# 然后导出
bash export-to-obsidian.sh
```

### 第四步：设置自动化
```bash
# 启动监控（后台运行）
bash chat-monitor.sh daemon &

# 或添加到crontab（每10分钟检查）
echo "*/10 * * * * /bin/bash $HOME/claude-chat-tools/chat-monitor.sh once" | crontab -
```

## 🔗 与Obsidian集成建议

### 1. 模板系统
在Obsidian中创建模板 `Templates/Claude Conversation.md`：
```markdown
---
id: <% tp.date.now("YYYYMMDDHHmmss") %>
date: <% tp.date.now("YYYY-MM-DD") %>
time: <% tp.date.now("HH:mm") %>
session_id: {{SESSION_ID}}
tags: [claude/conversation]
---

# {{TITLE}}

**主题**: {{TOPIC}}
**项目**: {{PROJECT}}

---

{{CONTENT}}

## 🔗 相关
- [[Claude Conversations Index]]
- [[{{DATE}}]]
```

### 2. Dataview查询
在Obsidian中创建查询视图：

```markdown
```dataview
TABLE WITHOUT ID
  file.link AS "对话",
  date AS "日期",
  topic AS "话题",
  length(file.outlinks) AS "链接数"
FROM "Claude-Chats/Conversations"
WHERE contains(tags, "claude/conversation")
SORT date DESC
LIMIT 20
```
```

### 3. 图谱视图
- 使用 `claude/conversation` 标签组织对话
- 按 `date/` 和 `topic/` 子标签分类
- 创建MOC（内容地图）文件连接相关对话

## 📝 注意事项

1. **隐私保护**：聊天记录可能包含敏感信息，确保Obsidian仓库加密或私有
2. **存储空间**：定期清理旧记录，避免占用过多空间
3. **兼容性**：脚本依赖 `jq` 工具，确保已安装
4. **备份**：定期备份原始JSONL文件
5. **性能**：会话文件过多时，导出可能较慢

## 🔄 更新与维护

- 定期检查脚本更新
- 根据使用情况调整清理策略
- 优化导出格式以适应笔记工具更新

---

**总结**：本方案提供了从查看原始记录到自动化导出到Obsidian的完整流程。用户可以根据需求选择不同的工具组合，实现高效的知识管理。