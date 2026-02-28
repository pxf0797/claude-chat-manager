# Claude Code Chat Manager

一套完整的Claude Code聊天记录管理工具，支持查看原始聊天记录和自动导出到Obsidian等双链笔记工具。

## ✨ 功能特性

### 🔍 查看功能
- **快速查看**：列出最近会话，显示基本信息
- **交互浏览**：交互式浏览器，支持搜索和筛选
- **多维度查看**：按项目、日期、内容搜索聊天记录

### 📤 导出功能
- **基础导出**：将聊天记录导出为Markdown格式
- **增强导出**：支持双链笔记特性（标签、反向链接、Dataview查询）
- **智能分类**：自动按日期、项目、话题组织文件
- **元数据提取**：自动提取会话ID、时间、话题等元数据

### 🤖 自动化功能
- **实时监控**：监控新对话并自动导出
- **系统服务**：支持macOS LaunchAgent后台运行
- **定期清理**：自动清理旧记录，节省存储空间
- **完整日志**：详细的操作日志和错误追踪

### 🛠️ 工具集
- **一键安装**：自动安装所有工具和依赖
- **Shell集成**：提供命令行别名和快捷命令
- **配置管理**：可配置的导出选项和监控设置

## 📁 文件结构

```
claude-chat-manager/
├── README.md                          # 项目说明
├── CONTRIBUTING.md                    # 贡献指南
├── CHANGELOG.md                       # 更新日志
├── LICENSE                            # MIT许可证
├── .gitignore                         # Git忽略配置
├── scripts/                           # 脚本目录
│   ├── view/                          # 查看功能
│   │   ├── view-chats.sh              # 查看工具
│   │   └── chat-explorer.sh           # 交互式浏览器
│   ├── export/                        # 导出功能
│   │   ├── export-to-obsidian.sh      # 基础导出工具
│   │   └── export-enhanced.sh         # 增强导出工具
│   ├── monitor/                       # 监控功能
│   │   └── chat-monitor.sh            # 自动监控工具
│   └── utils/                         # 工具脚本
│       ├── install-chat-tools.sh      # 安装脚本
│       ├── test-chat-tools.sh         # 测试脚本
│       └── init-repo.sh               # 仓库初始化工具
├── docs/                              # 文档目录
│   ├── Claude-Code-Chat-Management-Scheme.md  # 完整方案文档
│   ├── Quick-Start-Guide.md           # 快速开始指南
│   └── GITHUB_SETUP.md                # GitHub设置指南
├── config/                            # 配置文件模板
│   └── claude-chat-tools.conf.example # 配置示例
├── examples/                          # 示例目录
│   └── basic-usage.sh                 # 基本使用示例
├── templates/                         # 模板目录
│   └── obsidian-export-template.md    # Obsidian导出模板
└── init-repo.sh                       # 仓库初始化脚本（根目录备份）
```

## 🚀 快速开始

### 前提条件
- macOS 或 Linux 系统
- [Claude Code](https://claude.com/claude-code) 已安装
- [jq](https://stedolan.github.io/jq/) 命令行JSON处理器
- [Obsidian](https://obsidian.md/)（可选，用于笔记导出）

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/yourusername/claude-chat-manager.git
   cd claude-chat-manager
   ```

2. **运行安装脚本**
   ```bash
   find scripts -name "*.sh" -exec chmod +x {} \;
   ./scripts/utils/install-chat-tools.sh install
   ```

3. **配置环境变量**
   ```bash
   # 设置你的Obsidian仓库路径
   export CLAUDE_OBSIDIAN_VAULT="$HOME/Obsidian"
   echo 'export CLAUDE_OBSIDIAN_VAULT="$HOME/Obsidian"' >> ~/.zshrc
   source ~/.zshrc
   ```

4. **测试安装**
   ```bash
   ./scripts/utils/test-chat-tools.sh
   ```

## 📖 使用指南

### 查看聊天记录

```bash
# 快速查看最近会话
claude-view

# 启动交互式浏览器
claude-explore

# 查看特定日期的会话
claude-view | grep "2024-01-15"
```

### 导出到Obsidian

```bash
# 导出最新5个对话
claude-export --recent 5

# 导出今天的对话
claude-export --date $(date "+%Y-%m-%d")

# 导出日期范围的对话
claude-export --range 2024-01-01 2024-01-15

# 使用增强导出（推荐）
./scripts/export/export-enhanced.sh --recent 10
```

### 自动监控

```bash
# 单次检查
claude-monitor once

# 启动守护进程（每5分钟检查）
claude-monitor daemon

# 安装为系统服务（macOS）
claude-monitor install

# 查看状态
claude-status

# 查看日志
claude-log 50
```

## 🔧 配置说明

### 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `CLAUDE_OBSIDIAN_VAULT` | `$HOME/Obsidian` | Obsidian仓库路径 |
| `CLAUDE_CHAT_TOOLS_DIR` | `$HOME/claude-chat-tools` | 工具安装目录 |

### 配置文件

安装后会在 `$HOME/claude-chat-tools/config/` 目录生成配置文件：

- `claude-chat-tools.conf` - 主配置文件
- `Claude-Code-Chat-Management-Scheme.md` - 完整方案文档

### 自定义选项

可以通过修改以下文件自定义行为：

1. **导出模板**：修改 `export-enhanced.sh` 中的Frontmatter格式
2. **监控间隔**：修改 `chat-monitor.sh` 中的 `CHECK_INTERVAL`
3. **清理策略**：修改脚本中的 `KEEP_DAYS` 参数

## 🎯 使用场景

### 个人知识管理
- 将技术对话整理为可搜索的知识库
- 记录学习过程和问题解决方案
- 建立个人AI对话档案

### 团队协作
- 分享技术讨论和决策过程
- 建立团队知识库
- 跟踪项目进展和讨论历史

### 内容创作
- 整理创作灵感和素材
- 管理编辑和修订记录
- 建立写作参考库

## 📊 导出效果

### Obsidian中的功能
- **双链笔记**：自动创建话题、项目、日期之间的链接
- **Dataview查询**：动态统计和筛选对话记录
- **标签系统**：按话题、项目、日期自动打标签
- **时间线视图**：按时间顺序浏览对话历史

### 导出文件示例
```markdown
---
id: 3e0c354e-03a6-4080-b199-41b488a1d8d4
type: conversation
date: 2024-01-15
time: 14:48:22
topic: claude-code
tags: [claude/conversation, date/2024-01-15, topic/claude-code]
---

# 💬 如何管理claude code的历史聊天记录

**会话ID**: `3e0c354e-03a6-4080-b199-41b488a1d8d4`
**时间**: 2024-01-15 14:48:22

## 👤 用户
> *14:48:22*

如何管理claude code的历史聊天记录

## 🤖 Claude
> *14:48:30*

我已经为您创建了一个完整的Claude Code聊天记录管理方案...
```

## 🛠️ 开发指南

### 依赖说明
- **jq**: JSON处理，用于解析Claude聊天记录
- **bash**: 脚本运行环境（版本4.0+）
- **系统工具**: find, date, awk, sed, grep等

### 脚本说明

| 脚本文件 | 主要功能 | 依赖 |
|----------|----------|------|
| `view-chats.sh` | 基本查看功能 | jq |
| `chat-explorer.sh` | 交互式浏览器 | jq, 基本Shell工具 |
| `export-to-obsidian.sh` | 基础导出 | jq |
| `export-enhanced.sh` | 增强导出 | jq |
| `chat-monitor.sh` | 自动监控 | jq, 系统服务工具 |
| `install-chat-tools.sh` | 安装管理 | 系统包管理器 |

### 扩展开发

1. **添加新导出格式**
   ```bash
   # 复制 export-enhanced.sh 为 export-custom.sh
   # 修改输出格式和逻辑
   ```

2. **集成其他笔记工具**
   ```bash
   # 修改导出目标路径和格式
   # 支持Logseq、Notion、Roam Research等
   ```

3. **添加Web界面**
   ```bash
   # 基于现有脚本开发Web API
   # 使用Python/Node.js包装Shell脚本
   ```

## 🔍 故障排除

### 常见问题

1. **jq命令未找到**
   ```bash
   # macOS
   brew install jq

   # Ubuntu/Debian
   sudo apt-get install jq

   # CentOS/RHEL
   sudo yum install jq
   ```

2. **权限被拒绝**
   ```bash
   chmod +x *.sh
   sudo chmod +x /usr/local/bin/claude-* 2>/dev/null
   ```

3. **Obsidian路径错误**
   ```bash
   # 检查路径是否存在
   ls -la "$CLAUDE_OBSIDIAN_VAULT"

   # 设置正确路径
   export CLAUDE_OBSIDIAN_VAULT="/path/to/your/obsidian"
   ```

4. **监控服务未启动**
   ```bash
   # 检查服务状态
   launchctl list | grep claude

   # 重新安装服务
   claude-monitor uninstall
   claude-monitor install
   ```

### 调试模式

```bash
# 启用详细日志
export CLAUDE_DEBUG=true

# 查看详细错误信息
./scripts/monitor/chat-monitor.sh once 2>&1 | tee debug.log

# 检查日志文件
tail -f ~/.claude-chat-monitor.log
```

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

### 开发流程
1. Fork本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建Pull Request

### 代码规范
- 使用ShellCheck检查脚本语法
- 添加详细的注释说明
- 遵循现有代码风格
- 更新相关文档

### 测试要求
- 新功能需要添加测试用例
- 确保向后兼容性
- 更新快速开始指南

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [Claude Code](https://claude.com/claude-code) - 优秀的AI编程助手
- [Obsidian](https://obsidian.md/) - 强大的双链笔记工具
- [jq](https://stedolan.github.io/jq/) - 命令行JSON处理器

## 📞 支持与反馈

- **问题报告**: [GitHub Issues](https://github.com/yourusername/claude-chat-manager/issues)
- **功能建议**: [GitHub Discussions](https://github.com/yourusername/claude-chat-manager/discussions)
- **文档改进**: 提交Pull Request

---

**提示**: 详细的使用说明请查看 [Claude-Code-Chat-Management-Scheme.md](Claude-Code-Chat-Management-Scheme.md) 和 [Quick-Start-Guide.md](Quick-Start-Guide.md)。