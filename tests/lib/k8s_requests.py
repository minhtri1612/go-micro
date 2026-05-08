import json
import os
import time

import requests


class K8sClient:
    """
    Kubernetes API client using only requests (no kubernetes-python SDK).
    """

    def __init__(
        self,
        api_server="https://kubernetes.default.svc",
        sa_path="/var/run/secrets/kubernetes.io/serviceaccount",
        timeout=10,
    ):
        self.api_server = os.getenv("K8S_API_SERVER", api_server).rstrip("/")
        self.sa_path = sa_path
        self.timeout = timeout
        self.token = self._load_token()
        self.verify = self._resolve_verify()
        self.headers = {
            "Accept": "application/json",
            "Content-Type": "application/json",
        }
        if self.token:
            self.headers["Authorization"] = f"Bearer {self.token}"

    def _load_token(self):
        token_path = f"{self.sa_path}/token"
        if os.path.exists(token_path):
            with open(token_path, "r", encoding="utf-8") as f:
                return f.read().strip()
        return os.getenv("K8S_TOKEN", "").strip()

    def _resolve_verify(self):
        ca_override = os.getenv("K8S_CA_CERT")
        if ca_override:
            return ca_override
        ca_path = f"{self.sa_path}/ca.crt"
        if os.path.exists(ca_path):
            return ca_path
        # Local/dev fallback when CA bundle is unavailable.
        return False

    def get(self, path, params=None):
        url = f"{self.api_server}{path}"
        response = requests.get(
            url,
            headers=self.headers,
            params=params,
            verify=self.verify,
            timeout=self.timeout,
        )
        response.raise_for_status()
        return response.json()

    def post(self, path, data=None):
        url = f"{self.api_server}{path}"
        response = requests.post(
            url,
            headers=self.headers,
            data=json.dumps(data),
            verify=self.verify,
            timeout=self.timeout,
        )
        response.raise_for_status()
        return response.json()

    def get_nodes(self):
        return self.get("/api/v1/nodes")

    def get_node_names(self):
        payload = self.get_nodes()
        return [item.get("metadata", {}).get("name", "") for item in payload.get("items", [])]

    def get_pods(self, namespace, label_selector=None):
        path = f"/api/v1/namespaces/{namespace}/pods"
        params = {}
        if label_selector:
            params["labelSelector"] = label_selector
        return self.get(path, params=params)

    def get_nodes(self):
        path = "/api/v1/nodes"
        return self.get(path)

    def is_pod_ready(self, pod_json):
        status = pod_json.get("status", {})
        if status.get("phase") != "Running":
            return False

        container_statuses = status.get("containerStatuses", [])
        if not container_statuses:
            return False
        return all(s.get("ready", False) for s in container_statuses)

    def wait_for_service_ready(self, namespace, service_label, timeout=300):
        start_time = time.time()
        print(f"Waiting for pods in {namespace} with label app={service_label}...")

        while time.time() - start_time < timeout:
            pods = self.get_pods(namespace, f"app={service_label}")
            items = pods.get("items", [])
            if items and all(self.is_pod_ready(p) for p in items):
                print(f"All pods for {service_label} are Ready.")
                return True
            time.sleep(5)

        raise TimeoutError(f"Timeout waiting for service {service_label} to be ready.")
