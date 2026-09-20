#!/bin/bash
set -euo pipefail

# start-chrome-us.sh — 以美国地区启动 Chrome，确保 Gemini 工具栏正常显示
#
# 用法:
#   bash start-chrome-us.sh          # 终端执行
#   chmod +x start-chrome-us.sh && ./start-chrome-us.sh  # 直接执行
#
# 原理: Chrome 137+ 会根据出口 IP 判定地区，variations_country 为 cn 时
#       隐藏 Gemini 按钮。本脚本通过启动参数 --variations-override-country=us
#       在进程层面覆盖地区判定，比修改配置文件更可靠（不会被回写）。

# 检查 Chrome 是否安装
if [ ! -d "/Applications/Google Chrome.app" ]; then
    echo "错误：未找到 Google Chrome，请从 https://google.com/chrome 安装。"
    exit 1
fi

# 退出当前 Chrome（避免已有进程忽略启动参数）
echo "正在退出 Chrome..."
osascript -e 'quit app "Google Chrome"' 2>/dev/null || true
sleep 2

# 确认 Chrome 已完全退出
if pgrep -x "Google Chrome" >/dev/null 2>&1; then
    echo "Chrome 未响应退出请求，等待..."
    sleep 3
    if pgrep -x "Google Chrome" >/dev/null 2>&1; then
        echo "警告：Chrome 仍未退出，将强制关闭（未保存的数据可能丢失）..."
        killall "Google Chrome" 2>/dev/null || true
        sleep 1
    fi
fi

# 带地区覆盖参数启动
open -a "Google Chrome" --args --variations-override-country=us

echo "Chrome 已以美国地区启动，Gemini 工具栏应正常显示。"
echo "若仍未出现，请检查："
echo "  1. 浏览器语言是否已设为 English (United States)"
echo "  2. chrome://flags 中 glic 开关是否已启用"
echo "  3. 设置中"在浏览器顶部显示 Gemini"是否已开启"
