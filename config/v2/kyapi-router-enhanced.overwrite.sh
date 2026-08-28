#!/bin/sh
# =============================================================================
# kyapi 路由器独自增强版
# -----------------------------------------------------------------------------
# 把下面「ruby -ryaml ...」整段追加进
#   /etc/openclash/custom/openclash_custom_overwrite.sh 的  exit 0  之前。
# （替换掉旧的 openclash-region-groups.overwrite.sh 那一段，本文件是它的超集）
#
# 基于 kyapi 官方订阅规则，不改它的 rules/业务组结构，只：
#   1) 加 6 个地区组： 🇯🇵日本  🇺🇸美国  🇸🇬新加坡  🇭🇰香港  🇹🇼台湾  🌍其他国家
#      （url-test 自动选最快；地区组默认排除 " N-" 中转慢线，其余照 kyapi 原名）
#   2) 加 4 个专属分组： 📺油管  🏰迪士尼  🎵声破天  🛒亚马逊
#   3) 把这 10 个组塞进 kyapi 每个业务组候选项最前面
#   4) 把 kyapi 里 youtube / disney / spotify / amazon 的分流
#      从「🌍 国外媒体」改指到各自的专属分组
#
# kyapi 节点档位：E=不优化直连线(text: "E组为不优化")  S=优化线  N=中转慢线
# 幂等：OpenClash 每次刷新订阅重跑本段，脚本自身去重。
# =============================================================================

ruby -ryaml -e '
cf = ARGV[0]
c  = YAML.load_file(cf)
names = (c["proxies"] || []).map { |p| p["name"] }.compact
JUNK = /剩余|流量|官网|到期|重置|订阅|泄露|盗用|拉取|不优化|GB|群组|公告/
real = names.reject { |n| n =~ JUNK }

REGION = [
  ["🇯🇵 日本",   /日本|Japan|JP\b|东京|大阪|Tokyo|Osaka/i],
  ["🇺🇸 美国",   /美国|USA|United ?States|US\b|洛杉矶|圣何塞|西雅图/i],
  ["🇸🇬 新加坡", /新加坡|狮城|獅城|Singapore|SG\b/i],
  ["🇭🇰 香港",   /香港|Hong ?Kong|HK\b/i],
  ["🇹🇼 台湾",   /台湾|臺灣|台灣|Taiwan|TW\b/i],
]
SLOW = / N-|中转|Relay|relay|回国/
T = "http://www.gstatic.com/generate_204"
ut = lambda { |name, list|
  { "name" => name, "type" => "url-test", "url" => T,
    "interval" => 300, "tolerance" => 50,
    "proxies" => (list.empty? ? ["DIRECT"] : list) }
}

groups = []
claimed = []
REGION.each do |label, re|
  hit = real.select { |n| n =~ re }
  next if hit.empty?
  claimed.concat(hit)
  fast = hit.reject { |n| n =~ SLOW }
  groups << ut.call(label, fast.empty? ? hit : fast)
end
others = real.reject { |n| claimed.include?(n) }
groups << ut.call("🌍 其他国家", others) unless others.empty?

region_names = groups.map { |g| g["name"] }
SVC = ["📺 油管", "🏰 迪士尼", "🎵 声破天", "🛒 亚马逊"]
SVC.each do |s|
  opts = ["🚀 节点选择"] + region_names + ["♻️ 自动选择"]
  opts << "DIRECT" if s == "🛒 亚马逊"
  groups << { "name" => s, "type" => "select", "proxies" => opts }
end
inject = region_names + SVC

c["proxy-groups"] ||= []
have = c["proxy-groups"].map { |g| g["name"] }
newg = groups.reject { |g| have.include?(g["name"]) }
pos = c["proxy-groups"].index { |g| !["🚀 节点选择", "♻️ 自动选择"].include?(g["name"]) } || c["proxy-groups"].size
c["proxy-groups"].insert(pos, *newg)

BIZ  = /节点选择|国外媒体|电报信息|OpenAi|Gemini|Claude|微软服务|苹果服务|谷歌FCM|漏网之鱼/
LEAD = ["🚀 节点选择", "♻️ 自动选择", "🎯 全球直连", "DIRECT", "REJECT"]
c["proxy-groups"].each do |g|
  next unless g["name"] =~ BIZ
  next if SVC.include?(g["name"])
  g["proxies"] ||= []
  g["proxies"].reject! { |p| inject.include?(p) }
  h = 0
  h += 1 while g["proxies"][h] && LEAD.include?(g["proxies"][h])
  # 🚀 节点选择 只塞地区组；4 个服务组本身引用了 🚀 节点选择，塞进去会成环
  add_here = (g["name"] == "🚀 节点选择") ? region_names : inject
  g["proxies"].insert(h, *add_here)
end

# --- 规则重定向：只动当前指向「国外媒体」的那批 ---
YT  = /youtube|googlevideo|ytimg|youtu\.be|yt3\.ggpht|withyoutube|youtubei|youtubekids|youtubeeducation|youtubegaming/i
DIS = /disney|disneyplus|disney-plus|disneystreaming|bamgrid|dssott|starott|bn5x\.net|registerdisney/i
SPO = /spotify|spotifycdn|scdn\.co|pscdn\.co|spoti\.fi/i
AMZ = /amazonvideo|primevideo|atv-ps\.amazon|aiv-cdn|aiv-delivery|pv-cdn|media-amazon|images-amazon|aboutamazon|amazon\.jobs|amazontools|amazontours|amazonuniversity/i
c["rules"] = (c["rules"] || []).map do |r|
  s = r.to_s
  next r unless s.include?("国外媒体")
  d = if    s =~ YT  then "📺 油管"
      elsif s =~ DIS then "🏰 迪士尼"
      elsif s =~ SPO then "🎵 声破天"
      elsif s =~ AMZ then "🛒 亚马逊"
      end
  d ? s.sub(/,[^,]*国外媒体.*\z/, ",#{d}") : r
end

# --- 补 kyapi 缺的几条（放最前，避免被更宽的 keyword 规则先命中）---
EXTRA = [
  "DOMAIN-SUFFIX,amazon.com,🛒 亚马逊",
  "DOMAIN-SUFFIX,amazon.co.jp,🛒 亚马逊",
  "DOMAIN-SUFFIX,primevideo.com,🛒 亚马逊",
  "DOMAIN-SUFFIX,media-amazon.com,🛒 亚马逊",
  "DOMAIN-SUFFIX,open.spotify.com,🎵 声破天",
]
seen = c["rules"].map(&:to_s)
EXTRA.reverse_each do |e|
  c["rules"].unshift(e) unless seen.include?(e)
end

File.write(cf, c.to_yaml)
' "$CONFIG_FILE"

LOG_TIP "kyapi enhanced: region + youtube/disney/spotify/amazon groups injected."
