#!/bin/sh
# Gọi thẳng pod/service canary (giống AnalysisTemplate target-smoke-test cũ).
# Usage: ./run.sh <service-name> <target-host>
set -e

SERVICE="${1:-product}"
TARGET="${2:-localhost}"

echo "Target smoke: service=$SERVICE target=$TARGET"

svc_port() {
  case "$1" in
    product) echo 8080 ;;
    order) echo 8081 ;;
    inventory) echo 8082 ;;
    noti) echo 8083 ;;
    payment) echo 8084 ;;
    client) echo 80 ;;
    *) echo 8080 ;;
  esac
}

probe_path() {
  case "$1" in
    client) echo "/" ;;
    order) echo "/orders" ;;
    *) echo "/health" ;;
  esac
}

PORT="$(svc_port "$SERVICE")"
PATH_PART="$(probe_path "$SERVICE")"
URL="http://${TARGET}:${PORT}${PATH_PART}"
HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" "$URL")
if [ "$HTTP_CODE" != "200" ]; then
  echo "FAILED: target health returned $HTTP_CODE at $URL"
  exit 1
fi
echo "PASSED: target smoke ($URL)"
