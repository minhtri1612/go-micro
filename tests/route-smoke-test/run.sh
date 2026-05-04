#!/bin/sh
set -e

# Usage: ./run.sh <hostname> <path-prefix> <mode: canary|preview> [resolve-ip]
# Nếu có resolve-ip: curl dùng --resolve HOST:80:IP (không cần sửa /etc/hosts trên agent).
HOST="${1:-dev.go-micro.local}"
PREFIX="${2:-/api/v1/products}"
MODE="${3:-canary}"
RESOLVE_IP="${4:-}"

echo "Running Route Smoke Test for Mode: $MODE, Host: $HOST, Prefix: $PREFIX Resolve: ${RESOLVE_IP:-DNS}"

if [ "$MODE" = "canary" ]; then
  HEADER="X-Canary: true"
  EXPECTED_SERVED_BY="canary"
elif [ "$MODE" = "preview" ]; then
  HEADER="X-Preview: true"
  EXPECTED_SERVED_BY="preview"
else
  echo "Unknown mode: $MODE"
  exit 1
fi

# In a real CI environment, GATEWAY would point to the LoadBalancer IP or actual Traefik entrypoint.
URL="http://$HOST$PREFIX/health"

echo "Requesting: $URL with Header: $HEADER"
if [ -n "$RESOLVE_IP" ]; then
  RESPONSE=$(curl -i -s --resolve "${HOST}:80:${RESOLVE_IP}" -X GET -H "Host: $HOST" -H "$HEADER" "$URL" || echo "CURL_FAILED")
else
  RESPONSE=$(curl -i -s -X GET -H "Host: $HOST" -H "$HEADER" "$URL" || echo "CURL_FAILED")
fi

if [ "$RESPONSE" = "CURL_FAILED" ]; then
  echo "FAILED: curl could not connect to $URL"
  exit 1
fi

HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP/" | awk '{print $2}')
if [ "$HTTP_CODE" != "200" ]; then
  echo "FAILED: health returned $HTTP_CODE"
  echo "Response: $RESPONSE"
  exit 1
fi

SERVED_BY=$(echo "$RESPONSE" | grep -i "X-Served-By" | awk '{print $2}' | tr -d '\r')
if [ "$SERVED_BY" != "$EXPECTED_SERVED_BY" ]; then
  echo "FAILED: request was not served by $EXPECTED_SERVED_BY (Got: '$SERVED_BY')"
  exit 1
fi

echo "PASSED: Route Gate ($MODE)"
