#!/usr/bin/env python3
"""Sync per-service domain rules from MetaCubeX/meta-rules-dat (meta branch, updated daily
upstream) and convert them into classic Clash `DOMAIN`/`DOMAIN-SUFFIX` lines that
subconverter's `ruleset=` directive can consume for a `target=clash` output
(subconverter's ClashRuleTypes allowlist does not include `GEOSITE`, so the raw
geosite `+.domain.com` format from upstream must be converted, not used directly).
"""
import os
import urllib.request

CATEGORIES = [
    "openai", "anthropic", "google", "youtube",
    "microsoft", "github", "twitter", "instagram", "facebook",
    "amazon", "apple", "steam", "nintendo", "epicgames", "playstation", "xbox",
    "disney",
]

SOURCE = "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/{}.list"
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "config", "geosite")


def convert(name):
    url = SOURCE.format(name)
    with urllib.request.urlopen(url, timeout=30) as resp:
        content = resp.read().decode("utf-8")
    lines = []
    for raw in content.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("+."):
            lines.append(f"DOMAIN-SUFFIX,{line[2:]}")
        else:
            lines.append(f"DOMAIN,{line}")
    return lines


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name in CATEGORIES:
        lines = convert(name)
        out_path = os.path.join(OUT_DIR, f"{name}.list")
        with open(out_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(f"# Auto-converted from MetaCubeX/meta-rules-dat geo/geosite/{name}.list\n")
            f.write("# Upstream updates ~daily; this file is synced by .github/workflows/sync-geosite.yml\n")
            f.write("# Do not edit by hand -- changes will be overwritten on next sync.\n")
            f.write("\n".join(lines) + "\n")
        print(f"{name}: {len(lines)} rules")


if __name__ == "__main__":
    main()
