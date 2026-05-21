#!/usr/bin/env bash
# Usage: bump-image-tag.sh <env-file> <service>
set -euo pipefail
python3 - "$1" "$2" <<'PY'
import re, sys
from pathlib import Path

path = Path(sys.argv[1])
service = sys.argv[2]
lines = path.read_text().splitlines(keepends=True)
key = f"{service}:"
in_block = False
new_tag = None
out = []

for line in lines:
    if re.match(rf'^{re.escape(key)}\s*$', line):
        in_block = True
        out.append(line)
        continue
    if in_block and re.match(r'^[a-zA-Z0-9_-]+:\s*$', line):
        in_block = False
    if in_block:
        m = re.match(r'^(\s+tag:\s+)"([^"]+)"\s*$', line)
        if m and new_tag is None:
            old = m.group(2)
            m2 = re.match(r'^(.*?-v)(\d+)\.(\d+)\.(\d+)$', old)
            if not m2:
                raise SystemExit(f"Cannot parse tag: {old}")
            p, a, b, c = m2.groups()
            new_tag = f"{p}{a}.{b}.{int(c)+1}"
            out.append(f'{m.group(1)}"{new_tag}"\n')
            continue
    out.append(line)

if not new_tag:
    raise SystemExit(f"No tag under {key}")
path.write_text("".join(out))
print(new_tag)
PY
