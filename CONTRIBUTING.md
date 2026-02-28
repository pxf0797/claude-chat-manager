# 贡献指南

感谢您考虑为 Claude Chat Manager 贡献代码！本指南将帮助您开始贡献流程。

## 📋 行为准则

请遵守以下行为准则：
- 保持友善和尊重
- 包容不同背景和经验水平的贡献者
- 建设性的批评，专注于改进代码而不是个人
- 尊重不同的观点和经验

## 🚀 开始贡献

### 1. 设置开发环境

```bash
# 克隆仓库
git clone https://github.com/yourusername/claude-chat-manager.git
cd claude-chat-manager

# 安装依赖
./install-chat-tools.sh --dev

# 运行测试
./test-chat-tools.sh
```

### 2. 选择要贡献的内容

- **报告 Bug**：使用 [GitHub Issues](https://github.com/yourusername/claude-chat-manager/issues)
- **功能建议**：先在 Issues 中讨论
- **代码贡献**：遵循下面的流程

## 🔧 开发流程

### 1. 创建分支

```bash
# 从 main 分支创建新分支
git checkout main
git pull origin main
git checkout -b feature/your-feature-name

# 或修复 Bug
git checkout -b fix/issue-number-description
```

### 2. 编写代码

- 遵循现有的代码风格
- 添加适当的注释
- 编写测试用例
- 更新相关文档

### 3. 提交更改

```bash
# 添加更改
git add .

# 提交（遵循约定式提交）
git commit -m "feat: add new export format"
# 或
git commit -m "fix: resolve parsing error in view-chats.sh"
# 或
git commit -m "docs: update installation instructions"
```

### 约定式提交类型：
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式调整（不影响功能）
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建过程或辅助工具更改

### 4. 运行测试

```bash
# 运行所有测试
./test-chat-tools.sh

# 检查 Shell 脚本语法
for script in *.sh; do
    shellcheck "$script"
done

# 测试特定功能
bash -n *.sh  # 语法检查
```

### 5. 推送到远程

```bash
git push origin feature/your-feature-name
```

### 6. 创建 Pull Request

1. 访问 GitHub 仓库页面
2. 点击 "New Pull Request"
3. 选择正确的分支
4. 填写 PR 描述：
   - 解决的问题
   - 更改内容
   - 测试结果
   - 相关 Issue 编号

## 📝 代码规范

### Shell 脚本规范

1. **代码风格**
   ```bash
   # 使用 2 空格缩进
   if [ condition ]; then
     command
   fi

   # 函数定义
   function_name() {
     local var="value"
     command
   }

   # 变量引用
   "${variable}"
   ```

2. **错误处理**
   ```bash
   set -e  # 遇到错误退出
   set -u  # 使用未定义变量时报错

   # 检查命令是否存在
   if ! command -v jq &> /dev/null; then
     echo "Error: jq is required"
     exit 1
   fi
   ```

3. **文档注释**
   ```bash
   #!/bin/bash
   #
   # script-name.sh - Brief description
   #
   # Usage: script-name.sh [options]
   # Options:
   #   -h, --help    Show this help message
   #   -v, --version Show version
   #
   # Description: Detailed description of what the script does.
   #
   # Author: Your Name
   # Date: YYYY-MM-DD
   ```

### 测试要求

1. **新功能必须包含测试**
   ```bash
   # 测试文件示例：test-feature.sh
   #!/bin/bash
   # Test for feature-name

   echo "Testing feature-name..."

   # Test case 1
   if ! ./your-script.sh --test-option; then
     echo "FAIL: Test case 1"
     exit 1
   fi

   echo "PASS: All tests passed"
   ```

2. **测试覆盖率**
   - 测试正常流程
   - 测试错误处理
   - 测试边界情况

### 文档要求

1. **更新 README.md**
   - 新功能的使用说明
   - 配置选项变更
   - 依赖更新

2. **代码注释**
   - 复杂逻辑的说明
   - 函数参数和返回值
   - 重要的算法说明

## 🐛 报告 Bug

### Bug 报告模板

```
## 问题描述
清晰描述问题现象

## 重现步骤
1. 第一步
2. 第二步
3. ...

## 期望行为
描述期望的结果

## 实际行为
描述实际的结果

## 环境信息
- 操作系统：macOS 12.0 / Ubuntu 20.04
- Shell：bash 5.1 / zsh 5.8
- jq 版本：jq-1.6
- Claude Code 版本：2.1.63

## 日志输出
相关的错误日志或输出
```

## 💡 功能建议

### 功能建议模板

```
## 功能描述
详细描述建议的功能

## 使用场景
说明在什么情况下需要使用这个功能

## 实现建议
如果有实现思路，可以在这里描述

## 替代方案
考虑过哪些替代方案

## 相关功能
与现有功能的关联
```

## 🔍 代码审查流程

### 审查者指南
1. **功能性审查**
   - 代码是否实现预期功能？
   - 是否有明显的 Bug？
   - 错误处理是否充分？

2. **代码质量审查**
   - 是否符合代码规范？
   - 是否有重复代码？
   - 命名是否清晰？

3. **测试审查**
   - 是否有足够的测试？
   - 测试是否覆盖所有场景？
   - 测试是否清晰易懂？

4. **文档审查**
   - 是否更新了相关文档？
   - 注释是否清晰？
   - README 是否更新？

### 作者指南
1. 及时回应审查意见
2. 解释设计决策
3. 接受建设性批评
4. 保持 PR 精简（一个 PR 一个功能）

## 📦 发布流程

### 版本号规范
- **主版本号**：不兼容的 API 修改
- **次版本号**: 向下兼容的功能性新增
- **修订号**：向下兼容的问题修正

### 发布步骤
1. 更新版本号
2. 更新 CHANGELOG.md
3. 创建发布分支
4. 运行完整测试
5. 创建 Git 标签
6. 发布到 GitHub

## 🆘 获取帮助

### 讨论渠道
- [GitHub Issues](https://github.com/yourusername/claude-chat-manager/issues)
- [GitHub Discussions](https://github.com/yourusername/claude-chat-manager/discussions)

### 沟通指南
- 描述问题时提供足够的信息
- 保持专业和尊重
- 使用清晰的语言
- 提供复现步骤

## 🙏 致谢

感谢所有贡献者的努力和奉献！您的每一点贡献都让这个项目变得更好。

---

**注意**：提交 Pull Request 即表示您同意按照本项目的许可证（MIT）授权您的贡献。