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

region_names = groups.map { |g| g["name"] }          # 6 个国家组
SVC = ["📺 油管", "🏰 迪士尼", "🎵 声破天", "🛒 亚马逊"]

# 每个选择器的候选顺序：🚀节点选择 / ♻️自动选择 → 服务组 → 国家组
SVC.each do |s|
  opts = ["🚀 节点选择", "♻️ 自动选择"] + region_names
  opts << "DIRECT" if s == "🛒 亚马逊"
  groups << { "name" => s, "type" => "select", "proxies" => opts }
end

c["proxy-groups"] ||= []
have = c["proxy-groups"].map { |g| g["name"] }
c["proxy-groups"].concat(groups.reject { |g| have.include?(g["name"]) })   # 缺哪个补哪个，顺序稍后统一排

# --- 重排各选择器候选项（清掉平铺节点，只留分组入口）---
all_new    = region_names + SVC
BIZ_CLEAN  = ["🌍 国外媒体", "📲 电报信息", "💬 OpenAi", "💎 Gemini", "💡 Claude", "📢 谷歌FCM", "🐟 漏网之鱼"]
KEEP_DIRECT = ["Ⓜ️ 微软服务", "🍎 苹果服务"]   # 这两个保留「🎯 全球直连」在最前（默认直连不变）
c["proxy-groups"].each do |g|
  name = g["name"]
  if name == "🚀 节点选择"
    # 手动选具体节点的入口：保留原始节点列表，国家组塞在 自动选择/DIRECT 之后、节点之前
    raw = (g["proxies"] || []).reject { |p| all_new.include?(p) || ["♻️ 自动选择", "DIRECT"].include?(p) }
    g["proxies"] = ["♻️ 自动选择", "DIRECT"] + region_names + raw
  elsif SVC.include?(name)
    # 服务组：🚀节点选择/♻️自动选择 → 国家组（+ 亚马逊 DIRECT）；不列平铺节点、不互相引用
    g["proxies"] = ["🚀 节点选择", "♻️ 自动选择"] + region_names + (name == "🛒 亚马逊" ? ["DIRECT"] : [])
  elsif BIZ_CLEAN.include?(name)
    tail = (name == "🐟 漏网之鱼") ? ["DIRECT"] : []
    g["proxies"] = ["🚀 节点选择", "♻️ 自动选择"] + SVC + region_names + tail
  elsif KEEP_DIRECT.include?(name)
    g["proxies"] = ["🎯 全球直连", "🚀 节点选择", "♻️ 自动选择"] + SVC + region_names
  end
end

# --- 面板卡片顺序：节点选择/自动选择 → 服务组 → kyapi业务组 → 国家组 → 功能组 ---
HEAD = ["🚀 节点选择", "♻️ 自动选择"]
TAIL = ["🎯 全球直连", "🛑 全球拦截", "🐟 漏网之鱼", "GLOBAL"]
rank = lambda do |n|
  return 0   + HEAD.index(n)        if HEAD.include?(n)
  return 100 + SVC.index(n)         if SVC.include?(n)
  return 800 + region_names.index(n) if region_names.include?(n)
  return 900 + TAIL.index(n)        if TAIL.include?(n)
  500   # kyapi 自带业务组等，保持原相对顺序
end
c["proxy-groups"] = c["proxy-groups"].each_with_index
                     .sort_by { |g, i| [rank.call(g["name"]), i] }
                     .map(&:first)

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
