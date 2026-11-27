import pathlib, subprocess, tempfile, zipfile, io, json, hashlib
root=pathlib.Path(__file__).resolve().parents[1]
dest=pathlib.Path(tempfile.mkdtemp(prefix='otzovik-review-'))
raw=subprocess.check_output(['git','archive','HEAD'],cwd=root)
with zipfile.ZipFile(io.BytesIO(subprocess.check_output(['git','archive','--format=zip','HEAD'],cwd=root))) as z:
    z.extractall(dest)
for name in ('p2-company-race-review.json','p2-session-review.json','p2-owner-review.json'):
    for e in json.loads((dest/'tests'/name).read_text(encoding='utf8'))['edits']:
        p=dest/e['path']
        s=p.read_bytes().decode('utf8')
        assert s.count(e['old'])==e['count'],e['path']
        p.write_bytes(s.replace(e['old'],e['new']).encode('utf8'))
for p in ('company-context-selector.mjs','publication-status-ui.mjs','company-session-fence.mjs'):
    print(p,hashlib.sha256((dest/p).read_bytes()).hexdigest())
print('ISOLATED REVIEW SOURCE',dest)
# The unchanged staging packager has an explicit module allowlist.
# Report missing module rather than silently modifying build/guard.
builder=(dest/'scripts/build-specialist-staging.py').read_text(encoding='utf8')
assert "Path('company-session-fence.mjs')" in builder, 'BLOCKER: staging packager omits imported session fence module'
