import sys
import requests

def get_svc_port(service):
    ports = {
        "product": 8080,
        "order": 8081,
        "inventory": 8082,
        "noti": 8083,
        "payment": 8084,
        "client": 80
    }
    return ports.get(service, 8080)

def get_probe_path(service):
    if service == "client":
        return "/"
    elif service == "order":
        return "/orders"
    return "/health"

def main():
    if len(sys.argv) < 3:
        print("Usage: python run.py <service-name> <target-host>")
        sys.exit(1)

    service = sys.argv[1]
    target = sys.argv[2]

    print(f"Target smoke: service={service} target={target}")

    port = get_svc_port(service)
    path_part = get_probe_path(service)
    url = f"http://{target}:{port}{path_part}"

    try:
        response = requests.get(url, timeout=10)
    except Exception as e:
        print(f"FAILED: target health request failed at {url}")
        print(f"Error: {e}")
        sys.exit(1)

    if response.status_code != 200:
        print(f"FAILED: target health returned {response.status_code} at {url}")
        sys.exit(1)

    print(f"PASSED: target smoke ({url})")

if __name__ == "__main__":
    main()
