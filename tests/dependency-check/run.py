import sys
import os
import requests
import time
import random
import json

# Import our pure-requests K8s client
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'lib'))
try:
    from k8s_requests import K8sClient
except ImportError:
    # Fallback if lib is not found in path
    K8sClient = None

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

def curl_retry(url, method="GET", body=None, headers=None, retries=10, delay=3):
    for i in range(retries):
        try:
            if method == "GET":
                resp = requests.get(url, headers=headers, timeout=10)
            elif method == "POST":
                resp = requests.post(url, headers=headers, json=body, timeout=10)
            elif method == "PUT":
                resp = requests.put(url, headers=headers, json=body, timeout=10)
            elif method == "DELETE":
                resp = requests.delete(url, headers=headers, timeout=10)
            elif method == "PATCH":
                resp = requests.patch(url, headers=headers, json=body, timeout=10)
            
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
        "Host": "dev.go-micro.local",
        "Content-Type": "application/json"
    }
    if use_canary:
        headers["X-Canary"] = "true"
        print("[DBG] CANARY_HEADER enabled")

    print(f"--- Running Python Dependency Check for {service} against {target} ---")

    # Pure Request K8s API Check (Demonstrating Mentor's requirement)
    if K8sClient:
        try:
            client = K8sClient()
            # Just a simple node check to prove API access as requested by Mentor
            nodes = client.get("/api/v1/nodes")
            node_names = [n['metadata']['name'] for n in nodes.get('items', [])]
            print(f"[K8s API] Found nodes: {', '.join(node_names)}")
        except Exception as e:
            print(f"[K8s API] Warning: Could not get nodes (expected if running outside cluster): {e}")

    base_url = f"http://{target}{get_svc_prefix(service)}"

    try:
        if service == "product":
            # 1. GET /products
            resp = curl_retry(f"{base_url}/products", headers=headers)
            print(f"[DBG] product list OK: {len(resp.json())} items found")

            # 2. POST /products
            name = f"py-dep-{random.randint(1000, 9999)}"
            body = {"name": name, "description": "python-dep-check", "price": 99.99}
            resp = curl_retry(f"{base_url}/products", method="POST", body=body, headers=headers)
            product = resp.json()
            prod_id = product.get('id')
            assert prod_id, "Product ID missing"
            print(f"[DBG] product created with ID: {prod_id}")

            # 3. GET /products/:id
            resp = curl_retry(f"{base_url}/products/{prod_id}", headers=headers)
            assert resp.json().get('id') == prod_id, "ID mismatch"
            
            # 4. DELETE /products/:id
            resp = curl_retry(f"{base_url}/products/{prod_id}", method="DELETE", headers=headers)
            print(f"[DBG] product deleted: {resp.text}")

        elif service == "inventory":
            # Similar logic for inventory...
            pid = random.randint(10000, 99999)
            body = {"product_id": pid, "quantity": 100, "sku": f"PY-SKU-{pid}", "location": "PYTHON-ZONE"}
            resp = curl_retry(f"{base_url}/inventory", method="POST", body=body, headers=headers)
            inv_id = resp.json().get('id')
            assert inv_id, "Inventory ID missing"
            print(f"[DBG] inventory created: {inv_id}")
            
            # Check availability
            check_body = {"product_id": pid, "quantity": 50}
            resp = curl_retry(f"{base_url}/inventory/check", method="POST", body=check_body, headers=headers)
            assert resp.json().get('is_available') is True, "Should be available"
            print("[DBG] inventory check passed")

        elif service == "order":
            p_base = f"http://{target}/api/v1/products"
            i_base = f"http://{target}/api/v1/inventory"
            o_base = f"http://{target}/api/v1/orders"
            pid = random.randint(100000, 999999)

            # 1. Seed product
            p_body = {"name": f"dep-pre-{pid}", "description": "seed", "price": 21.5}
            resp = curl_retry(f"{p_base}/products", method="POST", body=p_body, headers={"Host": headers["Host"], "Content-Type": "application/json"})
            real_pid = resp.json().get('id')
            assert real_pid, "Seed product ID missing"
            print(f"[DBG] order dep seed product: {real_pid}")

            # 2. Seed inventory
            i_body = {"product_id": real_pid, "quantity": 25, "sku": f"ODSKU-{pid}", "location": "D4"}
            resp = curl_retry(f"{i_base}/inventory", method="POST", body=i_body, headers={"Host": headers["Host"], "Content-Type": "application/json"})
            assert resp.json().get('product_id') == real_pid, "Inventory seed failed"
            print(f"[DBG] order dep seed inventory passed")

            # Wait for inventory availability
            tries = 0
            while tries < 12:
                check_resp = requests.post(f"{i_base}/inventory/check", headers={"Host": headers["Host"], "Content-Type": "application/json"}, json={"product_id": real_pid, "quantity": 1})
                if check_resp.status_code < 400 and check_resp.json().get('is_available'):
                    print("[DBG] inventory ready for order")
                    break
                tries += 1
                time.sleep(2)
            else:
                raise Exception("order.dep.seed.inventory_not_available_after_retries")

            # 3. Test inventory check FAIL (quantity=99999)
            inv_fail_body = {"customer_id": 1, "product_id": real_pid, "quantity": 99999, "total_price": 99.9}
            resp = requests.post(f"{o_base}/orders", headers=headers, json=inv_fail_body)
            assert resp.status_code == 400, f"order.dep.inv_check_fail expected HTTP 400, got {resp.status_code}"
            print("[DBG] order dep inv_check_fail: HTTP 400 OK")

            # 4. POST /orders
            order_body = {"customer_id": 1, "product_id": real_pid, "quantity": 1, "total_price": 21.5}
            resp = curl_retry(f"{o_base}/orders", method="POST", body=order_body, headers=headers)
            order_id = resp.json().get('id')
            assert order_id, "Order ID missing"
            print(f"[DBG] order dep create: {order_id}")

            # 5. GET /orders
            resp = curl_retry(f"{o_base}/orders", headers=headers)
            assert any(o.get('id') == order_id for o in resp.json()), "Created order not in list"
            print("[DBG] order dep list passed")

            # 6. GET /orders/:id
            resp = curl_retry(f"{o_base}/orders/{order_id}", headers=headers)
            assert resp.json().get('id') == order_id, "Order get ID mismatch"
            print("[DBG] order dep get passed")

            # 7. PATCH /orders/:id/status
            resp = curl_retry(f"{o_base}/orders/{order_id}/status", method="PATCH", body={"status": "processing"}, headers=headers)
            assert resp.json().get('status') == "processing", "Order status patch failed"
            print("[DBG] order dep patch status passed")

            # 8. PUT /orders/:id
            put_body = {"customer_id": 1, "product_id": real_pid, "quantity": 2, "total_price": 43.0, "status": "processing"}
            resp = curl_retry(f"{o_base}/orders/{order_id}", method="PUT", body=put_body, headers=headers)
            assert resp.json().get('quantity') == 2, "Order put failed"
            print("[DBG] order dep put passed")

            # 9. DELETE /orders/:id
            resp = curl_retry(f"{o_base}/orders/{order_id}", method="DELETE", headers=headers)
            print("[DBG] order dep delete passed")

        elif service == "payment":
            pay_order_id = random.randint(5000, 9999)
            # 1. POST /payments/
            pay_body = {"order_id": pay_order_id, "customer_id": 1, "amount": 12.34, "currency": "usd"}
            resp = curl_retry(f"{base_url}/payments/", method="POST", body=pay_body, headers=headers)
            pay_id = resp.json().get('id')
            assert pay_id, "Payment ID missing"
            print(f"[DBG] payment dep create: {pay_id}")

            # 2. GET /payments/order/:orderId
            resp = curl_retry(f"{base_url}/payments/order/{pay_order_id}", headers=headers)
            assert resp.json().get('amount') == 12.34, "Payment by order mismatch"
            print("[DBG] payment dep by_order passed")

            # 3. GET /payments/:id
            resp = curl_retry(f"{base_url}/payments/{pay_id}", headers=headers)
            assert resp.json().get('id') == pay_id, "Payment get mismatch"
            print("[DBG] payment dep by_id passed")

        elif service == "noti":
            cust_id = random.randint(100, 999)
            order_id = random.randint(7000, 9999)

            # 1. POST /notifications
            noti_body = {"order_id": order_id, "customer_id": cust_id, "message": "dep check", "status": "pending"}
            resp = curl_retry(f"{base_url}/notifications", method="POST", body=noti_body, headers=headers)
            noti_id = resp.json().get('id')
            assert noti_id, "Notification ID missing"
            print(f"[DBG] noti dep create: {noti_id}")

            # 2. GET /notifications/:id
            resp = curl_retry(f"{base_url}/notifications/{noti_id}", headers=headers)
            assert resp.json().get('id') == noti_id, "Notification get mismatch"
            print("[DBG] noti dep get passed")

            # 3. GET /notifications
            resp = curl_retry(f"{base_url}/notifications", headers=headers)
            assert any(n.get('id') == noti_id for n in resp.json()), "Notification not in list"
            print("[DBG] noti dep list passed")

            # 4. PUT /notifications/:id/deliver
            resp = curl_retry(f"{base_url}/notifications/{noti_id}/deliver", method="PUT", headers=headers)
            assert "delivered" in resp.text, "Notification deliver failed"
            print("[DBG] noti dep deliver passed")

        else:
            print(f"SKIP: no dependency profile for {service}")

    except Exception as e:
        print(f"FAILED: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
