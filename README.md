# clash-rules

自用的 subconverter 自定义规则模板（`.ini`），配合 [subconverter](https://github.com/tindy2013/subconverter) 使用，通过 `&config=` 参数传入生成 Clash 配置。

## 使用方法

在 subconverter 转换请求里加 `config` 参数指向本仓库的 raw 文件：

```
https://sub.dqhub.uk/sub?target=clash&config=https://raw.githubusercontent.com/dqdudq/clash-rules/main/config/DQ_ACL4SSR.ini&url=<URL编码的订阅链接>
```

或在 [SubHub 前端](https://subweb.dqhub.uk/sub/) 的「规则模板」下拉框选「🔧 自定义模板 URL…」，填入：

```
https://raw.githubusercontent.com/dqdudq/clash-rules/main/config/DQ_ACL4SSR.ini
```

## 结构说明（`config/DQ_ACL4SSR.ini`）

**代理组**：

| 分组 | 类型 | 说明 |
|------|------|------|
| 🚀 节点选择 | select | 主入口，手动切换 |
| ♻️ 自动选择 | url-test | 全部节点自动测速选优 |
| 🇭🇰🇯🇵🇺🇲🇸🇬🇰🇷🇨🇳 地区节点 | url-test | 按节点名关键词分地区自动选优 |
| 📹 油管 / 🎥 奈飞 / 💬 AI平台 | select | 流媒体与 AI 服务单独分流 |
| 🎯 全球直连 | select | 局域网/中国域名与 IP |
| 🛑 广告拦截 | select | 默认拦截 |
| 🐟 漏网之鱼 | select | 兜底规则 |

**规则集**：直接引用 [ACL4SSR/ACL4SSR](https://github.com/ACL4SSR/ACL4SSR) 官方维护的 `Ruleset/*.list`，不在本仓库重复存放规则内容，只维护"规则集 → 代理组"的映射关系和分组结构，方便跟随上游规则更新。

## 修改

直接改 `config/DQ_ACL4SSR.ini`，push 后 `raw.githubusercontent.com` 链接立即生效（有 CDN 缓存，通常几分钟内刷新；如需立即生效可用 `?t=时间戳` 加 query string 强制绕过缓存，或改用 jsDelivr 的 `@版本号` 固定引用）。
