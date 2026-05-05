#!/bin/sh
set -e

# Usage: ./run.sh <service-name> <target-url>
SERVICE="${1:-product}"
TARGET="${2:-localhost}"

echo "Running Business Smoke Test for Service: $SERVICE against Target: $TARGET"

svc_prefix() {
  case "$1" in
    product) echo /api/v1/products ;;
    order) echo /api/v1/orders ;;
    inventory) echo /api/v1/inventory ;;
    noti) echo /api/v1/notifications ;;
    payment) echo /api/v1/payments ;;
    client) echo / ;;
    *) echo /api/v1/products ;;
  esac
}

curl_retry() {
  local url="$1"
  local method="${2:-GET}"
  local body="${3:-}"
  local tries=0
  while [ $tries -lt 10 ]; do
    if [ -n "$body" ]; then
      RESP=$(curl -sS -H "Host: dev.go-micro.local" -X "$method" "$url" -H "Content-Type: application/json" -d "$body") && { echo "$RESP"; return 0; }
    else
      RESP=$(curl -sS -H "Host: dev.go-micro.local" -X "$method" "$url") && { echo "$RESP"; return 0; }
    fi
    tries=$((tries+1))
    sleep 3
  done
  return 1
}

fail() { echo "[FAIL] $1"; echo "[RAW ] $2"; exit 1; }
assert_field() {
  local label="$1" value="$2" body="$3"
  [ -n "$value" ] || fail "$label missing or empty" "$body"
}
assert_contains() {
  local label="$1" pattern="$2" body="$3"
  echo "$body" | grep -qF "$pattern" || fail "$label not found (expected '$pattern')" "$body"
}
assert_any_contains() {
  local label="$1" body="$2"; shift 2
  local ok=1
  for p in "$@"; do
    if echo "$body" | grep -qF "$p"; then
      ok=0
      break
    fi
  done
  [ $ok -eq 0 ] || fail "$label none matched: $*" "$body"
}

case "$SERVICE" in
  product)
    BASE="http://${TARGET}$(svc_prefix "$SERVICE")"
    NAME="canary-smoke-${RANDOM}"
    CREATE_BODY=$(curl_retry "$BASE/products" "POST" "{\"name\":\"$NAME\",\"description\":\"canary-smoke\",\"price\":11.11}")
    echo "[DBG] product create: $CREATE_BODY"
    PRODUCT_ID=$(echo "$CREATE_BODY" | sed -n 's/.*"id":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
    assert_field "product.id" "$PRODUCT_ID" "$CREATE_BODY"
    assert_contains "product.name" "$NAME" "$CREATE_BODY"
    assert_contains "product.price" "11.11" "$CREATE_BODY"
    GET_BODY=$(curl_retry "$BASE/products/$PRODUCT_ID")
    echo "[DBG] product get: $GET_BODY"
    assert_contains "product.get.id" "\"id\":$PRODUCT_ID" "$GET_BODY"
    ;;
  inventory)
    BASE="http://${TARGET}$(svc_prefix "$SERVICE")"
    PID=$((1000 + RANDOM % 9000))
    CREATE_BODY=$(curl -sS -H "Host: dev.go-micro.local" -X POST "$BASE/inventory" -H "Content-Type: application/json" -d "{\"product_id\":$PID,\"quantity\":20,\"sku\":\"SKU-$PID\",\"location\":\"A1\"}")
    echo "[DBG] inventory create: $CREATE_BODY"
    INV_ID=$(echo "$CREATE_BODY" | sed -n 's/.*"id":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
    assert_field "inventory.id" "$INV_ID" "$CREATE_BODY"
    assert_contains "inventory.quantity" "\"quantity\":20" "$CREATE_BODY"
    assert_contains "inventory.sku" "SKU-$PID" "$CREATE_BODY"
    ;;
  order)
    # Seed product/inventory qua TARGET (arg2), không dùng hostname K8s — Jenkins/agent ngoài namespace không resolve được product/inventory.
    P_BASE="http://${TARGET}/api/v1/products"
    I_BASE="http://${TARGET}/api/v1/inventory"
    O_BASE="http://${TARGET}$(svc_prefix "$SERVICE")"
    PID=$(( $(date +%s) + RANDOM ))
    P_CREATE=$(curl_retry "$P_BASE/products" "POST" "{\"name\":\"order-pre-$PID\",\"description\":\"seed\",\"price\":15.5}")
    echo "[DBG] order seed product: $P_CREATE"
    REAL_PID=$(echo "$P_CREATE" | sed -n 's/.*"id":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
    assert_field "order.seed_product_id" "$REAL_PID" "$P_CREATE"
    curl_retry "$I_BASE/inventory" "POST" "{\"product_id\":$REAL_PID,\"quantity\":30,\"sku\":\"OSKU-$PID\",\"location\":\"B2\"}" >/dev/null
    ORDER_BODY=$(curl_retry "$O_BASE/orders" "POST" "{\"customer_id\":1,\"product_id\":$REAL_PID,\"quantity\":1,\"total_price\":15.5}")
    echo "[DBG] order create: $ORDER_BODY"
    ORDER_ID=$(echo "$ORDER_BODY" | sed -n 's/.*"id":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
    assert_field "order.id" "$ORDER_ID" "$ORDER_BODY"
    assert_contains "order.customer_id" "\"customer_id\":1" "$ORDER_BODY"
    assert_contains "order.product_id" "\"product_id\":$REAL_PID" "$ORDER_BODY"
    ;;
  payment)
    BASE="http://${TARGET}$(svc_prefix "$SERVICE")"
    PAY_BODY=$(curl_retry "$BASE/payments/" "POST" '{"order_id":9001,"customer_id":1,"amount":10.5,"currency":"usd"}')
    echo "[DBG] payment create: $PAY_BODY"
    assert_contains "payment.key" "\"payment\"" "$PAY_BODY"
    assert_contains "payment.amount" "10.5" "$PAY_BODY"
    assert_contains "payment.currency" "usd" "$PAY_BODY"
    ;;
  noti)
    BASE="http://${TARGET}$(svc_prefix "$SERVICE")"
    NOTI_BODY=$(curl -sS -H "Host: dev.go-micro.local" -X POST "$BASE/notifications" -H "Content-Type: application/json" -d '{"order_id":9001,"customer_id":1,"message":"canary smoke","status":"pending"}')
    echo "[DBG] noti create: $NOTI_BODY"
    NOTI_ID=$(echo "$NOTI_BODY" | sed -n 's/.*"id":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
    assert_field "noti.id" "$NOTI_ID" "$NOTI_BODY"
    assert_contains "noti.status" "pending" "$NOTI_BODY"
    assert_contains "noti.order_id" "9001" "$NOTI_BODY"
    ;;
  *)
    echo "SKIP: no business-smoke profile for $SERVICE"
    ;;
esac
echo "PASSED: business smoke for $SERVICE"
