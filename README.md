# Chrome Gemini Fix

> 修复 Chrome 升级后 Gemini 工具栏 / 侧边栏图标消失问题

## 这是什么

Chrome 137+ 正式集成了 Gemini in Chrome 功能（地址栏右侧的 AI 按钮），但在中国大陆地区，Chrome 会根据出口 IP 判定地区为 `cn`，直接隐藏 Gemini 按钮和设置中的 AI 入口。升级浏览器版本后，部分地区校准逻辑变化，即使之前能用的按钮也会消失。

本项目提供了一套完整的诊断流程和修复脚本，覆盖 macOS 和 Windows 双平台。

## 快速修复

### 方案一：启动脚本（推荐）

```bash
# 克隆仓库
git clone https://github.com/JH90iOS/chrome-gemini-fix.git
cd chrome-gemini-fix

# macOS
bash scripts/start-chrome-us.sh

# Windows (PowerShell)
.\scripts\start-chrome-us.ps1
```

### 方案二：手动命令

```bash
# macOS
open -a "Google Chrome" --args --variations-override-country=us

# Windows (PowerShell)
Start-Process "chrome.exe" -ArgumentList "--variations-override-country=us"
```

> 启动参数 `--variations-override-country=us` 在进程层面覆盖地区判定，比修改配置文件更可靠（不会被 Chrome 自动回写）。

### 方案三：修改配置文件

如果不想每次都带启动参数，可以修改 Chrome 的 `Local State` 配置文件：

```bash
# macOS（注意 BSD sed 必须用 -i ''）
# 先完全退出 Chrome，再执行：
cp "$HOME/Library/Application Support/Google/Chrome/Local State" \
   "$HOME/Library/Application Support/Google/Chrome/Local State.bak"
sed -i '' 's/"variations_country":"cn"/"variations_country":"us"/' \
   "$HOME/Library/Application Support/Google/Chrome/Local State"
```

```powershell
# Windows (PowerShell)
Copy-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State" `
          "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State.bak"
(Get-Content "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State") `
  -replace '"variations_country":"cn"', '"variations_country":"us"' `
  | Set-Content "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
```

> 如果修改后被 Chrome 自动改回 `cn`，需将 `clientservices.googleapis.com` 域名分流到美国节点（在代理软件的分流规则中添加）。

## 额外要求

仅改地区可能不够，还需确保：

1. **浏览器语言为英文** — 在 macOS 系统设置中单独为 Chrome 设置：
   - 系统设置 → 通用 → 语言与地区 → 应用程序 → Google Chrome → English (United States)
   - 注意：在 Chrome 设置里改语言不够，必须在系统层面设置，因为 Gemini 地区门控读取的是 OS 级 Locale

2. **实验开关已启用** — 在 `chrome://flags` 中搜索 `glic` 并启用

3. **设置中已开启** — Chrome 设置 → 搜索 "Gemini" → 开启"在浏览器顶部显示 Gemini"

## 诊断流程

如果快速修复无效，按以下 6 层逐项排查（详见 [SKILL.md](SKILL.md)）：

| 层级 | 检查项       | 说明                                          |
| ---- | ------------ | --------------------------------------------- |
| 1    | 地区判定     | `variations_country` 是否为 `us`              |
| 2    | 浏览器语言   | OS 级 Locale 是否为英文                       |
| 3    | 实验开关     | `glic@1` 是否在 `enabled_labs_experiments` 中 |
| 4    | Profile 配置 | `glic.previously_not_allowed` 是否为 `false`  |
| 5    | 服务端资格   | `aim_eligibility_response` 是否已授权         |
| 6    | UI 显示      | 是否全屏、按钮是否被取消固定                  |

## 目录结构

```
chrome-gemini-fix/
├── SKILL.md                        # 完整诊断流程（AI 可读的技术文档）
├── LICENSE                         # MIT 许可证
├── README.md                       # 你正在看的这个文件
├── .gitignore
├── references/
│   └── gemini-toolbar.md           # 完整排查案例 + 关键字段速查表 + 常见坑点
└── scripts/
    ├── start-chrome-us.sh      # macOS 一键启动脚本
    └── start-chrome-us.ps1     # Windows 一键启动脚本
```

## 常见坑点

- **BSD sed 语法**：macOS `sed -i` 必须写 `-i ''`（中间有空格），GNU 的 `-i` 在 Mac 上会报错
- **配置回写**：Chrome 启动时会重新校验地区并可能覆盖 `variations_country`，用启动参数或代理分流可解决
- **多 Profile 独立**：`Default`、`Profile 1` 等各有独立 `Preferences`，需逐个检查
- **全屏模式**：Chrome 全屏时工具栏整体隐藏，非 Gemini 消失
- **进程残留**：修改配置前必须完全退出 Chrome，检查 `pgrep -x "Google Chrome"`

## 兼容性

- Chrome 137+ (测试版本: 153.0.8010.53)
- macOS (darwin) / Windows 10/11

## 免责声明

本项目修改 Chrome 配置文件，操作前请务必备份。作者不对因使用本工具造成的任何数据损失负责。

## 许可证

[MIT](LICENSE)
