# DQ Clash Rules v2 — 设计说明

> 状态：**设计稿，未落地**。文件 `config/v2/config.tpl.yaml`。
> 目标客户端：家用软路由 iStoreOS 上的 **OpenClash（mihomo 内核）**。
> 主力机场：**kyapi**（`acsub.kyapi.xyz`），68 个 AnyTLS 节点。

---

## 1. 为什么推倒重来（v1 的三个毛病）

| v1 现象 | 根因 |
|---|---|
| 选「日本节点」经常连到某个小机场的日本线，不是主力机场的 | v1 把所有机场的日本节点丢进一个 `url-test` 池，谁快选谁，无来源概念 |
| kyapi 的 AnyTLS 节点一走订阅转换就全没了 | subconverter 的 Clash 序列化器不支持 AnyTLS，`target=clash` 整体返回 0 节点（xfltd 已踩过，见 `project_subconverter_service`） |
| 分组结构是照 ACL4SSR 改的，不完全贴合习惯 | v1 是在官方模板上做增删，没有从「先挑服务、再挑主力/备用节点」的用法出发重排 |

## 2. v2 的核心思路：主力 / 全池 两层节点组

```
业务组 (📹油管 / 🤖AI服务 / …)
   └─ 地区一级 (🇯🇵 日本)                  ← select，默认指向「主力」
        ├─ 🇯🇵 日本·主力   url-test, use:[kyapi]              ← 只有主力机场的日本节点
        └─ 🇯🇵 日本·全池   url-test, include-all-providers    ← 所有机场（含以后加的备用）的日本节点
```

- **「只选主力的日本」** = 地区一级 `🇯🇵 日本` 默认成员就是 `🇯🇵 日本·主力`，只从 kyapi 里挑。
- **备用不是摆设**：地区一级第二个成员是 `·全池`，手动点一下就切过去；想自动降级把 `🇯🇵 日本` 的 `type: select` 改成 `fallback`（成员顺序已经排好，主力全灭才用全池）。
- **来源靠前缀区分**：每个 `proxy-provider` 用 `override.additional-prefix` 给节点名加 `[K] ` / `[X] ` …。`·主力` 组用 `use: [kyapi]` 精确锁定；`·全池` 组用 `include-all-providers: true`，以后加机场不用改分组。

## 3. 为什么走「路线 A：mihomo 原生 proxy-providers」而不是 subconverter

- **AnyTLS 天然可用**：节点从 kyapi 订阅直接进 mihomo，不经过有 bug 的 Clash 转换器。
- **不必暴露公网**：整份配置就是 OpenClash 的本地配置文件，`sub.dqhub.uk` / SubHub 前端这次用不上（它们仍可留给别的场景）。
- **来源标签 / 按机场筛**是 mihomo `proxy-providers` + `filter` 的原生能力，subconverter 侧要靠 `rename` 硬凑且分不清来源。
- 代价：OpenClash 要切成「自定义配置文件」模式，不再用它自带的订阅管理器拉 kyapi（订阅 URL 移到配置文件里的 `proxy-providers.kyapi.url`）。

## 4. 分组清单（v2）

**业务/服务**：📹 油管 · 🏰 迪士尼 · 🤖 AI服务 · 🏢 Office全家桶 · 🐙 GitHub · 📱 社交媒体 · 🛒 亚马逊 · 🍎 苹果服务 · 🎮 游戏平台
（沿用 v1 的 9 个；`🍎 苹果` / `🎮 游戏` 默认第一项是 DIRECT）

**节点**：🚀 手动切换（主入口）· 🇯🇵🇺🇸🇭🇰🇸🇬🇨🇳🇰🇷 地区一级 · 各地区 `·主力` / `·全池` · ♻️ 自动·主力 / ♻️ 自动·全池 · 🌍 其他地区

**功能**：🎯 全球直连 · 🛑 广告拦截（默认 REJECT）· 🐟 漏网之鱼

**规则**：ACL4SSR（局域网 / 去广告 / 中国域名 / GFW 兜底）+ 本仓库自建 `config/geosite/*.list`（每天自动同步）。全部走 mihomo `rule-providers`（`behavior: classical`）。

## 5. 待你确认（落地前需要定的点）

1. **kyapi 节点的 E/S/N 档命名**——2026-08-27 实测记录里 N 档延迟 1~4.5s（慢）。要不要在 `🇯🇵 日本·主力` 等组里用 `exclude-filter` 把 N 档排除？需要一份真实 `proxies:` 节点名清单才能写准正则（模板里先留了注释行）。给我在路由器上 dump 一下 kyapi 的节点名即可。
2. **地区一级用 `select` 还是 `fallback`**——`select` = 纯手动、默认主力；`fallback` = 主力全灭自动切全池。模板默认 `select`。
3. **业务分组是否再精简**——比如 社交媒体/油管/迪士尼 是否合并成一个「🎬 国际媒体」。当前保持 9 个不动。
4. **备用机场**——现在只 kyapi。xfltd / nanoPort 要不要现在就作为 `·全池` 的备用池加进来（各给一个前缀）？还是等真需要时再加。
5. **OpenClash 接入方式**——确认可以把 OpenClash 从「订阅管理器 + `config_path=xfltd.yaml`」切成「自定义配置文件 = 本 yaml」。切换前会单独确认（改共享生产配置，按 `feedback_minimal_blast_radius_shared_infra`）。

## 6. 已知风险 / 注意

- **ACL4SSR 某些 list 含 `URL-REGEX` 等 mihomo `classical` 不认的行**，内核可能报 rule-set 解析错误。真出现就把对应源换成 ACL4SSR 的精简/`_No_Resolve` 版本，或剔掉该条。
- **`additional-prefix` 会改节点名**，所有 `filter` 都按「关键词出现在名字任意位置」写，不加 `^$` 锚定，不用 `(?!...)`（mihomo 是 RE2，不支持预查——这点跟 v1 里 subconverter `std::regex` 卡死是两码事，但结论一致：别用预查）。
- **真实订阅 URL 含 token，不能进公开仓库**。`config.tpl.yaml` 里是 `__KYAPI_URL__` 占位符；正本放 `🪪 ID Docs/` 加密笔记，只在路由器本地替换进实际配置。
- v1 的 `config/DQ_ACL4SSR.ini` **保留不动**，作为回退。

## 7. 落地步骤（等你拍板后再做）

1. 路由器上把 `__KYAPI_URL__` 换成真实 kyapi 链接，存成 `/etc/openclash/config/dq-v2.yaml`
2. 先用隔离 mihomo 实例（端口 17890/19090，按 `✅ Playbooks/2026-08-11_安全测试机场节点质量`）`mihomo -t` 校验 + 起一份实测分组生成、节点筛选是否符合预期，**全程不碰生产 `config_path`**
3. 验证通过后，OpenClash 切「自定义配置文件」→ 选 `dq-v2.yaml` → 重载
4. 观察 1~2 天稳定后，清理 OpenClash 订阅管理器里 kyapi 那条重复订阅

## 相关

`../../✅ Playbooks/2026-08-05_DQ自定义订阅规则模板搭建与维护手册.md`（v1 手册）·
`Claude Code Memory/project_subconverter_service.md` · `project_kyapi_airport_evaluation.md`
