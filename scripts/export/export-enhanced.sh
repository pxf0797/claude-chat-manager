#!/bin/bash
# export-enhanced.sh - 增强版导出，支持双链笔记特性

# 配置工具
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/config-utils.sh" 2>/dev/null || {
    echo "⚠️  配置工具未找到，使用默认配置"
}

# 获取Obsidian仓库路径
VAULT_PATH=$(get_obsidian_vault 2>/dev/null || echo "${CLAUDE_OBSIDIAN_VAULT:-$HOME/Obsidian}")
EXPORT_BASE="$VAULT_PATH/Claude-Chats"

# 检查依赖
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo "❌ 需要安装 jq 工具"
        echo "安装命令:"
        echo "  macOS: brew install jq"
        echo "  Ubuntu: sudo apt-get install jq"
        exit 1
    fi

    if [ ! -d "$VAULT_PATH" ]; then
        echo "❌ 未找到Obsidian仓库: $VAULT_PATH"
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
        echo "3. 使用默认路径并创建目录:"
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

    echo "✅ 依赖检查通过"
    echo "📂 Obsidian仓库: $VAULT_PATH"
    echo "📁 导出目录: $EXPORT_BASE"
}

# 初始化目录结构
init_directories() {
    echo "📁 创建目录结构..."

    # 主目录
    mkdir -p "$EXPORT_BASE/Conversations"
    mkdir -p "$EXPORT_BASE/Daily"
    mkdir -p "$EXPORT_BASE/Weekly"
    mkdir -p "$EXPORT_BASE/Monthly"
    mkdir -p "$EXPORT_BASE/Projects"
    mkdir -p "$EXPORT_BASE/Topics"
    mkdir -p "$EXPORT_BASE/Tags"
    mkdir -p "$EXPORT_BASE/People"
    mkdir -p "$EXPORT_BASE/Attachments"

    echo "✅ 目录结构已创建"
}

# 提取话题标签
extract_topic() {
    local content="$1"
    # 提取话题标签（#开头）
    local topic=$(echo "$content" | grep -o "#[a-zA-Z0-9_-]\+" | head -1 | sed 's/^#//')

    if [ -z "$topic" ]; then
        # 如果没有话题标签，尝试从内容推断
        local first_line=$(echo "$content" | head -1)
        if [[ "$first_line" =~ ^[[:space:]]*[a-zA-Z]+ ]]; then
            topic=$(echo "$first_line" | awk '{print $1}' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
        fi
    fi

    echo "${topic:-general}"
}

# 生成会话文件
generate_conversation() {
    local file="$1"
    local session_id=$(basename "$file" .jsonl)
    local date=$(date -r "$file" "+%Y-%m-%d")
    local time=$(date -r "$file" "+%H:%M:%S")
    local week=$(date -r "$file" "+%Y-W%W")
    local month=$(date -r "$file" "+%Y-%m")

    echo "🔍 处理会话: $session_id"

    # 提取第一条用户消息
    local first_message=$(jq -r '
        select(.type=="user") |
        if .message.content | type == "string" then
            .message.content
        else
            (.message.content[] | select(.type=="text") | .text) // ""
        end
    ' "$file" 2>/dev/null | head -1 || echo "无标题对话")
    local topic=$(extract_topic "$first_message")
    local project=$(jq -r '.project' "$file" 2>/dev/null | head -1 | sed 's/[^a-zA-Z0-9_-]//g' || echo "default")

    # 生成文件名
    local safe_topic=$(echo "$topic" | sed 's/[[:space:]]/_/g')
    local safe_project=$(echo "$project" | sed 's/[[:space:]]/_/g')
    local md_file="$EXPORT_BASE/Conversations/${date}_${safe_project}_${safe_topic}_${session_id:0:6}.md"

    echo "  主题: $topic"
    echo "  项目: $project"
    echo "  日期: $date"
    echo "  文件: $(basename "$md_file")"

    # 提取所有标签
    local all_tags=$(jq -r '
        select(.type=="user") |
        if .message.content | type == "string" then
            .message.content
        else
            (.message.content[] | select(.type=="text") | .text) // ""
        end
    ' "$file" 2>/dev/null | grep -o "#[a-zA-Z0-9_-]\+" | sort | uniq | tr '\n' ',' | sed 's/#//g' | sed 's/,$//')

    # 创建Frontmatter
    cat > "$md_file" << EOF
---
id: ${session_id}
type: conversation
date: ${date}
time: ${time}
datetime: ${date}T${time}
week: "${week}"
month: "${month}"
project: "${project}"
topic: "${topic}"
tags: [claude/conversation, date/${date}, week/${week}, month/${month}, project/${project}, topic/${topic}${all_tags:+, ${all_tags}}]
participants: [user, claude]
links:
  - "[[Claude Conversations Index]]"
  - "[[Daily/${date}]]"
  - "[[Weekly/${week}]]"
  - "[[Monthly/${month}]]"
  - "[[Projects/${project}]]"
  - "[[Topics/${topic}]]"
aliases:
  - "${session_id}"
  - "Claude-${session_id:0:8}"
---

# 💬 ${first_message:0:80}...

**会话ID**: \`${session_id}\`
**项目**: [[Projects/${project}|${project}]]
**话题**: [[Topics/${topic}|${topic}]]
**时间**: ${date} ${time}
**对话时长**: $(calculate_duration "$file")

---

EOF

    # 添加对话内容
    add_conversation_content "$file" "$md_file"

    # 添加元数据
    add_conversation_metadata "$file" "$md_file" "$session_id" "$date" "$week" "$month" "$project" "$topic"

    # 更新索引
    update_all_indices "$session_id" "$date" "$week" "$month" "$project" "$topic" "$md_file" "$first_message"

    echo "✅ 完成: $(basename "$md_file")"
    echo ""
}

# 计算对话时长
calculate_duration() {
    local file="$1"

    # 使用jq计算持续时间，处理ISO时间戳和数字时间戳
    local duration=$(jq -r '
        [select(.timestamp) | .timestamp] |
        if length > 0 then
            map(
                if type == "string" then
                    fromdateiso8601? // (split(".")[0] + "Z" | fromdateiso8601?) // 0
                else
                    . / 1000  # 假设是毫秒时间戳
                end
            ) |
            (max - min) | floor
        else
            empty
        end
    ' "$file" 2>/dev/null)

    if [ -n "$duration" ] && [ "$duration" -gt 0 ]; then
        local minutes=$(( duration / 60 ))
        local seconds=$(( duration % 60 ))

        if [ $minutes -eq 0 ]; then
            echo "${seconds}秒"
        else
            echo "${minutes}分${seconds}秒"
        fi
    else
        echo "未知"
    fi
}

# 添加对话内容
add_conversation_content() {
    local file="$1"
    local md_file="$2"

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
            "\n## 👤 用户\n"
        else
            "\n## 🤖 Claude\n"
        end +
        "> *" + (.timestamp|strftime("%H:%M:%S")) + "*\n\n" +
        (.message.content[0].text? // .message.content[0].thinking? // "") + "\n\n" +
        "---"
    ' "$file" >> "$md_file" 2>/dev/null
}

# 添加会话元数据
add_conversation_metadata() {
    local file="$1"
    local md_file="$2"
    local session_id="$3"
    local date="$4"
    local week="$5"
    local month="$6"
    local project="$7"
    local topic="$8"

    cat >> "$md_file" << EOF

## 📊 会话统计

### 基本信息
- **会话ID**: \`${session_id}\`
- **日期**: [[Daily/${date}|${date}]]
- **周次**: [[Weekly/${week}|${week}]]
- **月份**: [[Monthly/${month}|${month}]]
- **项目**: [[Projects/${project}|${project}]]
- **话题**: [[Topics/${topic}|${topic}]]

### 消息统计
\`\`\`dataviewjs
const sessionId = "${session_id}";
const pages = dv.pages('#claude/conversation')
    .filter(p => p.session_id === sessionId);

if (pages.length > 0) {
    const page = pages[0];
    dv.paragraph(\`对话时长: \${page.duration || "未知"}\`);
    dv.paragraph(\`创建时间: \${page.datetime}\`);
}
\`\`\`

### 相关对话
\`\`\`dataview
TABLE WITHOUT ID
  file.link AS "相关对话",
  date AS "日期",
  topic AS "话题"
FROM #claude/conversation
WHERE project = "${project}" OR topic = "${topic}"
  AND session_id != "${session_id}"
SORT date DESC
LIMIT 5
\`\`\`

## 🔗 反向链接
> 本笔记被以下文件引用：
\`\`\`dataview
LIST FROM outgoing([[${md_file#$EXPORT_BASE/}]])
\`\`\`

---

> 本文件由 Claude Chat Exporter 自动生成
> 生成时间: \`$(date "+%Y-%m-%d %H:%M:%S")\`
EOF
}

# 更新所有索引文件
update_all_indices() {
    local session_id="$1"
    local date="$2"
    local week="$3"
    local month="$4"
    local project="$5"
    local topic="$6"
    local md_file="$7"
    local title="$8"
    local rel_path="${md_file#$EXPORT_BASE/}"

    # 更新日期索引
    update_daily_index "$date" "$rel_path" "$title" "$session_id"

    # 更新周索引
    update_weekly_index "$week" "$rel_path" "$title" "$date"

    # 更新月索引
    update_monthly_index "$month" "$rel_path" "$title" "$date"

    # 更新项目索引
    update_project_index "$project" "$rel_path" "$title" "$date"

    # 更新话题索引
    update_topic_index "$topic" "$rel_path" "$title" "$date"

    # 更新总索引
    update_main_index "$rel_path" "$title" "$date" "$project" "$topic"
}

# 更新日期索引
update_daily_index() {
    local date="$1"
    local rel_path="$2"
    local title="$3"
    local session_id="$4"
    local index_file="$EXPORT_BASE/Daily/${date}.md"

    if [ ! -f "$index_file" ]; then
        cat > "$index_file" << EOF
---
date: ${date}
title: "${date} 的对话"
tags: [claude/daily, date/${date}]
calendar: true
---
# ${date} 的对话

## 📅 日期信息
**日期**: ${date}
**星期**: $(date -d "$date" "+%A" 2>/dev/null || echo "未知")

## 💬 今日对话

EOF
    fi

    # 添加对话条目（如果不存在）
    if ! grep -q "\[\[${rel_path%.md}\]\]" "$index_file"; then
        echo "- [[${rel_path%.md}|${title:0:50}]] (\`${session_id:0:8}\`)" >> "$index_file"
    fi
}

# 更新周索引
update_weekly_index() {
    local week="$1"
    local rel_path="$2"
    local title="$3"
    local date="$4"
    local index_file="$EXPORT_BASE/Weekly/${week}.md"

    if [ ! -f "$index_file" ]; then
        cat > "$index_file" << EOF
---
week: "${week}"
title: "第 ${week#*-W} 周对话"
tags: [claude/weekly, week/${week}]
---
# 第 ${week#*-W} 周对话 (${week%%-W*})

## 📅 本周日期范围
**开始**: $(date -d "$date -$(date -d "$date" +%u) days +1 day" "+%Y-%m-%d" 2>/dev/null || echo "未知")
**结束**: $(date -d "$date +$(expr 7 - $(date -d "$date" +%u)) days" "+%Y-%m-%d" 2>/dev/null || echo "未知")

## 💬 本周对话

EOF
    fi

    if ! grep -q "\[\[${rel_path%.md}\]\]" "$index_file"; then
        echo "- [[${rel_path%.md}|${date} - ${title:0:50}]]" >> "$index_file"
    fi
}

# 更新月索引
update_monthly_index() {
    local month="$1"
    local rel_path="$2"
    local title="$3"
    local date="$4"
    local index_file="$EXPORT_BASE/Monthly/${month}.md"

    if [ ! -f "$index_file" ]; then
        local year_month=$(echo "$month" | sed 's/-/\//')
        cat > "$index_file" << EOF
---
month: "${month}"
title: "${month} 月对话"
tags: [claude/monthly, month/${month}]
---
# ${month} 月对话

## 📅 月份信息
**月份**: ${month}
**天数**: $(cal $(date -d "$date" "+%m %Y" 2>/dev/null) 2>/dev/null | awk 'NF {DAYS = $NF}; END {print DAYS}' || echo "未知")

## 💬 本月对话

EOF
    fi

    if ! grep -q "\[\[${rel_path%.md}\]\]" "$index_file"; then
        echo "- [[${rel_path%.md}|${date} - ${title:0:50}]]" >> "$index_file"
    fi
}

# 更新项目索引
update_project_index() {
    local project="$1"
    local rel_path="$2"
    local title="$3"
    local date="$4"
    local index_file="$EXPORT_BASE/Projects/${project}.md"

    if [ ! -f "$index_file" ]; then
        cat > "$index_file" << EOF
---
project: "${project}"
title: "项目 ${project} 的对话"
tags: [claude/project, project/${project}]
---
# 项目 ${project}

## 📁 项目信息
**项目名称**: ${project}
**对话数量**: 1

## 💬 相关对话

EOF
    fi

    if ! grep -q "\[\[${rel_path%.md}\]\]" "$index_file"; then
        echo "- [[${rel_path%.md}|${date} - ${title:0:50}]]" >> "$index_file"

        # 更新对话数量
        local count=$(grep -c "^-\s*\[\[" "$index_file")
        sed -i '' "s/对话数量:.*/对话数量: ${count}/" "$index_file" 2>/dev/null || \
        sed -i "s/对话数量:.*/对话数量: ${count}/" "$index_file"
    fi
}

# 更新话题索引
update_topic_index() {
    local topic="$1"
    local rel_path="$2"
    local title="$3"
    local date="$4"
    local index_file="$EXPORT_BASE/Topics/${topic}.md"

    if [ ! -f "$index_file" ]; then
        cat > "$index_file" << EOF
---
topic: "${topic}"
title: "话题 ${topic} 的对话"
tags: [claude/topic, topic/${topic}]
---
# 话题 ${topic}

## 🏷️ 话题信息
**话题名称**: ${topic}
**相关对话**: 1

## 💬 相关对话

EOF
    fi

    if ! grep -q "\[\[${rel_path%.md}\]\]" "$index_file"; then
        echo "- [[${rel_path%.md}|${date} - ${title:0:50}]]" >> "$index_file"

        # 更新对话数量
        local count=$(grep -c "^-\s*\[\[" "$index_file")
        sed -i '' "s/相关对话:.*/相关对话: ${count}/" "$index_file" 2>/dev/null || \
        sed -i "s/相关对话:.*/相关对话: ${count}/" "$index_file"
    fi
}

# 更新主索引
update_main_index() {
    local rel_path="$1"
    local title="$2"
    local date="$3"
    local project="$4"
    local topic="$5"
    local index_file="$EXPORT_BASE/Claude Conversations Index.md"

    if [ ! -f "$index_file" ]; then
        create_main_index
    fi

    # 在主索引中添加条目（如果不存在）
    if ! grep -q "\[\[${rel_path%.md}\]\]" "$index_file"; then
        local entry="- [[${rel_path%.md}|${date} - ${project} - ${topic} - ${title:0:30}]]"
        # 插入到"## 所有对话"部分之后
        if grep -q "## 所有对话" "$index_file"; then
            awk -v entry="$entry" '
                /## 所有对话/ {print; getline; print entry; print; next}
                1
            ' "$index_file" > "$index_file.tmp" && mv "$index_file.tmp" "$index_file"
        else
            echo "$entry" >> "$index_file"
        fi
    fi
}

# 创建主索引
create_main_index() {
    cat > "$EXPORT_BASE/Claude Conversations Index.md" << EOF
---
title: Claude 对话索引
tags: [claude/index, MOC]
type: index
---
# Claude 对话总索引

## 🔍 快速导航

### 按时间
- [[Daily/最近7天|最近7天]]
- [[Weekly/最近4周|最近4周]]
- [[Monthly/最近3个月|最近3个月]]

### 按分类
- [[Projects/所有项目|所有项目]]
- [[Topics/所有话题|所有话题]]

## 📊 统计概览

\`\`\`dataviewjs
const pages = dv.pages('#claude/conversation');

// 基础统计
dv.paragraph(\`**总对话数**: \${pages.length}\`);

// 按项目统计
const byProject = pages.groupBy(p => p.project);
dv.paragraph(\`**项目数量**: \${byProject.length}\`);

// 按话题统计
const byTopic = pages.groupBy(p => p.topic);
dv.paragraph(\`**话题数量**: \${byTopic.length}\`);

// 时间分布
const byMonth = pages.groupBy(p => p.month);
dv.paragraph(\`**月份分布**: \${byMonth.length} 个月份\`);
\`\`\`

## 📈 数据可视化

### 活跃度统计
\`\`\`dataviewjs
const pages = dv.pages('#claude/conversation');

// 按月统计
const monthlyData = pages.groupBy(p => p.month)
    .map(g => ({month: g.key, count: g.rows.length}))
    .sort(g => g.month);

dv.table(["月份", "对话数量"], monthlyData.map(g => [g.month, g.count]));
\`\`\`

### 热门话题
\`\`\`dataviewjs
const pages = dv.pages('#claude/conversation');

const topicData = pages.groupBy(p => p.topic)
    .map(g => ({topic: g.key, count: g.rows.length}))
    .sort(g => -g.count)
    .slice(0, 10);

dv.table(["话题", "对话数量"], topicData.map(g => [\`[[Topics/\${g.topic}|\${g.topic}]]\`, g.count]));
\`\`\`

## 💬 所有对话

<!-- 对话列表将自动添加 -->

---

> 本索引由 Claude Chat Exporter 自动生成
> 最后更新: \`$(date "+%Y-%m-%d %H:%M:%S")\`
EOF
}

# 导出最新对话
export_recent() {
    local count=${1:-10}
    echo "📤 导出最新 $count 个对话..."
    echo ""

    local files=$(find "$HOME/.claude/projects" -name "*.jsonl" -exec ls -t {} + 2>/dev/null | head -$count)
    local total=$(echo "$files" | wc -l)

    if [ "$total" -eq 0 ]; then
        echo "❌ 未找到对话文件"
        return
    fi

    echo "找到 $total 个对话"
    echo ""

    local counter=0
    echo "$files" | while read file; do
        counter=$((counter + 1))
        echo "[$counter/$total]"
        generate_conversation "$file"
    done
}

# 导出指定日期范围的对话
export_date_range() {
    local start_date="$1"
    local end_date="$2"

    echo "📅 导出日期范围: $start_date 至 $end_date"
    echo ""

    local files=$(find "$HOME/.claude/projects" -name "*.jsonl" -newermt "${start_date} 00:00:00" ! -newermt "${end_date} 23:59:59" 2>/dev/null)
    local total=$(echo "$files" | wc -l)

    if [ "$total" -eq 0 ]; then
        echo "❌ 未找到指定日期范围的对话"
        return
    fi

    echo "找到 $total 个对话"
    echo ""

    local counter=0
    echo "$files" | while read file; do
        counter=$((counter + 1))
        echo "[$counter/$total]"
        generate_conversation "$file"
    done
}

# 更新所有索引
update_indices_only() {
    echo "🔄 更新所有索引文件..."

    # 重建主索引
    create_main_index

    # 重新扫描所有对话文件
    find "$EXPORT_BASE/Conversations" -name "*.md" | while read md_file; do
        local content=$(head -20 "$md_file")
        local session_id=$(echo "$content" | grep "session_id:" | head -1 | sed 's/.*: //' | tr -d '[:space:]')
        local date=$(echo "$content" | grep "^date:" | head -1 | sed 's/.*: //' | tr -d '[:space:]')
        local topic=$(echo "$content" | grep "^topic:" | head -1 | sed 's/.*: //' | tr -d '[:space:]' | tr -d '"')
        local project=$(echo "$content" | grep "^project:" | head -1 | sed 's/.*: //' | tr -d '[:space:]' | tr -d '"')
        local title=$(head -10 "$md_file" | grep "^# " | head -1 | sed 's/^# //')

        if [ -n "$session_id" ] && [ -n "$date" ]; then
            local week=$(date -d "$date" "+%Y-W%W" 2>/dev/null || echo "")
            local month=$(date -d "$date" "+%Y-%m" 2>/dev/null || echo "")

            if [ -n "$week" ] && [ -n "$month" ]; then
                update_all_indices "$session_id" "$date" "$week" "$month" "$project" "$topic" "$md_file" "$title"
            fi
        fi
    done

    echo "✅ 索引更新完成"
}

# 主菜单
main_menu() {
    while true; do
        echo ""
        echo "=== Claude 双链笔记导出工具 ==="
        echo ""
        echo "1. 导出最新对话"
        echo "2. 导出今天的对话"
        echo "3. 导出日期范围的对话"
        echo "4. 导出所有对话（谨慎！）"
        echo "5. 仅更新索引"
        echo "6. 查看统计信息"
        echo "7. 退出"
        echo ""
        read -p "请选择 (1-7): " choice

        case $choice in
            1)
                read -p "导出数量 (默认: 10): " count
                count=${count:-10}
                export_recent "$count"
                ;;
            2)
                today=$(date "+%Y-%m-%d")
                export_date_range "$today" "$today"
                ;;
            3)
                read -p "开始日期 (YYYY-MM-DD): " start_date
                read -p "结束日期 (YYYY-MM-DD，默认今天): " end_date
                end_date=${end_date:-$(date "+%Y-%m-%d")}
                if [[ "$start_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$end_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                    export_date_range "$start_date" "$end_date"
                else
                    echo "❌ 日期格式错误"
                fi
                ;;
            4)
                echo "⚠️  警告：这将导出所有对话，可能会创建大量文件"
                read -p "确认导出所有对话？(y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    find "$HOME/.claude/projects" -name "*.jsonl" | while read file; do
                        generate_conversation "$file"
                    done
                fi
                ;;
            5)
                update_indices_only
                ;;
            6)
                echo "📊 统计信息："
                echo "导出目录: $EXPORT_BASE"
                echo "对话文件: $(find "$EXPORT_BASE/Conversations" -name "*.md" 2>/dev/null | wc -l)"
                echo "索引文件: $(find "$EXPORT_BASE" -name "*.md" 2>/dev/null | wc -l)"
                echo "占用空间: $(du -sh "$EXPORT_BASE" 2>/dev/null | cut -f1)"
                echo ""
                echo "最新对话："
                find "$EXPORT_BASE/Conversations" -name "*.md" -exec ls -lt {} + 2>/dev/null | head -5 | \
                    awk '{print "  " $6" "$7" "$8": "$9}'
                ;;
            7)
                echo "👋 再见！"
                exit 0
                ;;
            *)
                echo "❌ 无效选择"
                ;;
        esac
    done
}

# 主函数
main() {
    echo "🧠 Claude 双链笔记导出工具"
    echo "=============================="

    # 检查依赖
    check_dependencies

    # 初始化目录
    init_directories

    # 显示主菜单
    main_menu
}

# 处理命令行参数
if [ $# -gt 0 ]; then
    case $1 in
        "--recent"|"-r")
            count=${2:-10}
            check_dependencies
            init_directories
            export_recent "$count"
            exit 0
            ;;
        "--date"|"-d")
            date=${2:-$(date "+%Y-%m-%d")}
            check_dependencies
            init_directories
            export_date_range "$date" "$date"
            exit 0
            ;;
        "--range"|"-R")
            start=${2:-$(date "+%Y-%m-%d")}
            end=${3:-$(date "+%Y-%m-%d")}
            check_dependencies
            init_directories
            export_date_range "$start" "$end"
            exit 0
            ;;
        "--update"|"-u")
            check_dependencies
            init_directories
            update_indices_only
            exit 0
            ;;
        "--help"|"-h")
            echo "使用说明:"
            echo "  $0                    # 交互模式"
            echo "  $0 --recent [N]      # 导出最新N个对话"
            echo "  $0 --date [YYYY-MM-DD] # 导出指定日期对话"
            echo "  $0 --range START END # 导出日期范围对话"
            echo "  $0 --update          # 仅更新索引"
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