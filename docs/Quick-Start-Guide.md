# Claude Code 聊天管理工具快速开始指南

## 🚀 一分钟上手

### 第一步：安装工具
```bash
# 确保在正确的目录
cd ~/claude

# 运行安装脚本
chmod +x *.sh
./install-chat-tools.sh install
```

### 第二步：配置环境变量
```bash
# 设置Obsidian仓库路径（修改为你的实际路径）
export CLAUDE_OBSIDIAN_VAULT="$HOME/Obsidian"

# 永久生效（添加到 ~/.zshrc 或 ~/.bashrc）
echo 'export CLAUDE_OBSIDIAN_VAULT="$HOME/Obsidian"' >> ~/.zshrc
source ~/.zshrc
```

### 第三步：测试查看功能
```bash
# 查看最近聊天记录
claude-view

# 或直接运行
./view-chats.sh
```

### 第四步：导出到Obsidian
```bash
# 导出最新5个对话
claude-export --recent 5

# 或使用交互模式
claude-export
```

## 📁 工具概览

### 1. 查看工具
```bash
# 简单查看
claude-view

# 交互式浏览器
claude-explore

# 输出示例：
# === Claude Code 聊天记录查看器 ===
#
# 📋 最近会话列表：
# ----------------------------------------
# 2024-01-15 14:30 | 如何管理claude code的历史聊天记录 | /Users/xfpan/claude
# 2024-01-15 14:25 | 赣州天气 | /Users/xfpan
# ...
```

### 2. 导出工具
```bash
# 基本导出（适合新手）
claude-export --recent 3

# 增强导出（双链笔记）
./export-enhanced.sh --recent 5

# 指定日期导出
claude-export --date 2024-01-15

# 导出单个文件
claude-export --file ~/.claude/projects/-Users-xfpan-claude/xxxxxx.jsonl
```

### 3. 自动化工具
```bash
# 单次检查
claude-monitor once

# 启动守护进程（每5分钟检查）
claude-monitor daemon

# 查看状态
claude-status

# 查看日志
claude-log
```

## 🔧 高级配置

### Obsidian集成配置
1. 确保Obsidian仓库存在
2. 设置正确的仓库路径：
   ```bash
   # 查看当前配置
   echo $CLAUDE_OBSIDIAN_VAULT

   # 修改配置
   export CLAUDE_OBSIDIAN_VAULT="/path/to/your/obsidian/vault"
   ```

### 自定义导出目录
```bash
# 在导出脚本中修改（第8-9行）
EXPORT_DIR="$OBSIDIAN_VAULT/Your-Folder-Name"
```

### 设置自动监控
```bash
# 方法1：使用系统服务（macOS）
claude-monitor install

# 方法2：使用crontab（所有系统）
(crontab -l 2>/dev/null; echo "*/10 * * * * /bin/bash $HOME/claude-chat-tools/chat-monitor.sh once") | crontab -
```

## 🎯 常见场景

### 场景1：每日回顾
```bash
# 导出昨天的所有对话
yesterday=$(date -v-1d "+%Y-%m-%d")
claude-export --date $yesterday

# 在Obsidian中查看
open "$CLAUDE_OBSIDIAN_VAULT/Claude-Chats"
```

### 场景2：项目整理
```bash
# 导出特定项目的所有对话
./view-chats.sh  # 查看项目名称
# 然后手动导出相关文件
```

### 场景3：批量清理
```bash
# 保留最近30天，清理旧记录
find ~/.claude/projects -name "*.jsonl" -mtime +30 -delete

# 清理旧导出文件（保留90天）
find "$CLAUDE_OBSIDIAN_VAULT/Claude-Chats" -name "*.md" -mtime +90 -delete
```

## 📝 实用技巧

### 1. 快速搜索
```bash
# 在所有聊天记录中搜索关键词
grep -r "关键词" ~/.claude/projects/

# 使用交互浏览器搜索
claude-explore
# 然后选择"搜索内容"
```

### 2. 批量处理
```bash
# 导出最近一周的所有对话
for i in {0..6}; do
    date=$(date -v-${i}d "+%Y-%m-%d")
    echo "导出: $date"
    claude-export --date "$date" 2>/dev/null
done
```

### 3. 与Obsidian深度集成
- 使用 `#claude/conversation` 标签筛选所有对话
- 使用 `date/2024-01-15` 标签按日期浏览
- 使用Dataview查询创建动态视图

## 🛠️ 故障排除

### 问题1：找不到jq
```bash
# 安装jq
brew install jq  # macOS
# 或
sudo apt-get install jq  # Ubuntu/Debian
# 或
sudo yum install jq  # CentOS/RHEL
```

### 问题2：Obsidian路径错误
```bash
# 检查路径
ls -la "$CLAUDE_OBSIDIAN_VAULT"

# 如果不存在，创建目录或设置正确路径
export CLAUDE_OBSIDIAN_VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/YourVault"
```

### 问题3：权限问题
```bash
# 添加执行权限
chmod +x ~/claude/*.sh

# 如果使用安装脚本
./install-chat-tools.sh install
```

### 问题4：导出文件为空
```bash
# 检查原始文件
head -5 ~/.claude/projects/-Users-xfpan-claude/最新文件.jsonl

# 检查jq是否正常工作
echo '{"test": "value"}' | jq '.test'
```

## 🔄 工作流程示例

### 每日工作流
```bash
# 早上：检查昨晚的对话
claude-export --date $(date "+%Y-%m-%d")

# 工作中：实时监控
claude-monitor daemon &

# 晚上：整理总结
claude-view | grep "今天"
```

### 每周回顾
```bash
# 导出本周所有对话
for i in {0..6}; do
    date=$(date -v-${i}d "+%Y-%m-%d")
    claude-export --date "$date" 2>/dev/null
done

# 生成周报
./export-enhanced.sh --update
```

## 📚 扩展学习

### 深入学习
1. **查看详细文档**：
   ```bash
   open ./Claude-Code-Chat-Management-Scheme.md
   ```

2. **探索脚本功能**：
   ```bash
   ./export-enhanced.sh --help
   ./chat-monitor.sh help
   ```

3. **自定义配置**：
   - 修改 `export-enhanced.sh` 中的导出模板
   - 调整 `chat-monitor.sh` 中的检查间隔
   - 创建自己的工具脚本

### 社区资源
- [Obsidian 官方文档](https://help.obsidian.md/)
- [Dataview 插件指南](https://blacksmithgu.github.io/obsidian-dataview/)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)

## 🎉 开始使用！

### 第一步：运行测试
```bash
./test-chat-tools.sh
```

### 第二步：初次导出
```bash
# 先设置Obsidian路径
export CLAUDE_OBSIDIAN_VAULT="$HOME/Obsidian"

# 导出几个对话试试
claude-export --recent 2

# 在Obsidian中查看结果
open "$CLAUDE_OBSIDIAN_VAULT/Claude-Chats"
```

### 第三步：设置自动化
```bash
# 添加到开机启动
claude-monitor install

# 或添加到crontab
(crontab -l; echo "0 9 * * * /bin/bash $HOME/claude-chat-tools/chat-monitor.sh once") | crontab -
```

---

**提示**：如果遇到问题，查看日志文件：
```bash
tail -f ~/.claude-chat-monitor.log
```

祝您使用愉快！ 🎯