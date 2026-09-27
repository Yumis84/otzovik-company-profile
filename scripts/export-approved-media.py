#!/usr/bin/env python3
"""Prepare a public-safe media manifest from canonical profile JSON.

This script intentionally does NOT contain credentials or download private
objects. A privileged CI/runtime supplies downloaded source files separately.
"""
import argparse, json, re
from pathlib import Path

SAFE_TYPES={"logo","cover","interior","exterior","products","team","gallery"}

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--slug",required=True)
    p.add_argument("--profile",required=True)
    p.add_argument("--source-dir",required=True)
    p.add_argument("--output",required=True)
    a=p.parse_args()
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,62}",a.slug):
        raise SystemExit("invalid slug")
    data=json.loads(Path(a.profile).read_text(encoding="utf-8"))
    media=data.get("media") or []
    src=Path(a.source_dir)
    out=[]
    for item in media:
        if not isinstance(item,dict):
            continue
        typ=str(item.get("type") or "gallery").lower()
        if typ not in SAFE_TYPES:
            continue
        # The privileged fetch stage must map canonical media id -> local file.
        mid=str(item.get("id") or "")
        matches=list(src.glob(mid+".*")) if mid else []
        if len(matches)!=1:
            continue
        out.append({
            "file":matches[0].name,
            "type":typ,
            "approved":True,
            "alt":item.get("alt"),
            "caption":item.get("caption")
        })
    Path(a.output).write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"prepared {len(out)} approved media records")

if __name__=="__main__": main()
