#!/bin/sh
# =============================================================================
# 本地模式：给 OpenClash 当前配置补「国家/地区选择」这一层
# -----------------------------------------------------------------------------
# 用法：把下面「ruby -ryaml ...」整段追加进
#       /etc/openclash/custom/openclash_custom_overwrite.sh 的  exit 0  之前。
#
# 作用：不动订阅自带的规则(rules)和业务分组，只在配置里新增地区组并注入到业务组。
#       对 kyapi 单跑 或 以后合并多家订阅 都适用——地区组按“最终生成的节点名”动态构建。
#
# 地区组（每个地区一对）：
#   <地区>优选  = url-test，只收该地区的优质线（排除 N-/中转/Relay 标记）
#   <地区>全选  = url-test，收该地区全部节点（优质 + 中转，做备胎）
#
# 幂等：OpenClash 每次刷新订阅都重跑本段，脚本自身去重，不会重复插。
# =============================================================================

ruby -ryaml -e '
cf = ARGV[0]
c  = YAML.load_file(cf)
names = (c["proxies"] || []).map { |p| p["name"] }.compact

# 地区名 => 匹配正则（含中文/英文/城市别名兜底）
REGION = {
  "日本"   => /日本|Japan|JP\b|东京|大阪|名古屋|埼玉|Tokyo|Osaka/i,
  "美国"   => /美国|United ?States|USA|US\b|洛杉矶|圣何塞|西雅图|硅谷|Los ?Angeles|San ?Jose|Seattle/i,
  "新加坡" => /新加坡|狮城|獅城|Singapore|SG\b/i,
  "香港"   => /香港|Hong ?Kong|HK\b|沪港|港岛/i,
  "台湾"   => /台湾|臺灣|台灣|Taiwan|TW\b|彰化|新北/i,
}
# “优选”排除：中转 / 低速档标记
SLOW = / N-|中转|Relay|relay|RELAY|回国/

def grp(label, list)
  {
    "name" => label, "type" => "url-test",
    "url" => "http://www.gstatic.com/generate_204",
    "interval" => 300, "tolerance" => 50,
    "proxies" => (list.empty? ? ["DIRECT"] : list)
  }
end

regions = []
REGION.each do |zh, re|
  hit  = names.select { |n| n =~ re }
  next if hit.empty?
  fast = hit.reject { |n| n =~ SLOW }
  regions << grp("#{zh}优选", fast.empty? ? hit : fast)
  regions << grp("#{zh}全选", hit)
end
rnames = regions.map { |g| g["name"] }

c["proxy-groups"] ||= []
have = c["proxy-groups"].map { |g| g["name"] }
# 新地区组插在 节点选择/自动选择 之后（列表靠前，客户端里好找）
ins = c["proxy-groups"].index { |g| !["\u{1F680} 节点选择", "♻️ 自动选择"].include?(g["name"]) } || c["proxy-groups"].length
add = regions.reject { |g| have.include?(g["name"]) }
c["proxy-groups"].insert(ins, *add)

# 注入到这些业务组候选列表最前面（订阅生成的组名；缺哪个跳过哪个）
targets = [
  "\u{1F680} 节点选择", "\u{1F30D} 国外媒体", "\u{1F310} 国外媒体", "\u{1F4F2} 电报信息",
  "\u{1F4AC} OpenAi", "\u{1F48E} Gemini", "\u{1F4A1} Claude",
  "Ⓜ️ 微软服务", "\u{1F34E} 苹果服务", "\u{1F4E2} 谷歌FCM",
  "\u{1F3AE} 游戏平台", "\u{1F41F} 漏网之鱼",
]
lead = ["\u{1F680} 节点选择", "♻️ 自动选择", "\u{1F3AF} 全球直连", "DIRECT", "REJECT"]
c["proxy-groups"].each do |g|
  next unless targets.include?(g["name"])
  g["proxies"] ||= []
  g["proxies"].reject! { |p| rnames.include?(p) }   # 先清旧的 → 幂等
  h = 0
  h += 1 while g["proxies"][h] && lead.include?(g["proxies"][h])
  g["proxies"].insert(h, *rnames)
end

File.write(cf, c.to_yaml)
' "$CONFIG_FILE"

LOG_TIP "region groups injected (local mode)."
