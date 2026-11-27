"""Review artifact only. Never builds or modifies protected source."""
import difflib, hashlib, json, pathlib, subprocess
root=pathlib.Path(__file__).resolve().parents[1]
out=root.parent/'otzovik-protected-review'
out.mkdir(exist_ok=True)
original={}
candidate={}
for name in ('p2-company-race-review.json','p2-session-review.json'):
    for e in json.loads((root/'tests'/name).read_text(encoding='utf8'))['edits']:
        p=e['path']
        if p not in original:
            original[p]=subprocess.check_output(['git','show','HEAD:'+p],cwd=root).decode('utf8')
            candidate[p]=original[p]
        assert candidate[p].count(e['old'])==e['count'],(p,e['old'])
        candidate[p]=candidate[p].replace(e['old'],e['new'])
diff=''.join(''.join(difflib.unified_diff(original[p].splitlines(True),candidate[p].splitlines(True),fromfile='a/'+p,tofile='b/'+p)) for p in sorted(candidate))
(out/'candidate.diff').write_bytes(diff.encode('utf8'))
manifest={p:{'old':hashlib.sha256(original[p].encode()).hexdigest(),'new':hashlib.sha256(candidate[p].encode()).hexdigest()} for p in sorted(candidate)}
(out/'manifest.json').write_bytes(json.dumps(manifest,indent=2).encode())
print('REVIEW ONLY',len(candidate),'files',hashlib.sha256(diff.encode()).hexdigest())
print(json.dumps(manifest))
