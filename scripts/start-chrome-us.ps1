# start-chrome-us.ps1 — 以美国地区启动 Chrome，确保 Gemini 工具栏正常显示
#
# 用法:
#   .\start-chrome-us.ps1          # 在 PowerShell 中执行
#
# 原理: Chrome 137+ 会根据出口 IP 判定地区，variations_country 为 cn 时
#       隐藏 Gemini 按钮。本脚本通过启动参数 --variations-override-country=us
#       在进程层面覆盖地区判定，比修改配置文件更可靠（不会被回写）。

# 退出当前 Chrome（避免已有进程忽略启动参数）
$chromeProc = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
if ($chromeProc) {
    Write-Host "正在退出 Chrome..."
    Stop-Process -Name "chrome" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# 确认 Chrome 已完全退出
if (Get-Process -Name "chrome" -ErrorAction SilentlyContinue) {
    Write-Host "Chrome 未响应退出请求，等待..."
    Start-Sleep -Seconds 3
    if (Get-Process -Name "chrome" -ErrorAction SilentlyContinue) {
        Write-Host "警告：Chrome 仍未退出，将强制关闭（未保存的数据可能丢失）..."
        Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
}

# 检查 Chrome 是否安装
$chromePath = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chromePath)) {
    $chromePath = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
}
if (-not (Test-Path $chromePath)) {
    $chromePath = "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
}
if (-not (Test-Path $chromePath)) {
    Write-Host "错误：未找到 Google Chrome，请从 https://google.com/chrome 安装。" -ForegroundColor Red
    exit 1
}

# 带地区覆盖参数启动
Start-Process $chromePath -ArgumentList "--variations-override-country=us"

Write-Host "Chrome 已以美国地区启动，Gemini 工具栏应正常显示。"
Write-Host "若仍未出现，请检查："
Write-Host "  1. 浏览器语言是否已设为 English (United States)"
Write-Host "  2. chrome://flags 中 glic 开关是否已启用"
Write-Host '  3. 设置中"在浏览器顶部显示 Gemini"是否已开启'
