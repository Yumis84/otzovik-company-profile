"""Run at repository root after npm ci. Supply the staging publishable key via stdin."""
from pathlib import Path
from hashlib import sha256
from html import escape
import re, subprocess, sys, tempfile, zipfile

target = 'salmcnhexlftrgtiryyo'
key = sys.stdin.read().strip()
if not re.fullmatch(r'sb_publishable_[A-Za-z0-9_-]+', key):
    sys.exit('Expected staging publishable key on stdin')
archive = Path(sys.argv[1])
assets = {}
with tempfile.TemporaryDirectory() as tmp:
    sdk = Path(tmp) / 'staging-sdk.js'
    subprocess.run(['node_modules/.bin/esbuild','node_modules/@supabase/supabase-js/dist/index.mjs','--bundle','--format=esm','--platform=browser','--minify','--outfile='+str(sdk)],check=True)
    assets[sdk.name] = sdk.read_bytes()
origin = 'https://' + target + '.supabase.co'
csp = f"default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src {origin} wss://{target}.supabase.co; img-src 'self' data: blob: {origin}; font-src 'self'; form-action 'none'; base-uri 'none'; object-src 'none'"
for path in sorted([*Path('.').glob('account-*'), Path('staging/specialist/public.html')]):
    if path.suffix not in {'.html','.js','.css'}:
        continue
    data = path.read_text().replace('__PUBLIC_KEY__',key)
    data = data.replace('rzhlcszqtuhkhfibygnk',target).replace('sb_publishable_yhqWJ1eWUznBkqKwPogTrw_xCdCbFA-',key)
    data = data.replace('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.115.0/+esm','./staging-sdk.js')
    data = data.replace('https://отзыв.com/', './account-home.html').replace('https://${encodeURIComponent(c.slug)}.xn--b1ajuq0c.com/', './account-preview.html?company_id=${encodeURIComponent(c.id)}')
    for obj in ('c','company'):
        data = data.replace("'https://'+%s.slug+'.xn--b1ajuq0c.com/'"%obj,"'./account-preview.html?company_id='+encodeURIComponent(%s.id)"%obj)
    data = data.replace("display+'.отзыв.com'", "display+'.invalid'")
    if path.name=='account-create-specialist.html':
        data = data.replace("urlPreview.textContent='https://'+(slug||'ваше-имя')+'.отзыв.com/';","const url=new URL('public.html',location.href);url.searchParams.set('slug',slug);urlPreview.textContent=url.href;urlPreview.href=url.href;")
        data = data.replace('<strong id="specialist-url">https://master-ivan.отзыв.com/</strong>','<a id="specialist-url">Профиль</a>').replace('<span class="slug-part">https://</span>','').replace('<span class="slug-part">.отзыв.com</span>','')
    if path.suffix=='.html':
        data, count = re.subn(r'<head>',lambda _: '<head><meta http-equiv="Content-Security-Policy" content="'+escape(csp,quote=True)+'">',data,count=1,flags=re.I)
        if count!=1: raise ValueError(path)
    if re.search(r'rzhlcszqtuhkhfibygnk|https?://[^/\s]*отзыв\.com|xn--b1ajuq0c\.com|https://cdn\.jsdelivr\.net|eyJ[A-Za-z0-9_-]{16,}\.',data):
        raise ValueError('Unexpected external configuration in '+str(path))
    if set(re.findall(r'sb_publishable_[\w-]+',data))-{key}:raise ValueError(path)
    assets[path.name]=data.encode()
assets['SHA256SUMS']=''.join(f'{sha256(data).hexdigest()}  {name}\n' for name,data in sorted(assets.items())).encode()
with zipfile.ZipFile(archive,'w') as z:
    for name,data in sorted(assets.items()):
        z.writestr(zipfile.ZipInfo(name,(2026,1,1,0,0,0)),data,compress_type=zipfile.ZIP_DEFLATED)
