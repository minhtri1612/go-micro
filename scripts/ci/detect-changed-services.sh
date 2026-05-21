#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
if [[ -n "${FORCE_SERVICES:-}" ]]; then
  tr ',' '\n' <<< "${FORCE_SERVICES// /}"
  exit 0
fi
# Commit vừa push: so sánh với parent. Jenkins BUILD_SERVICES=auto dùng cặp này.
BASE="${BASE_REF:-HEAD~1}"
HEAD="${HEAD_REF:-HEAD}"
if [[ -n "${GIT_PREVIOUS_SUCCESSFUL_COMMIT:-}" ]] && git rev-parse --verify "$GIT_PREVIOUS_SUCCESSFUL_COMMIT" >/dev/null 2>&1; then
  BASE="$GIT_PREVIOUS_SUCCESSFUL_COMMIT"
fi
git rev-parse --verify "$BASE" >/dev/null 2>&1 || { echo "product inventory order payment noti client"; exit 0; }
declare -A s=()
while read -r p; do
  case "$p" in
    product-service/*) s[product]=1 ;;
    inventory-service/*) s[inventory]=1 ;;
    order-service/*) s[order]=1 ;;
    payment-service/*) s[payment]=1 ;;
    notification-service/*) s[noti]=1 ;;
    client/*) s[client]=1 ;;
    go.mod|go.sum) for x in product inventory order payment noti; do s[$x]=1; done ;;
  esac
done < <(git diff --name-only "$BASE" "$HEAD" 2>/dev/null || true)
for k in "${!s[@]}"; do echo "$k"; done | sort
