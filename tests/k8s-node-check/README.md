# K8s Node Check RBAC

This folder contains a pure-requests Kubernetes API check script (`run.py`) and the minimum RBAC needed for listing cluster nodes.

## Apply RBAC

If your Jenkins test pods run in `default` namespace:

```bash
kubectl --context kind-dev apply -f tests/k8s-node-check/rbac.yaml
```

If your test namespace is not `default`, replace namespace in manifest before apply:

```bash
NS=microservices-dev
sed "s/namespace: default/namespace: ${NS}/g" tests/k8s-node-check/rbac.yaml | kubectl --context kind-dev apply -f -
```

## Jenkins parameters

- `DEV_TEST_NAMESPACE`: namespace where pod tests are created.
- `DEV_TEST_SERVICE_ACCOUNT`: service account used by pod tests (default: `go-micro-test-runner`).

Ensure both values match the namespace/service account bound by RBAC above.
