# Obsidian 导出模板示例
# 可用于自定义导出格式

---
id: {{id}}
type: conversation
date: {{date}}
time: {{time}}
topic: {{topic}}
tags: [claude/conversation, date/{{date}}, topic/{{topic}}]
---

# 💬 {{title}}

**会话ID**: `{{id}}`
**时间**: {{date}} {{time}}
**项目**: {{project}}

## 👤 用户
> *{{time}}*

{{user_message}}

## 🤖 Claude
> *{{claude_time}}*

{{claude_message}}

## 🔗 相关链接
- [[Claude 对话索引]]
- [[话题/{{topic}}]]
- [[日期/{{date}}]]

---
*导出时间: {{export_time}}*