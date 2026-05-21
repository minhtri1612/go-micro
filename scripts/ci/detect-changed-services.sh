#!/usr/bin/env bash
# In ra tên service (product, order, …) cần build.
# BUILD_SERVICES=auto: file trong commit HEAD + diff HEAD~1..HEAD (union).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if [[ -n "${FORCE_SERVICES:-}" ]]; then
  tr ',' '\n' <<< "${FORCE_SERVICES// /}"
  exit 0
fi

HEAD="${HEAD_REF:-HEAD}"
BASE="${BASE_REF:-HEAD~1}"

declare -A s=()
add_path() {
  local p="$1"
  case "$p" in
    product-service/*) s[product]=1 ;;
    inventory-service/*) s[inventory]=1 ;;
    order-service/*) s[order]=1 ;;
    payment-service/*) s[payment]=1 ;;
    notification-service/*) s[noti]=1 ;;
    client/*) s[client]=1 ;;
    go.mod|go.sum) for x in product inventory order payment noti; do s[$x]=1; done ;;
  esac
}

# Mọi file touched trong commit hiện tại (đúng nghĩa "vừa git push")
while read -r p; do
  [[ -n "$p" ]] && add_path "$p"
done < <(git show -1 --name-only --pretty=format: "$HEAD" 2>/dev/null || true)

# Thêm diff so với parent (phòng merge / amend)
if git rev-parse --verify "${BASE}^{commit}" >/dev/null 2>&1; then
  while read -r p; do
    [[ -n "$p" ]] && add_path "$p"
  done < <(git diff --name-only "$BASE" "$HEAD" 2>/dev/null || true)
fi

if [[ ${#s[@]} -eq 0 ]]; then
  echo "DEBUG: commit $(git rev-parse --short HEAD) — không có */service/ trong:" >&2
  git show -1 --name-only --pretty=format:'  %h %s' "$HEAD" 2>/dev/null | sed 's/^/  /' >&2
  exit 0
fi

for k in "${!s[@]}"; do echo "$k"; done | sort
