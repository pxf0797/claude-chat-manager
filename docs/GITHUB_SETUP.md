# GitHub 仓库设置指南

本文档说明如何将 Claude Chat Manager 项目设置为 GitHub 仓库。

## 步骤一：本地初始化

### 1. 进入项目目录
```bash
cd /Users/xfpan/claude/claude-chat-manager
```

### 2. 初始化 Git 仓库
```bash
git init
```

### 3. 添加所有文件
```bash
git add .
```

### 4. 提交初始版本
```bash
git commit -m "Initial commit: Claude Chat Manager v1.0"
```

## 步骤二：创建 GitHub 仓库

### 1. 登录 GitHub
访问 [GitHub](https://github.com) 并登录您的账户。

### 2. 创建新仓库
- 点击右上角的 "+" 按钮，选择 "New repository"
- 输入仓库名称，例如 `claude-chat-manager`
- 添加描述（可选）："A complete chat management tool for Claude Code"
- 选择公开（Public）或私有（Private）
- **不要**初始化 README、.gitignore 或 LICENSE（因为我们已经有了）
- 点击 "Create repository"

## 步骤三：连接并推送

### 1. 添加远程仓库
复制 GitHub 提供的命令，类似：
```bash
git remote add origin https://github.com/yourusername/claude-chat-manager.git
```

### 2. 推送到 GitHub
```bash
git push -u origin main
```

如果您的默认分支是 `master` 而不是 `main`：
```bash
git push -u origin master
```

## 步骤四：验证设置

### 1. 检查远程仓库
```bash
git remote -v
```

### 2. 查看提交历史
```bash
git log --oneline
```

### 3. 访问 GitHub 页面
打开浏览器访问您的仓库地址：
```
https://github.com/yourusername/claude-chat-manager
```

## 步骤五：日常开发流程

### 1. 创建新分支
```bash
git checkout -b feature/new-feature
```

### 2. 添加更改
```bash
git add .
git commit -m "Add new feature: ..."
```

### 3. 推送到远程
```bash
git push origin feature/new-feature
```

### 4. 创建 Pull Request
- 在 GitHub 仓库页面点击 "Compare & pull request"
- 填写描述信息
- 等待代码审查和合并

## 配置 GitHub Actions（可选）

### 1. 创建工作流目录
```bash
mkdir -p .github/workflows
```

### 2. 创建测试工作流
创建 `.github/workflows/test.yml`：
```yaml
name: Test

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Setup Shell
      run: |
        sudo apt-get update
        sudo apt-get install -y jq

    - name: Test scripts
      run: |
        chmod +x *.sh
        ./test-chat-tools.sh
```

## 配置 GitHub Pages（可选）

### 1. 启用 GitHub Pages
- 进入仓库设置（Settings）
- 找到 "Pages" 部分
- 选择分支（如 `main` 或 `gh-pages`）
- 选择文件夹（如 `/docs` 或 `/`）

### 2. 创建文档目录
```bash
mkdir docs
cp README.md docs/
# 添加其他文档
```

## 问题排查

### 1. 推送被拒绝
```bash
# 先拉取最新更改
git pull origin main --rebase

# 然后推送
git push origin main
```

### 2. 大型文件警告
如果文件太大无法推送：
```bash
# 检查大文件
git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | awk '/^blob/ {print substr($0,6)}' | sort --numeric-sort --key=2 | tail -10

# 从历史中移除大文件（谨慎操作）
git filter-branch --tree-filter 'rm -f path/to/large/file' HEAD
```

### 3. 权限问题
```bash
# 检查 SSH 密钥
ssh -T git@github.com

# 或使用 HTTPS 凭证缓存
git config --global credential.helper cache
```

## 最佳实践

### 1. 提交规范
- 使用有意义的提交信息
- 遵循约定式提交（Conventional Commits）
- 关联 Issue 编号（如 `fix: #123`）

### 2. 分支管理
- `main`/`master`: 稳定版本
- `develop`: 开发分支
- `feature/*`: 功能分支
- `bugfix/*`: 修复分支

### 3. 版本标签
```bash
# 创建版本标签
git tag -a v1.0.0 -m "Version 1.0.0"

# 推送标签
git push origin v1.0.0
```

## 自动化脚本

创建 `setup-github.sh` 脚本简化流程：

```bash
#!/bin/bash
# setup-github.sh

echo "=== GitHub 仓库设置 ==="

# 初始化仓库
git init
git add .
git commit -m "Initial commit: Claude Chat Manager"

# 设置远程仓库
read -p "请输入 GitHub 仓库 URL: " repo_url
git remote add origin "$repo_url"

# 推送
git push -u origin main

echo "✅ 设置完成！"
```

## 参考链接

- [GitHub 官方文档](https://docs.github.com/)
- [Git 教程](https://git-scm.com/book/)
- [GitHub CLI](https://cli.github.com/)
- [GitHub Actions 文档](https://docs.github.com/actions)