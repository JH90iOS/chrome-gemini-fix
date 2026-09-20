# Chrome Gemini 修复

## 问题根因

Chrome 137+ 集成 Gemini in Chrome 后，会根据出口 IP 判定地区。当 `variations_country` 为 `cn` 时，直接隐藏顶部工具栏的 Gemini 按钮和设置中的 AI 入口。升级版本后部分地区校准逻辑变化，可能导致此前能用的按钮消失。

## 诊断分层流程

按以下顺序逐层排查，找到首个未通过项即执行对应修复：

### 第 1 层：地区判定（最常见根因）

检查 `Local State` 中 `variations_country` 的值：

```bash
# macOS
grep -o '"variations_country":"[a-z]*"' "$HOME/Library/Application Support/Google/Chrome/Local State"
# Windows (PowerShell)
Select-String -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State" -Pattern '"variations_country":"([a-z]*)"'
```

若为 `cn`，需修改为 `us`。**必须先完全退出 Chrome**，否则配置会被回写覆盖。

**方案 A（推荐）：启动参数覆盖**——不改文件，每次启动带参数：

```bash
# macOS
open -a "Google Chrome" --args --variations-override-country=us
# Windows
Start-Process "chrome.exe" -ArgumentList "--variations-override-country=us"
```

**方案 B：修改配置文件**——一劳永逸但可能被回写：

```bash
# macOS（注意 BSD sed 必须用 -i ''）
cp "$HOME/Library/Application Support/Google/Chrome/Local State" "$HOME/Library/Application Support/Google/Chrome/Local State.bak"
sed -i '' 's/"variations_country":"cn"/"variations_country":"us"/' "$HOME/Library/Application Support/Google/Chrome/Local State"
```

```powershell
# Windows
Copy-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State" "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State.bak"
(Get-Content "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State") -replace '"variations_country":"cn"', '"variations_country":"us"' | Set-Content "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
```

若修改后被自动改回 `cn`：需将 `clientservices.googleapis.com` 域名分流到美国节点（在代理软件分流规则中添加），从源头避免地区被重新校准。

### 第 2 层：浏览器语言

Gemini 功能要求浏览器语言为英文。macOS 可单独给 Chrome 设置英文，不影响系统其他应用：

- **macOS**：系统设置 → 通用 → 语言与地区 → 应用程序 → 找到 Google Chrome → 设为 English (United States)
- **Windows**：设置 → 时间和语言 → 语言 → 首选语言添加 English (United States)

### 第 3 层：实验开关（Flags）

检查 `Local State` 中 `enabled_labs_experiments` 是否包含 `glic@1`：

```bash
# macOS
python3 -c "import json; d=json.load(open('$HOME/Library/Application Support/Google/Chrome/Local State')); print(d.get('browser',{}).get('enabled_labs_experiments',[]))"
```

```powershell
# Windows (PowerShell)
python -c "import json,os; d=json.load(open(os.path.join(os.environ['LOCALAPPDATA'],'Google','Chrome','User Data','Local State'))); print(d.get('browser',{}).get('enabled_labs_experiments',[]))"
```

若无 `glic@1`，需手动添加。也可以引导用户在 `chrome://flags` 搜索 `glic` 并启用。

### 第 4 层：Profile 配置（glic 字段）

检查各 Profile 的 `Preferences` 文件中 `glic` 配置，关键字段：

| 字段                          | 期望值  | 说明                                   |
| ----------------------------- | ------- | -------------------------------------- |
| `previously_not_allowed`      | `false` | 历史禁止缓存标记，为 `true` 会阻止显示 |
| `pinned_to_tabstrip`          | `true`  | 是否固定到工具栏                       |
| `partition_needs_cookie_sync` | -       | Cookie 同步状态，可能影响功能初始化    |
| `onboarding_status`           | `5`     | 引导完成状态                           |

```bash
# macOS - 检查并修复 glic 配置
python3 -c "
import json
p='$HOME/Library/Application Support/Google/Chrome/Default/Preferences'
d=json.load(open(p))
if 'glic' in d:
    d['glic']['previously_not_allowed']=False
    d['glic']['pinned_to_tabstrip']=True
    json.dump(d, open(p,'w'), ensure_ascii=False)
    print('glic 配置已修复')
"
```

```powershell
# Windows (PowerShell) - 检查并修复 glic 配置
python -c "
import json,os
p=os.path.join(os.environ['LOCALAPPDATA'],'Google','Chrome','User Data','Default','Preferences')
d=json.load(open(p))
if 'glic' in d:
    d['glic']['previously_not_allowed']=False
    d['glic']['pinned_to_tabstrip']=True
    json.dump(d, open(p,'w'), ensure_ascii=False)
    print('glic 配置已修复')
"
```

注意：`previously_not_allowed` 可能被 Chrome 启动时重新设为 `true`，需配合第 1 层方案 A 使用启动参数。

### 第 5 层：服务端资格

解码 `Preferences` 中 `aim_eligibility_service.aim_eligibility_response`（base64 编码的 protobuf），确认 Google 服务端是否允许该账号使用 Gemini。若响应中包含完整功能配置（图片生成、文件上传等），说明服务端已授权，问题在本地 UI 层。

```bash
# macOS
python3 -c "
import json,base64,re
d=json.load(open('$HOME/Library/Application Support/Google/Chrome/Default/Preferences'))
resp=d.get('aim_eligibility_service',{}).get('aim_eligibility_response','')
raw=base64.b64decode(resp)
texts=re.findall(rb'[\x20-\x7e\xe4-\xe9][\x20-\x7e\xe4-\xe9\x80-\xbf]{3,}', raw)
for t in texts[:20]:
    try: print(t.decode('utf-8'))
    except: pass
"
```

```powershell
# Windows (PowerShell)
python -c "
import json,base64,re,os
d=json.load(open(os.path.join(os.environ['LOCALAPPDATA'],'Google','Chrome','User Data','Default','Preferences')))
resp=d.get('aim_eligibility_service',{}).get('aim_eligibility_response','')
raw=base64.b64decode(resp)
texts=re.findall(rb'[\x20-\x7e\xe4-\xe9][\x20-\x7e\xe4-\xe9\x80-\xbf]{3,}', raw)
for t in texts[:20]:
    try: print(t.decode('utf-8'))
    except: pass
"
```

### 第 6 层：UI 显示

排查 UI 层问题：

- 确认 Chrome 不在全屏模式（全屏会隐藏工具栏）
  - macOS：按 F11 或绿色按钮退出全屏
  - Windows：按 F11 退出全屏
- 确认按钮未被手动取消固定（右上角"自定义 Chrome"）
- macOS 用 `screencapture` 截图前先 `osascript -e 'tell application "Google Chrome" to activate'`，否则可能截到桌面
- Windows 可用 `Win+Shift+S` 截图，或用 PowerShell `Add-Type` 调用 `System.Drawing` 截屏

## 快速修复脚本

- **macOS**：使用 `scripts/start-chrome-us.sh` 一键以美国地区启动 Chrome（含退出旧进程、启动参数覆盖）
- **Windows**：使用 `scripts/start-chrome-us.ps1` 一键以美国地区启动 Chrome

## 参考文档

完整案例与关键字段速查表见 [references/gemini-toolbar.md](references/gemini-toolbar.md)。

## 注意事项

- 修改配置文件前必须**完全退出 Chrome**（Cmd+Q / Alt+F4），检查后台无残留进程
- macOS 的 `sed` 是 BSD 版本，必须用 `-i ''`（中间有空格），GNU 的 `-i` 会报错
- 复杂 JSON 修改用 `python3` 操作，避免 sed 正则误伤
- 修改后重启 Chrome 需验证值未被自动回写
- 多 Profile 配置相互独立，需逐个检查
- 这是灰度功能，账号资格、版本、网络环境任一不满足都可能不显示
