#!/bin/sh
set -e

# Usage: ./run.sh <service-name> <target-url>
SERVICE="${1:-product}"
TARGET="${2:-localhost}"

echo "Running Dependency Check for Service: $SERVICE against Target: $TARGET"

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

case "$SERVICE" in
  product)
    BASE="http://${TARGET}$(svc_prefix "$SERVICE")"

    # 1. GET /products — list phải là JSON array
    LIST_BODY=$(curl_retry "$BASE/products")
    echo "[DBG] product list: $LIST_BODY"
    echo "$LIST_BODY" | grep -qE '^\[|^null' || fail "product.list not a JSON array or null" "$LIST_BODY"

    # 2. POST /products — tạo mới để test CRUD
    PNAME="dep-prod-${RANDOM}"
    CREATE_BODY=$(curl_retry "$BASE/products" "POST" "{\"name\":\"$PNAME\",\"description\":\"dep-check\",\"price\":55.5}")
    echo "[DBG] product dep create: $CREATE_BODY"
    PROD_ID=$(echo "$CREATE_BODY" | sed -n 's/.*"id":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
    assert_field "product.dep.id" "$PROD_ID" "$CREATE_BODY"

    # 3. GET /products/:id
    GET_BODY=$(curl_retry "$BASE/products/$PROD_ID")
    echo "[DBG] product dep get: $GET_BODY"
    assert_contains "product.dep.get.id" "\"id\":$PROD_ID" "$GET_BODY"
    assert_contains "product.dep.get.price" "55.5" "$GET_BODY"

    # 4. PUT /products/:id — update price
    PUT_BODY=$(curl_retry "$BASE/products/$PROD_ID" "PUT" "{\"name\":\"$PNAME-upd\",\"description\":\"updated\",\"price\":77.7}")
    echo "[DBG] product dep put: $PUT_BODY"
    assert_contains "product.dep.put.id" "\"id\":$PROD_ID" "$PUT_BODY"
    assert_contains "product.dep.put.price" "77.7" "$PUT_BODY"

    # 5. DELETE /products/:id
    DEL_BODY=$(curl_retry "$BASE/products/$PROD_ID" "DELETE")
    echo "[DBG] product dep delete: $DEL_BODY"
    assert_contains "product.dep.delete" "deleted successfully" "$DEL_BODY"
    ;;
  inventory)
    BASE="http://${TARGET}$(svc_prefix "$SERVICE")"
    PID=$((3000 + RANDOM % 9000))

    # 1. POST /inventory — tạo mới
    CREATE_BODY=$(curl -sS -H "Host: dev.go-micro.local" -X POST "$BASE/inventory" -H "Content-Type: application/json" -d "{\"product_id\":$PID,\"quantity\":9,\"sku\":\"DSKU-$PID\",\"location\":\"C3\"}")
    echo "[DBG] inventory dep create: $CREATE_BODY"
    INV_ID=$(echo "$CREATE_BODY" | sed -n 's/.*"id":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
    assert_field "inventory.dep.id" "$INV_ID" "$CREATE_BODY"
    assert_contains "inventory.dep.quantity" "\"quantity\":9" "$CREATE_BODY"
    assert_contains "inventory.dep.sku" "DSKU-$PID" "$CREATE_BODY"

    # 2. GET /inventory/:id
    GET_BODY=$(curl -sS -H "Host: dev.go-micro.local" "$BASE/inventory/$INV_ID")
    echo "[DBG] inventory dep get: $GET_BODY"
    assert_contains "inventory.dep.get.id" "\"id\":$INV_ID" "$GET_BODY"
    assert_contains "inventory.dep.get.location" "C3" "$GET_BODY"

    # 3. POST /inventory/check — available (qty=9 >= 1)
    CHECK_OK=$(curl -sS -H "Host: dev.go-micro.local" -X POST "$BASE/inventory/check" -H "Content-Type: application/json" -d "{\"product_id\":$PID,\"quantity\":1}")
    echo "[DBG] inventory dep check ok: $CHECK_OK"
    assert_contains "inventory.dep.check.available" "\"is_available\":true" "$CHECK_OK"

    # 4. POST /inventory/check — not available (qty=9 < 999)
    CHECK_FAIL=$(curl -sS -H "Host: dev.go-micro.local" -X POST "$BASE/inventory/check" -H "Content-Type: application/json" -d "{\"product_id\":$PID,\"quantity\":999}")
    echo "[DBG] inventory dep check fail: $CHECK_FAIL"
    assert_contains "inventory.dep.check.not_available" "\"is_available\":false" "$CHECK_FAIL"

    # 5. PUT /inventory/:id — update quantity
    PUT_BODY=$(curl -sS -H "Host: dev.go-micro.local" -X PUT "$BASE/inventory/$INV_ID" -H "Content-Type: application/json" -d "{\"product_id\":$PID,\"quantity\":50,\"sku\":\"DSKU-$PID-upd\",\"location\":\"Z9\"}")
    echo "[DBG] inventory dep put: $PUT_BODY"
    assert_contains "inventory.dep.put.quantity" "\"quantity\":50" "$PUT_BODY"
    assert_contains "inventory.dep.put.location" "Z9" "$PUT_BODY"

    # 6. DELETE /inventory/:id
    DEL_BODY=$(curl -sS -H "Host: dev.go-micro.local" -X DELETE "$BASE/inventory/$INV_ID")
    echo "[DBG] inventory dep delete: $DEL_BODY"
    assert_contains "inventory.dep.delete" "deleted successfully" "$DEL_BODY"
    ;;
  order)
    # Cùng TARGET với O_BASE — curl từ Jenkins jenkins/* namespace tới service IP:port, không dùng DNS pod product/inventory trong microservices-dev.
    P_BASE="http://${TARGET}/api/v1/products"
    I_BASE="http://${TARGET}/api/v1/inventory"
    O_BASE="http://${TARGET}$(svc_prefix "$SERVICE")"
    PID=$(( $(date +%s) + RANDOM ))

    # 1. Seed: tạo product + inventory (quantity=25)
    P_CREATE=$(curl_retry "$P_BASE/products" "POST" "{\"name\":\"dep-pre-$PID\",\"description\":\"seed\",\"price\":21.5}")
    echo "[DBG] order dep seed product: $P_CREATE"
    REAL_PID=$(echo "$P_CREATE" | sed -n 's/.*\"id\":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
    assert_field "order.dep.seed_product_id" "$REAL_PID" "$P_CREATE"
    curl_retry "$I_BASE/inventory" "POST" "{\"product_id\":$REAL_PID,\"quantity\":25,\"sku\":\"ODSKU-$PID\",\"location\":\"D4\"}" >/dev/null

    # 2. Test: inventory check FAIL (quantity=99999 > 25 available)
    INV_FAIL_STATUS=$(curl -sS -H "Host: dev.go-micro.local" -o /dev/null -w "%{http_code}" -X POST "$O_BASE/orders" \
      -H "Content-Type: application/json" \
      -d "{\"customer_id\":1,\"product_id\":$REAL_PID,\"quantity\":99999,\"total_price\":99.9}")
    [ "$INV_FAIL_STATUS" = "400" ] || fail "order.dep.inv_check_fail expected HTTP 400, got $INV_FAIL_STATUS" "inventory should reject qty=99999"
    echo "[DBG] order dep inv_check_fail: HTTP $INV_FAIL_STATUS (expected 400) OK"

    # 3. POST /orders — tạo order hợp lệ
    ORDER_BODY=$(curl_retry "$O_BASE/orders" "POST" "{\"customer_id\":1,\"product_id\":$REAL_PID,\"quantity\":1,\"total_price\":21.5}")
    echo "[DBG] order dep create: $ORDER_BODY"
    ORDER_ID=$(echo "$ORDER_BODY" | sed -n 's/.*\"id\":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
    assert_field "order.dep.id" "$ORDER_ID" "$ORDER_BODY"
    assert_contains "order.dep.total_price" "21.5" "$ORDER_BODY"
    assert_contains "order.dep.status" "\"status\":\"pending\"" "$ORDER_BODY"

    # 4. GET /orders — list phải chứa order vừa tạo
    ORDER_LIST=$(curl_retry "$O_BASE/orders")
    echo "[DBG] order dep list: $ORDER_LIST"
    assert_contains "order.dep.list.id" "\"id\":$ORDER_ID" "$ORDER_LIST"

    # 5. GET /orders/:id — lấy đúng order theo ID
    GET_BODY=$(curl -sS -H "Host: dev.go-micro.local" "$O_BASE/orders/$ORDER_ID")
    echo "[DBG] order dep get: $GET_BODY"
    assert_contains "order.dep.get.id" "\"id\":$ORDER_ID" "$GET_BODY"
    assert_contains "order.dep.get.customer_id" "\"customer_id\":1" "$GET_BODY"
    assert_contains "order.dep.get.product_id" "\"product_id\":$REAL_PID" "$GET_BODY"

    # 6. PATCH /orders/:id/status — đổi status sang processing
    PATCH_BODY=$(curl -sS -H "Host: dev.go-micro.local" -X PATCH "$O_BASE/orders/$ORDER_ID/status" \
      -H "Content-Type: application/json" -d '{"status":"processing"}')
    echo "[DBG] order dep patch status: $PATCH_BODY"
    assert_contains "order.dep.patch.order_id" "\"order_id\":$ORDER_ID" "$PATCH_BODY"
    assert_contains "order.dep.patch.status" "\"status\":\"processing\"" "$PATCH_BODY"

    # 7. PUT /orders/:id — update quantity và total_price
    PUT_BODY=$(curl -sS -H "Host: dev.go-micro.local" -X PUT "$O_BASE/orders/$ORDER_ID" \
      -H "Content-Type: application/json" \
      -d "{\"customer_id\":1,\"product_id\":$REAL_PID,\"quantity\":2,\"total_price\":43.0,\"status\":\"processing\"}")
    echo "[DBG] order dep put: $PUT_BODY"
    assert_contains "order.dep.put.id" "\"id\":$ORDER_ID" "$PUT_BODY"
    assert_contains "order.dep.put.quantity" "\"quantity\":2" "$PUT_BODY"

    # 8. POST /orders/with-payment — order path tích hợp payment
    WITH_PAY=$(curl -sS -H "Host: dev.go-micro.local" -X POST "$O_BASE/orders/with-payment" \
      -H "Content-Type: application/json" \
      -d "{\"customer_id\":1,\"product_id\":$REAL_PID,\"quantity\":1,\"total_price\":21.5,\"currency\":\"usd\"}")
    echo "[DBG] order dep with-payment: $WITH_PAY"
    assert_contains "order.dep.with_payment.order" "\"order\"" "$WITH_PAY"
    if ! echo "$WITH_PAY" | grep -qF "\"payment\"" && ! echo "$WITH_PAY" | grep -qF "\"payment_error\""; then
      fail "order.dep.with_payment.result none matched: \"payment\" or \"payment_error\"" "$WITH_PAY"
    fi

    # 9. POST /orders/batch — xử lý batch tối thiểu
    BATCH_BODY=$(curl -sS -H "Host: dev.go-micro.local" -X POST "$O_BASE/orders/batch" \
      -H "Content-Type: application/json" \
      -d "[{\"customer_id\":1,\"product_id\":$REAL_PID,\"quantity\":1,\"total_price\":21.5}]")
    echo "[DBG] order dep batch: $BATCH_BODY"
    assert_contains "order.dep.batch.total_orders" "\"total_orders\":1" "$BATCH_BODY"
    assert_contains "order.dep.batch.successful" "\"successful\":1" "$BATCH_BODY"

    # 10. DELETE /orders/:id — xóa order, verify response
    DEL_BODY=$(curl -sS -H "Host: dev.go-micro.local" -X DELETE "$O_BASE/orders/$ORDER_ID")
    echo "[DBG] order dep delete: $DEL_BODY"
    assert_contains "order.dep.delete" "deleted successfully" "$DEL_BODY"
    ;;
  payment)
    BASE="http://${TARGET}$(svc_prefix "$SERVICE")"
    PAY_ORDER_ID=$((5000 + RANDOM % 9000))

    # 1. POST /payments/ — tạo payment
    PAY_CREATE=$(curl -sS -H "Host: dev.go-micro.local" -X POST "$BASE/payments/" -H "Content-Type: application/json" -d "{\"order_id\":$PAY_ORDER_ID,\"customer_id\":1,\"amount\":12.34,\"currency\":\"usd\"}")
    echo "[DBG] payment dep create: $PAY_CREATE"
    PAY_ID=$(echo "$PAY_CREATE" | sed -n 's/.*"id":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
    assert_field "payment.dep.id" "$PAY_ID" "$PAY_CREATE"
    assert_contains "payment.dep.create.order_id" "\"order_id\":$PAY_ORDER_ID" "$PAY_CREATE"

    # 2. GET /payments/order/:orderId
    BY_ORDER=$(curl -sS -H "Host: dev.go-micro.local" "$BASE/payments/order/$PAY_ORDER_ID")
    echo "[DBG] payment dep by_order: $BY_ORDER"
    assert_contains "payment.dep.order_id" "\"order_id\":$PAY_ORDER_ID" "$BY_ORDER"
    assert_contains "payment.dep.amount" "12.34" "$BY_ORDER"
    assert_contains "payment.dep.currency" "usd" "$BY_ORDER"

    # 3. GET /payments/:id
    BY_ID=$(curl -sS -H "Host: dev.go-micro.local" "$BASE/payments/$PAY_ID")
    echo "[DBG] payment dep by_id: $BY_ID"
    assert_contains "payment.dep.get.id" "\"id\":$PAY_ID" "$BY_ID"
    assert_contains "payment.dep.get.amount" "12.34" "$BY_ID"
    ;;
  noti)
    BASE="http://${TARGET}$(svc_prefix "$SERVICE")"
    CUST_ID=$((100 + RANDOM % 900))
    ORDER_ID=$((7000 + RANDOM % 1000))

    # 1. POST /notifications — tạo mới
    CREATE_BODY=$(curl -sS -H "Host: dev.go-micro.local" -X POST "$BASE/notifications" -H "Content-Type: application/json" \
      -d "{\"order_id\":$ORDER_ID,\"customer_id\":$CUST_ID,\"message\":\"dep check\",\"status\":\"pending\"}")
    echo "[DBG] noti dep create: $CREATE_BODY"
    NOTI_ID=$(echo "$CREATE_BODY" | sed -n 's/.*"id":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
    assert_field "noti.dep.id" "$NOTI_ID" "$CREATE_BODY"
    assert_contains "noti.dep.status" "pending" "$CREATE_BODY"
    assert_contains "noti.dep.order_id" "\"order_id\":$ORDER_ID" "$CREATE_BODY"

    # 2. GET /notifications/:id
    GET_BODY=$(curl -sS -H "Host: dev.go-micro.local" "$BASE/notifications/$NOTI_ID")
    echo "[DBG] noti dep get: $GET_BODY"
    assert_contains "noti.dep.get.id" "\"id\":$NOTI_ID" "$GET_BODY"
    assert_contains "noti.dep.get.customer_id" "\"customer_id\":$CUST_ID" "$GET_BODY"

    # 3. GET /notifications — list
    LIST_BODY=$(curl -sS -H "Host: dev.go-micro.local" "$BASE/notifications")
    echo "[DBG] noti dep list: $LIST_BODY"
    assert_contains "noti.dep.list.id" "\"id\":$NOTI_ID" "$LIST_BODY"

    # 4. GET /notifications/customer/:customerId
    CUST_LIST=$(curl -sS -H "Host: dev.go-micro.local" "$BASE/notifications/customer/$CUST_ID")
    echo "[DBG] noti dep cust_list: $CUST_LIST"
    assert_contains "noti.dep.cust.id" "\"id\":$NOTI_ID" "$CUST_LIST"

    # 5. POST /notifications/order-status
    OS_BODY=$(curl -sS -H "Host: dev.go-micro.local" -X POST "$BASE/notifications/order-status" -H "Content-Type: application/json" \
      -d "{\"order_id\":$ORDER_ID,\"customer_id\":$CUST_ID,\"status\":\"processing\"}")
    echo "[DBG] noti dep order-status: $OS_BODY"
    assert_contains "noti.dep.order_status.message" "Order status notification created" "$OS_BODY"
    OS_NID=$(echo "$OS_BODY" | sed -n 's/.*"notification_id":[[:space:]]*\([0-9][0-9]*\).*/\1/p')
    assert_field "noti.dep.order_status.notification_id" "$OS_NID" "$OS_BODY"

    # 6. PUT /notifications/:id/deliver
    DELIVER=$(curl -sS -H "Host: dev.go-micro.local" -X PUT "$BASE/notifications/$NOTI_ID/deliver")
    echo "[DBG] noti dep deliver: $DELIVER"
    assert_contains "noti.dep.deliver" "delivered" "$DELIVER"
    ;;
  *)
    echo "SKIP: no dependency profile for $SERVICE"
    ;;
esac
echo "PASSED: dependency check for $SERVICE"
