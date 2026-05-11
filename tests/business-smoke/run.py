import sys
import os
import requests
import time
import random

def get_svc_prefix(service):
    prefixes = {
        "product": "/api/v1/products",
        "order": "/api/v1/orders",
        "inventory": "/api/v1/inventory",
        "noti": "/api/v1/notifications",
        "payment": "/api/v1/payments",
        "client": "/"
    }
    return prefixes.get(service, "/api/v1/products")

def curl_retry(url, method="GET", body=None, headers=None, retries=10, delay=3, use_canary=True):
    # Shallow copy to avoid modifying original headers dict across calls
    req_headers = dict(headers) if headers else {}
    if not use_canary and "X-Canary" in req_headers:
        del req_headers["X-Canary"]

    for i in range(retries):
        try:
            if method == "GET":
                resp = requests.get(url, headers=req_headers, timeout=10)
            elif method == "POST":
                resp = requests.post(url, headers=req_headers, json=body, timeout=10)
            elif method == "PUT":
                resp = requests.put(url, headers=req_headers, json=body, timeout=10)
            elif method == "DELETE":
                resp = requests.delete(url, headers=req_headers, timeout=10)
            elif method == "PATCH":
                resp = requests.patch(url, headers=req_headers, json=body, timeout=10)
            
            if resp.status_code < 400:
                return resp
            print(f"[RETRY {i+1}] Received status {resp.status_code}: {resp.text}")
        except Exception as e:
            print(f"[RETRY {i+1}] Error: {e}")
        
        time.sleep(delay)
    raise Exception(f"Failed to call {url} after {retries} retries")

def main():
    if len(sys.argv) < 3:
        print("Usage: python run.py <service-name> <target-url>")
        sys.exit(1)

    service = sys.argv[1]
    target = sys.argv[2]
    use_canary = os.getenv("CANARY_HEADER", "false").lower() == "true"

    headers = {
        "Host": "dev-go-micro.local",
        "Content-Type": "application/json"
    }
    if use_canary:
        headers["X-Canary"] = "true"
        print("[DBG] CANARY_HEADER enabled for business-smoke")

    print(f"--- Running Business Smoke Test for {service} against {target} ---")

    base_url = f"http://{target}{get_svc_prefix(service)}"

    try:
        if service == "product":
            name = f"canary-smoke-{random.randint(1000, 9999)}"
            body = {"name": name, "description": "canary-smoke", "price": 11.11}
            resp = curl_retry(f"{base_url}/products", method="POST", body=body, headers=headers)
            prod_id = resp.json().get('id')
            assert prod_id, "Product ID missing"
            assert resp.json().get('name') == name, "Name mismatch"
            assert resp.json().get('price') == 11.11, "Price mismatch"
            print(f"[DBG] product create: {prod_id}")

            resp = curl_retry(f"{base_url}/products/{prod_id}", headers=headers)
            assert resp.json().get('id') == prod_id, "Product ID mismatch on get"
            print("[DBG] product get passed")

        elif service == "inventory":
            pid = random.randint(1000, 9999)
            body = {"product_id": pid, "quantity": 20, "sku": f"SKU-{pid}", "location": "A1"}
            resp = curl_retry(f"{base_url}/inventory", method="POST", body=body, headers=headers)
            inv_id = resp.json().get('id')
            assert inv_id, "Inventory ID missing"
            assert resp.json().get('quantity') == 20, "Quantity mismatch"
            assert resp.json().get('sku') == f"SKU-{pid}", "SKU mismatch"
            print(f"[DBG] inventory create: {inv_id}")

        elif service == "order":
            p_base = f"http://{target}/api/v1/products"
            i_base = f"http://{target}/api/v1/inventory"
            o_base = f"http://{target}/api/v1/orders"
            pid = int(time.time()) + random.randint(1000, 9999)

            # Seed product (no_canary)
            p_body = {"name": f"order-pre-{pid}", "description": "seed", "price": 15.5}
            resp = curl_retry(f"{p_base}/products", method="POST", body=p_body, headers=headers, use_canary=False)
            real_pid = resp.json().get('id')
            assert real_pid, "Seed product ID missing"
            print(f"[DBG] order seed product: {real_pid}")

            # Seed inventory (no_canary)
            i_body = {"product_id": real_pid, "quantity": 30, "sku": f"OSKU-{pid}", "location": "B2"}
            resp = curl_retry(f"{i_base}/inventory", method="POST", body=i_body, headers=headers, use_canary=False)
            assert resp.json().get('product_id') == real_pid, "Inventory seed failed"
            print(f"[DBG] order seed inventory passed")

            # Wait for inventory available
            tries = 0
            while tries < 12:
                check_resp = requests.post(f"{i_base}/inventory/check", headers=headers, json={"product_id": real_pid, "quantity": 1})
                if check_resp.status_code < 400 and check_resp.json().get('is_available'):
                    print("[DBG] inventory check ready")
                    break
                tries += 1
                time.sleep(2)
            else:
                raise Exception("order.seed.inventory_not_available_after_retries")

            # Create order
            order_body = {"customer_id": 1, "product_id": real_pid, "quantity": 1, "total_price": 15.5}
            resp = curl_retry(f"{o_base}/orders", method="POST", body=order_body, headers=headers)
            order_id = resp.json().get('id')
            assert order_id, "Order ID missing"
            assert resp.json().get('customer_id') == 1, "Customer ID mismatch"
            assert resp.json().get('product_id') == real_pid, "Product ID mismatch"
            print(f"[DBG] order create: {order_id}")

        elif service == "payment":
            pay_body = {"order_id": 9001, "customer_id": 1, "amount": 10.5, "currency": "usd"}
            resp = curl_retry(f"{base_url}/payments/", method="POST", body=pay_body, headers=headers)
            assert resp.json().get('payment'), "Payment object missing"
            assert resp.json()['payment'].get('amount') == 10.5, "Amount mismatch"
            assert resp.json()['payment'].get('currency') == "usd", "Currency mismatch"
            print("[DBG] payment create passed")

        elif service == "noti":
            noti_body = {"order_id": 9001, "customer_id": 1, "message": "canary smoke", "status": "pending"}
            resp = curl_retry(f"{base_url}/notifications", method="POST", body=noti_body, headers=headers)
            noti_id = resp.json().get('id')
            assert noti_id, "Notification ID missing"
            assert resp.json().get('status') == "pending", "Status mismatch"
            assert resp.json().get('order_id') == 9001, "Order ID mismatch"
            print(f"[DBG] noti create: {noti_id}")

        else:
            print(f"SKIP: no business-smoke profile for {service}")

        print(f"PASSED: business smoke for {service}")

    except Exception as e:
        print(f"FAILED: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
