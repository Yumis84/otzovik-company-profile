"""Verify a private, unaligned tuples-only UTF-8 psql export without printing records."""
from pathlib import Path
import hashlib, json, sys
raw=Path(sys.argv[1]).read_bytes()
if not raw.endswith(b'\n'):raise SystemExit('Incomplete export')
rows=raw[:-1].split(b'\n')
if rows!=sorted(rows):raise SystemExit('Unexpected order or extra output')
for row in rows:
    if set(json.loads(row))!={'relation','payload'}:raise SystemExit('Invalid record')
print('sha256',hashlib.sha256(raw).hexdigest())
print('otz.recovery_archive_digest',hashlib.md5(b'\n'.join(rows)).hexdigest())
