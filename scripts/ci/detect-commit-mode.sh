#!/usr/bin/env bash
# Phân loại commit (một dòng): service | env-only | none
#   service   — có thay đổi *-service/, client/, go.mod
#   env-only  — chỉ env/* (test tag GitOps, không build image)
#   none      — không thuộc hai loại trên (Jenkinsfile, scripts/ci/, …)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
HEAD="${HEAD_REF:-HEAD}"

has_service=0
has_env=0
while read -r p; do
  [[ -z "$p" ]] && continue
  case "$p" in
    product-service/*|inventory-service/*|order-service/*|payment-service/*|notification-service/*|client/*|go.mod|go.sum)
      has_service=1
      ;;
    env/*)
      has_env=1
      ;;
  esac
done < <(git show -1 --name-only --pretty=format: "$HEAD" 2>/dev/null || true)

if [[ "$has_service" -eq 1 ]]; then
  echo service
elif [[ "$has_env" -eq 1 ]]; then
  echo env-only
else
  echo none
fi
