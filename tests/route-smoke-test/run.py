import sys
import requests

def main():
    if len(sys.argv) < 4:
        print("Usage: python run.py <hostname> <path-prefix> <mode: standard|canary|preview> [resolve-ip]")
        sys.exit(1)

    host = sys.argv[1]
    prefix = sys.argv[2]
    mode = sys.argv[3]
    resolve_ip = sys.argv[4] if len(sys.argv) > 4 else None

    print(f"Running Route Smoke Test for Mode: {mode}, Host: {host}, Prefix: {prefix} Resolve: {resolve_ip or 'DNS'}")

    headers = {"Host": host}
    expected_served_by = None

    if mode == "standard":
        pass
    elif mode == "canary":
        headers["X-Canary"] = "true"
        expected_served_by = "canary"
    elif mode == "preview":
        headers["X-Preview"] = "true"
        expected_served_by = "preview"
    else:
        print(f"Unknown mode: {mode}")
        sys.exit(1)

    # In a real CI environment, GATEWAY would point to the LoadBalancer IP
    if resolve_ip:
        url = f"http://{resolve_ip}{prefix}/health"
    else:
        url = f"http://{host}{prefix}/health"

    print(f"Requesting: {url} mode={mode} with headers={headers}")

    try:
        response = requests.get(url, headers=headers, timeout=10)
    except Exception as e:
        print(f"FAILED: request could not connect to {url}")
        print(f"Error: {e}")
        sys.exit(1)

    if response.status_code != 200:
        print(f"FAILED: health returned {response.status_code}")
        print(f"Response: {response.text}")
        sys.exit(1)

    if expected_served_by:
        # requests converts headers to case-insensitive dict
        served_by = response.headers.get("X-Served-By")
        if served_by != expected_served_by:
            print(f"FAILED: request was not served by {expected_served_by} (Got: '{served_by}')")
            sys.exit(1)

    print(f"PASSED: Route Gate ({mode})")

if __name__ == "__main__":
    main()
