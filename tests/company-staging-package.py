"""Offline packaging regression: no staging company link may expose a private preview."""
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
KEY = "sb_publishable_SYNTHETIC_BUILD_ONLY"
with tempfile.TemporaryDirectory() as tmp:
    output = Path(tmp) / "candidate.zip"
    subprocess.run(
        [sys.executable, "scripts/build-specialist-staging.py", str(output)],
        input=KEY, text=True, cwd=ROOT, check=True,
    )
    with zipfile.ZipFile(output) as archive:
        names = set(archive.namelist())
        assert "company-public-unavailable.html" in names
        fallback = archive.read("company-public-unavailable.html").decode("utf-8")
        assert 'name="robots" content="noindex,nofollow"' in fallback
        assert sum(0x0400 <= ord(ch) <= 0x04ff for ch in fallback) > 100
        assert "???" not in fallback
        assert "get_my_companies" not in fallback
        assert "get_public_company_profile_v2" not in fallback
        assert "rzhlcszqtuhkhfibygnk" not in fallback
        analytics = archive.read("account-analytics.html").decode("utf-8")
        assert "company-public-unavailable.html?slug=" in analytics
        assert "sb_publishable_SYNTHETIC_BUILD_ONLY" in analytics
        assert "salmcnhexlftrgtiryyo.supabase.co" in analytics
        assert "company-public-unavailable.html" in names
        assert "account-home.html" in names
        assert "staging-sdk.js" in names
        assert "https://salmcnhexlftrgtiryyo.supabase.co" in analytics
        assert "account-preview.html?company_id=" not in analytics
        manifest = archive.read("SHA256SUMS").decode("ascii")
        expected = {line.split("  ", 1)[1]: line.split("  ", 1)[0]
                    for line in manifest.splitlines()}
        assert set(expected) == names - {"SHA256SUMS"}
        for name, digest in expected.items():
            assert hashlib.sha256(archive.read(name)).hexdigest() == digest, name
        for name in names:
            if name.endswith((".html", ".js")):
                body = archive.read(name).decode("utf-8")
                assert "account-preview.html?company_id=" not in body, name
                assert "xn--b1ajuq0c.com" not in body, name
                assert "https://\u043e\u0442\u0437\u044b\u0432.com/" not in body, name
                assert "rzhlcszqtuhkhfibygnk" not in body, name
                assert "__PUBLIC_KEY__" not in body, name
                assert "https://cdn.jsdelivr.net/npm/@supabase/supabase-js" not in body, name
        print(f"PASS offline staging ZIP: {len(names)} files, verified SHA256SUMS, no private company route, no production backend")
