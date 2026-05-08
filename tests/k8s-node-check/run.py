import os
import sys

import requests

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "lib"))
from k8s_requests import K8sClient


def main():
    print("Running K8s API node check (pure requests)")
    client = K8sClient()

    try:
        nodes = client.get_nodes()
    except requests.HTTPError as exc:
        code = exc.response.status_code if exc.response is not None else "unknown"
        body = exc.response.text if exc.response is not None else str(exc)
        print(f"FAILED: cannot list nodes from Kubernetes API (status={code})")
        print(body)
        sys.exit(1)
    except Exception as exc:
        print(f"FAILED: cannot call Kubernetes API: {exc}")
        sys.exit(1)

    items = nodes.get("items", [])
    node_names = [n.get("metadata", {}).get("name", "") for n in items if n.get("metadata", {}).get("name")]

    if not node_names:
        print("FAILED: Kubernetes API returned no nodes")
        sys.exit(1)

    print(f"PASSED: found {len(node_names)} nodes")
    for name in node_names:
        print(f"- {name}")


if __name__ == "__main__":
    main()
