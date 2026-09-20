# Gemini 工具栏消失 — 完整案例与关键字段速查

## 目录

1. [实测环境](#实测环境)
2. [完整排查记录](#完整排查记录)
3. [关键字段速查表](#关键字段速查表)
4. [常见坑点](#常见坑点)
5. [最终有效方案](#最终有效方案)

---

## 实测环境

- 系统：macOS (Darwin)
- Chrome 版本：153.0.8010.53
- 账号：Gmail 账号已登录，服务端已判定允许使用 Gemini
- 问题：Chrome 升级后右上角 Gemini 按钮消失，设置中"在浏览器顶部显示 Gemini"已开启

---

## 完整排查记录

以下为一次完整排查的各步骤与结果，供复现参考。

### 步骤 1：检查地区标记

```bash
grep -o '"variations_country":"[a-z]*"' "$HOME/Library/Application Support/Google/Chrome/Local State"
# 结果："variations_country":"cn"  ← 根因
```

### 步骤 2：修改地区为 us

先退出 Chrome，再执行：

```bash
cp "$HOME/Library/Application Support/Google/Chrome/Local State" "$HOME/Library/Application Support/Google/Chrome/Local State.bak"
sed -i '' 's/"variations_country":"cn"/"variations_country":"us"/' "$HOME/Library/Application Support/Google/Chrome/Local State"
# 验证
grep -o '"variations_country":"[a-z]*"' "$HOME/Library/Application Support/Google/Chrome/Local State"
# 结果："variations_country":"us"  ← 修改成功
```

重启 Chrome 后检查，值保持 `us`，但 Gemini 按钮仍未出现。

### 步骤 3：检查 Profile 配置

```bash
python3 -c "
import json
d=json.load(open('$HOME/Library/Application Support/Google/Chrome/Default/Preferences'))
g=d.get('glic',{})
print(json.dumps(g, ensure_ascii=False, indent=2))
"
```

输出（注意 `previously_not_allowed` 为 `true` 是阻止显示的历史标记）：

```json
{
  "completed_fre": 1,
  "last_invoked_time": "13433995816935891",
  "last_prompt_time": "13433941348286248",
  "onboarding_status": 5,
  "partition_needs_cookie_sync": true,
  "pinned_to_tabstrip": true,
  "previously_not_allowed": true,
  "profile_enablement": { "last_ready_state": 3 },
  "window": { "last_dimissed_time": "13433995816935872" }
}
```

### 步骤 4：修改 glic.previously_not_allowed

```bash
python3 -c "
import json
p='$HOME/Library/Application Support/Google/Chrome/Default/Preferences'
d=json.load(open(p))
d['glic']['previously_not_allowed']=False
json.dump(d, open(p,'w'), ensure_ascii=False)
print('写入完成')
"
```

重启后检查，`previously_not_allowed` 又被 Chrome 自动改回 `true`。说明仅改配置不够。

### 步骤 5：检查实验开关

```bash
python3 -c "
import json
d=json.load(open('$HOME/Library/Application Support/Google/Chrome/Local State'))
print(d.get('browser',{}).get('enabled_labs_experiments',[]))
"
# 结果：['enable-webrtc-hide-local-ips-with-mdns@2', 'glic@1']  ← glic 已开启
```

### 步骤 6：解码服务端资格响应

```bash
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

输出包含"添加图片""添加文件""生成图片""已启用"等，确认 Google 服务端已授权。

### 步骤 7：设置浏览器语言为英文

macOS：系统设置 → 通用 → 语言与地区 → 应用程序 → Google Chrome → English (United States)

### 步骤 8：用启动参数覆盖地区

```bash
open -a "Google Chrome" --args --variations-override-country=us
```

此方案成功，Gemini 按钮恢复显示。

---

## 关键字段速查表

### Local State 文件

| 字段路径                           | 说明            | 期望值        |
| ---------------------------------- | --------------- | ------------- |
| `variations_country`               | IP 地区判定结果 | `us`          |
| `browser.enabled_labs_experiments` | 实验开关列表    | 包含 `glic@1` |

### Preferences 文件（各 Profile 独立）

| 字段路径                                           | 说明                          | 期望值              |
| -------------------------------------------------- | ----------------------------- | ------------------- |
| `glic.previously_not_allowed`                      | 历史禁止缓存                  | `false`             |
| `glic.pinned_to_tabstrip`                          | 工具栏固定                    | `true`              |
| `glic.onboarding_status`                           | 引导状态                      | `5`（已完成）       |
| `glic.partition_needs_cookie_sync`                 | Cookie 同步                   | `true` 时可能需重置 |
| `glic.profile_enablement.last_ready_state`         | 就绪状态                      | `3`                 |
| `aim_eligibility_service.aim_eligibility_response` | 服务端资格（base64 protobuf） | 含完整功能配置      |
| `toolbar.pinned_actions`                           | 工具栏固定按钮列表            | 应含 Gemini 相关项  |

---

## 常见坑点

1. **BSD sed 语法**：macOS `sed -i` 必须写 `-i ''`（空字符串备份后缀），GNU 的 `sed -i` 在 Mac 上会报错
2. **配置回写**：Chrome 启动时会重新校验地区并可能覆盖 `variations_country` 和 `previously_not_allowed`，需用启动参数或代理分流解决
3. **多 Profile 独立**：`Default`、`Profile 1`、`Profile 3` 等各有独立 `Preferences`，需逐个检查
4. **全屏模式**：Chrome 全屏时工具栏整体隐藏，截图前需 `osascript -e 'tell application "Google Chrome" to activate'` 并确认非全屏
5. **截图体积**：`screencapture` 生成的 PNG 可能过大（>5MB），需用 `sips -Z 1600` 压缩后再分析
6. **进程残留**：退出 Chrome 后检查 `pgrep -x "Google Chrome"`，确保无后台进程再修改文件
7. **语言要求**：浏览器语言必须为英文，中文环境下即使地区改对也可能不显示

---

## 最终有效方案

经完整排查，在本案例中有效的最终方案为两步组合：

1. **将 Chrome 浏览器语言设为 English (United States)**（macOS 可单独为 Chrome 设置，不影响系统）
2. **使用启动参数覆盖地区**：`open -a "Google Chrome" --args --variations-override-country=us`

配套脚本 `scripts/start-chrome-us.sh` 封装了上述启动逻辑，先退出旧 Chrome 进程再带参数启动。
