# DQ Clash Rules v2 — 两套并行

> 目标客户端：家用软路由 iStoreOS 上的 **OpenClash（mihomo 内核）**。
> 主力机场：**kyapi**（`acsub.kyapi.xyz`），节点全 AnyTLS。
> 核心诉求：业务分组里能直接选「日本 / 美国…」，且默认只用**优质线**（E/S 档），不掉进 N 中转慢线。

kyapi 节点命名 `<旗> <E|S|N>-<国家><序号>`（例 `🇯🇵 E-日本1` / `🇯🇵 N-日本15`）。
实测：E/S 档 380~520ms；**N 档 800~3600ms**（中转慢线）。所以 `优选 = E/S`，`全选 = 全部`。

---

## 模式一：本地覆写（kyapi 单跑，已部署）

**文件**：`openclash-region-groups.overwrite.sh`
**落地**：其中 `ruby -ryaml …` 整段已追加进路由器 `/etc/openclash/custom/openclash_custom_overwrite.sh`
（备份 `openclash_custom_overwrite.sh.bak.20260828`）。OpenClash 每次刷新订阅后自动重跑，幂等。

**做的事**：不动 kyapi 自带的 2520 条规则和业务分组，只：
1. 按生成配置里的真实节点名，动态建地区组：`日本优选`/`日本全选`/`美国优选`… （JP/US/SG/HK/TW/KR，生成配置里有哪个国家就建哪个）
2. 把这些组插进 `🚀 节点选择 / 国外媒体 / 电报 / OpenAi / Gemini / Claude / 微软 / 苹果 / 谷歌FCM / 漏网之鱼` 每个组候选项的最前面

`优选` = url-test，排除名字含 ` N-|中转|Relay|回国` 的；`全选` = 该地区全部。

**验证**：路由器上 `cp` 一份配置跑脚本 + `/etc/openclash/clash -t` → `test is successful`，连跑两次分组数不变。
**生效**：cron `0 3 * * *` 自动重建配置时套用；要立刻生效在 LuCI 点「应用配置」。

**注意**：路由器 OpenClash 的 kyapi 订阅带 `keyword` 过滤，只保留 美/新/日 三国；想要港/台/韩地区组，得先在订阅管理器里放宽那个 keyword 过滤。

---

## 模式二：网页合并链接（多机场，subconverter）

**页面**：私有 Artifact「订阅合并链接生成器」
→ https://claude.ai/code/artifact/e20de72e-cec5-4acd-baa7-4426f81301ec
（纯前端，不联网，机场链接只存浏览器 localStorage）

**产出**：一条 `https://sub.dqhub.uk/sub?target=clash&url=<机场1|机场2|…>&config=<DQ_v2.ini>&exclude=<假节点关键词>` 合并订阅链接，粘进 OpenClash / Clash Verge 订阅框即用。

**规则模板**：`config/DQ_v2.ini`（顶层 `config/` 而非 `config/v2/`——raw.githubusercontent 对新建子目录有几分钟传播延迟，放老目录才能立即被 subconverter 拉到）。
地区组同样拆 `优选`（正则 `(?i)E-日本|S-日本`，靠 E-/S- 前缀筛）/ `全选`；业务组沿用 kyapi 命名。
纯 subconverter **无法按来源机场分优先级**，「主力优先」只有模式一能做。

**已验证**：`target=clash` + kyapi 链接 + `config=DQ_v2.ini` → 200 / ~750KB / 68 节点 / 26 组 / 14394 条规则；`日本优选` 8 个（E1-4,S5-8）、`日本全选` 13 个。

**踩坑**：
- `sub.dqhub.uk` 的 subconverter（现为 `v0.9.1-*-mihomo backend`）**已能正常序列化 AnyTLS 到 clash 格式**，2026-08-11 记录的「AnyTLS→target=clash 清零」bug 不再复现。
- `target=clash.meta` 在这个 build 上报 `Invalid target!`，只能用 `target=clash`。
- ACL4SSR **没有** `Clash/Telegram.list`，加了会 404 → subconverter worker 卡死。Telegram 规则已改内联（域名 + 官方 IP 段）。

---

## 其他文件

- `config.tpl.yaml` — mihomo 原生 `proxy-providers` 完整配置模板。适合「多机场 + 主力优先 + 不想依赖 subconverter」的场景：每机场一个 provider 带 `additional-prefix`，`优选` 用 `filter: ^\[主\]…` 锁主力。当前未采用（模式一够用），留作备选。
- `DQ_v2.ini` (本目录副本，与顶层 `config/DQ_v2.ini` 同步) — 便于集中查看。

## 相关

`../../✅ Playbooks/2026-08-05_DQ自定义订阅规则模板搭建与维护手册.md` ·
`Claude Code Memory/project_subconverter_service.md` · `project_kyapi_airport_evaluation.md` ·
`Claude Code Memory/reference_router.md`
