# DQ Clash Rules v2 — kyapi 路由器增强

> 客户端：家用软路由 iStoreOS 上的 **OpenClash（mihomo 内核）**，主力机场 **kyapi**（`acsub.kyapi.xyz`），节点全 AnyTLS。
> 诉求：在 kyapi 官方订阅规则基础上补「国家选择」+ 油管/迪士尼/声破天/亚马逊 专属分组。

kyapi 节点命名 `<旗> <E|S|N>-<国家><序号>`。实测 E/S 档 380~520ms，**N 档 800~3600ms（中转慢线）**。
kyapi `app=auto` 返回约 75 个节点：香港22 / 日本13 / 台湾7 / 美国7 / 新加坡7 / 韩国2 / 英德巴土印马泰菲乌 各 1~2。

---

## 采用方案：`kyapi-router-enhanced.overwrite.sh`（已部署）

**落地**：其中 `ruby -ryaml …` 整段已追加进路由器 `/etc/openclash/custom/openclash_custom_overwrite.sh`
（原文件备份 `openclash_custom_overwrite.sh.bak.20260828`）。OpenClash 每次刷新订阅后自动重跑，**幂等**。

**做的事**（不改 kyapi 的 rules 结构和 13 个业务组）：

1. **6 个地区组**（url-test，自动选最快；默认排除 ` N-` 中转慢线，其余照 kyapi 原节点名）
   `🇯🇵 日本` `🇺🇸 美国` `🇸🇬 新加坡` `🇭🇰 香港` `🇹🇼 台湾` `🌍 其他国家`
   （`其他国家` = 不属于前 5 国的真实节点：韩/英/德/巴西/土/印/马/泰/菲/乌）
2. **4 个专属分组**（select，候选 = 🚀节点选择 + 6 地区组 + ♻️自动选择；亚马逊多一个 DIRECT）
   `📺 油管` `🏰 迪士尼` `🎵 声破天` `🛒 亚马逊`
3. 把这 10 个组插进 `节点选择 / 国外媒体 / 电报 / OpenAi / Gemini / Claude / 微软 / 苹果 / 谷歌FCM / 漏网之鱼` 每个组候选项最前
   （`🚀 节点选择` 只塞 6 个地区组——4 个服务组引用了它，全塞会成环）
4. **规则重定向**：把 kyapi 里 youtube / disney / spotify / amazon-video 的分流从 `🌍 国外媒体` 改指到各自专组；
   另补 `amazon.com` / `amazon.co.jp` / `primevideo.com` / `open.spotify.com` 等 kyapi 缺的几条到最前

**验证**：路由器 `cp` 一份 kyapi 生成配置跑脚本 → `/etc/openclash/clash -t` = `test is successful`，连跑三次 23 组不变、无 ProxyGroup loop。
**生效**：cron `0 3 * * *` 自动重建配置时套用；要立刻生效在 LuCI 点「应用配置」。**不要为了立即生效反复 `/etc/init.d/openclash restart`**（见下方事故）。

---

## 未采用的东西（留档）

- **`sub-merge-generator.html`** —— 网页版「订阅合并链接生成器」，多机场合并思路。**2026-08-29 用户明确不用**，仅留仓库存档。曾发过私有 Artifact `e20de72e-…`（已弃用）。
- **`openclash-region-groups.overwrite.sh`** —— 增强版的前身，只做地区组不做服务组，已被 `kyapi-router-enhanced` 取代。
- **`config.tpl.yaml`** —— mihomo 原生 `proxy-providers` 多机场模板（每机场一 provider 带 `additional-prefix`，`优选` 用 `filter: ^\[主\]…` 锁主力）。纯本地不依赖 subconverter，留作以后真要多机场时的备选。
- **`DQ_v2.ini`**（顶层 `config/` + 本目录副本）—— subconverter 合并链接用的规则模板，配 `sub-merge-generator.html`。一并搁置。

## subconverter 现状（更新 2026-08-11 旧结论）

- `sub.dqhub.uk` backend 已能正常把 **AnyTLS 序列化到 clash 格式**，旧的「AnyTLS→target=clash 清零」bug 不再复现。
- `target=clash.meta` 报 `Invalid target!`，只能 `target=clash`。
- ACL4SSR **没有** `Clash/Telegram.list`（404 → subconverter worker 卡死），DQ_v2.ini 里 Telegram 已改内联。

## 2026-08-28 夜事故（教训）

想一次把「4 机场合并当出口 + 地区组」全上生产 → 合并配置 DNS 引导死锁（fallback DNS 走空的代理组），来回 `openclash restart` 十几次把 nft/路由也搞乱。
- **误判**：`curl 127.0.0.1:9090/proxies` 一直 `Unauthorized` → 以为 0 节点。实际 **mihomo API 要 secret**（`grep '^secret:' /etc/openclash/ihcloud.yaml`），带 `-H "Authorization: Bearer <secret>"` 才有数据。
- 最终 `cp /etc/config/openclash.bak.<日期>` 全量回滚。改共享路由器：**一次只改一样、只重启一次、马上从真实客户端验证**。

## 相关

`../../✅ Playbooks/2026-08-05_DQ自定义订阅规则模板搭建与维护手册.md` ·
`Claude Code Memory/project_subconverter_service.md` · `project_kyapi_airport_evaluation.md` · `reference_router.md`
