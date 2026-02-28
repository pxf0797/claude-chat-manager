#!/bin/bash
# chat-monitor.sh - 监控新对话并自动导出

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBSIDIAN_VAULT="${CLAUDE_OBSIDIAN_VAULT:-$HOME/Obsidian}"
EXPORT_SCRIPT="$SCRIPT_DIR/../export/export-enhanced.sh"
LAST_CHECK_FILE="$HOME/.claude-chat-last-check"
LOG_FILE="$HOME/.claude-chat-monitor.log"
STATE_FILE="$HOME/.claude-chat-monitor.state"
CHECK_INTERVAL=300  # 默认检查间隔（秒）

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=""

    case $level in
        "INFO") color="$BLUE" ;;
        "SUCCESS") color="$GREEN" ;;
        "WARNING") color="$YELLOW" ;;
        "ERROR") color="$RED" ;;
        *) color="$NC" ;;
    esac

    echo -e "${color}[$timestamp] [$level] $message${NC}"
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# 检查配置
check_config() {
    if [ ! -d "$OBSIDIAN_VAULT" ]; then
        log "ERROR" "未找到Obsidian仓库: $OBSIDIAN_VAULT"
        log "INFO" "请设置环境变量: export CLAUDE_OBSIDIAN_VAULT=/path/to/your/obsidian"
        return 1
    fi

    if [ ! -f "$EXPORT_SCRIPT" ]; then
        log "ERROR" "未找到导出脚本: $EXPORT_SCRIPT"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        log "ERROR" "需要安装 jq 工具"
        return 1
    fi

    log "INFO" "配置检查通过"
    log "INFO" "Obsidian仓库: $OBSIDIAN_VAULT"
    log "INFO" "导出脚本: $EXPORT_SCRIPT"
    log "INFO" "日志文件: $LOG_FILE"
    return 0
}

# 初始化
initialize() {
    log "INFO" "初始化监控器..."

    # 创建必要的文件
    mkdir -p "$(dirname "$LAST_CHECK_FILE")"
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$STATE_FILE")"

    # 初始化最后检查时间（如果没有）
    if [ ! -f "$LAST_CHECK_FILE" ]; then
        echo "0" > "$LAST_CHECK_FILE"
        log "INFO" "初始化最后检查时间"
    fi

    # 初始化状态文件
    if [ ! -f "$STATE_FILE" ]; then
        cat > "$STATE_FILE" << EOF
{
  "last_check": $(cat "$LAST_CHECK_FILE"),
  "total_exports": 0,
  "last_export": 0,
  "errors": 0
}
EOF
        log "INFO" "初始化状态文件"
    fi

    log "SUCCESS" "监控器初始化完成"
}

# 更新状态
update_state() {
    local key="$1"
    local value="$2"

    if [ -f "$STATE_FILE" ]; then
        local temp_file="${STATE_FILE}.tmp"
        jq ".${key} = ${value}" "$STATE_FILE" > "$temp_file" && mv "$temp_file" "$STATE_FILE" 2>/dev/null
    fi
}

# 获取状态
get_state() {
    local key="$1"
    if [ -f "$STATE_FILE" ]; then
        jq -r ".${key}" "$STATE_FILE" 2>/dev/null
    fi
}

# 导出新对话
export_new_chats() {
    local last_check=$(cat "$LAST_CHECK_FILE" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local export_count=0

    log "INFO" "检查新对话 (上次检查: $(date -r "$last_check" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "从未"))"

    # 查找上次检查后修改的JSONL文件
    local new_files=$(find "$HOME/.claude/projects" -name "*.jsonl" -newermt "@$last_check" 2>/dev/null)

    if [ -z "$new_files" ]; then
        log "INFO" "未发现新对话"
        echo "$current_time" > "$LAST_CHECK_FILE"
        update_state "last_check" "$current_time"
        return 0
    fi

    local file_count=$(echo "$new_files" | wc -l | tr -d ' ')
    log "INFO" "发现 $file_count 个新对话"

    # 导出每个新对话
    echo "$new_files" | while read file; do
        local session_id=$(basename "$file" .jsonl)
        local file_time=$(date -r "$file" '+%Y-%m-%d %H:%M:%S')

        log "INFO" "导出会话: $session_id ($file_time)"

        # 执行导出
        if bash "$EXPORT_SCRIPT" --file "$file" 2>/dev/null; then
            log "SUCCESS" "导出成功: $session_id"
            export_count=$((export_count + 1))
            update_state "total_exports" "$(($(get_state "total_exports") + 1))"
        else
            log "ERROR" "导出失败: $session_id"
            update_state "errors" "$(($(get_state "errors") + 1))"
        fi
    done

    # 更新最后检查时间
    echo "$current_time" > "$LAST_CHECK_FILE"
    update_state "last_check" "$current_time"
    update_state "last_export" "$current_time"

    if [ $export_count -gt 0 ]; then
        log "SUCCESS" "成功导出 $export_count 个新对话"

        # 发送系统通知（macOS）
        if [[ "$OSTYPE" == "darwin"* ]]; then
            osascript -e "display notification \"成功导出 ${export_count} 个Claude对话到Obsidian\" with title \"Claude Chat Monitor\"" 2>/dev/null || true
        fi
    fi

    return $export_count
}

# 显示状态
show_status() {
    log "INFO" "=== 监控器状态 ==="

    if [ ! -f "$STATE_FILE" ]; then
        log "WARNING" "状态文件不存在"
        return
    fi

    local last_check=$(get_state "last_check")
    local total_exports=$(get_state "total_exports")
    local last_export=$(get_state "last_export")
    local errors=$(get_state "errors")

    echo "最后检查: $(date -d "@$last_check" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "从未")"
    echo "最后导出: $(date -d "@$last_export" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "从未")"
    echo "总导出数: $total_exports"
    echo "错误次数: $errors"
    echo "日志文件: $LOG_FILE"
    echo "状态文件: $STATE_FILE"

    # 显示最近日志
    echo ""
    echo "最近日志："
    tail -5 "$LOG_FILE" 2>/dev/null | while read line; do
        echo "  $line"
    done
}

# 清理旧日志
cleanup_logs() {
    local keep_days=${1:-7}

    log "INFO" "清理 $keep_days 天前的日志"

    if [ -f "$LOG_FILE" ]; then
        # 创建日志备份
        local backup_dir="$(dirname "$LOG_FILE")/backups"
        mkdir -p "$backup_dir"
        local backup_file="$backup_dir/claude-monitor-$(date '+%Y%m%d').log"

        cp "$LOG_FILE" "$backup_file" 2>/dev/null
        log "INFO" "日志备份到: $backup_file"

        # 清理旧备份
        find "$backup_dir" -name "claude-monitor-*.log" -mtime +$keep_days -delete 2>/dev/null
    fi

    # 清理旧状态文件
    find "$(dirname "$STATE_FILE")" -name "*.state.*" -mtime +30 -delete 2>/dev/null

    log "SUCCESS" "清理完成"
}

# 守护进程模式
daemon_mode() {
    local interval=${1:-$CHECK_INTERVAL}

    log "INFO" "启动守护进程模式，检查间隔: ${interval}秒"
    log "INFO" "按 Ctrl+C 停止"

    # 写入PID文件
    echo $$ > "$STATE_FILE.pid"
    trap "cleanup_pid" EXIT INT TERM

    while true; do
        log "INFO" "开始检查周期"
        export_new_chats
        log "INFO" "检查完成，下次检查: $(date -d "+${interval} seconds" '+%H:%M:%S')"
        sleep $interval
    done
}

# 清理PID文件
cleanup_pid() {
    if [ -f "$STATE_FILE.pid" ]; then
        rm -f "$STATE_FILE.pid"
        log "INFO" "清理PID文件"
    fi
    log "INFO" "守护进程停止"
    exit 0
}

# 单次检查模式
once_mode() {
    log "INFO" "执行单次检查"
    export_new_chats
    local result=$?
    log "INFO" "单次检查完成，导出 $result 个对话"
    return $result
}

# 查看日志
view_logs() {
    local lines=${1:-50}

    log "INFO" "显示最近 $lines 行日志"

    if [ -f "$LOG_FILE" ]; then
        tail -n $lines "$LOG_FILE"
    else
        log "WARNING" "日志文件不存在"
    fi
}

# 安装系统服务（macOS LaunchAgent）
install_service() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log "ERROR" "仅支持macOS系统"
        return 1
    fi

    local service_name="com.$(whoami).claudechatmonitor"
    local service_file="$HOME/Library/LaunchAgents/${service_name}.plist"
    local script_path="$(realpath "$0")"

    log "INFO" "安装系统服务: $service_name"

    cat > "$service_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${service_name}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${script_path}</string>
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
    <integer>${CHECK_INTERVAL}</integer>
    <key>EnvironmentVariables</key>
    <dict>
        <key>CLAUDE_OBSIDIAN_VAULT</key>
        <string>${OBSIDIAN_VAULT}</string>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF

    # 加载服务
    launchctl load -w "$service_file" 2>/dev/null

    if [ $? -eq 0 ]; then
        log "SUCCESS" "服务安装成功: $service_file"
        log "INFO" "启动服务: launchctl start $service_name"
        log "INFO" "查看状态: launchctl list | grep $service_name"
        return 0
    else
        log "ERROR" "服务安装失败"
        return 1
    fi
}

# 卸载系统服务
uninstall_service() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log "ERROR" "仅支持macOS系统"
        return 1
    fi

    local service_name="com.$(whoami).claudechatmonitor"
    local service_file="$HOME/Library/LaunchAgents/${service_name}.plist"

    log "INFO" "卸载系统服务: $service_name"

    # 停止并卸载服务
    launchctl stop "$service_name" 2>/dev/null
    launchctl unload -w "$service_file" 2>/dev/null

    # 删除服务文件
    if [ -f "$service_file" ]; then
        rm -f "$service_file"
        log "SUCCESS" "服务卸载成功"
        return 0
    else
        log "WARNING" "服务文件不存在"
        return 1
    fi
}

# 帮助信息
show_help() {
    echo "Claude Chat Monitor - 聊天记录监控器"
    echo ""
    echo "使用说明:"
    echo "  $0 [命令] [参数]"
    echo ""
    echo "命令:"
    echo "  daemon [间隔]   启动守护进程模式（默认间隔: 300秒）"
    echo "  once            执行单次检查"
    echo "  status          显示状态信息"
    echo "  log [行数]      查看日志（默认: 50行）"
    echo "  cleanup [天数]  清理旧日志（默认: 7天）"
    echo "  install         安装系统服务（macOS）"
    echo "  uninstall       卸载系统服务（macOS）"
    echo "  help            显示帮助信息"
    echo ""
    echo "环境变量:"
    echo "  CLAUDE_OBSIDIAN_VAULT  Obsidian仓库路径（默认: \$HOME/Obsidian）"
    echo ""
    echo "示例:"
    echo "  $0 daemon 600      # 每10分钟检查一次"
    echo "  $0 once            # 执行单次检查"
    echo "  $0 status          # 查看状态"
    echo "  $0 log 100         # 查看最近100行日志"
    echo ""
}

# 主函数
main() {
    local command="$1"
    local argument="$2"

    # 检查配置
    if ! check_config; then
        exit 1
    fi

    # 初始化
    initialize

    case $command in
        "daemon")
            daemon_mode "${argument:-$CHECK_INTERVAL}"
            ;;
        "once")
            once_mode
            ;;
        "status")
            show_status
            ;;
        "log")
            view_logs "$argument"
            ;;
        "cleanup")
            cleanup_logs "$argument"
            ;;
        "install")
            install_service
            ;;
        "uninstall")
            uninstall_service
            ;;
        "help"|"")
            show_help
            ;;
        *)
            echo "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"