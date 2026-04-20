# Kind setup for go-micro

Platform flow is the same as your old project: `management -> Argo CD -> workload clusters`.

Workload shape is different:
- old project: monolithic (`backend` + `database`)
- this project: microservices (`api-gateway`, `product`, `inventory`, `order`, `payment`, `noti`, `client` + DB services)

Run all commands from repo root:

```bash
cd ~/Downloads/go-micro
```

Argo CD runs only on `kind-management`.
Host API endpoints:
- management: `https://127.0.0.1:33443`
- dev: `https://127.0.0.1:30443`
- staging: `https://127.0.0.1:32443`
- prod: `https://127.0.0.1:31443`

## 1) Daily recreate flow (after reboot)

### 1.1 Delete old clusters (if any)

```bash
kind delete cluster --name management
kind delete cluster --name dev
kind delete cluster --name staging
kind delete cluster --name prod
```

### 1.2 Recreate clusters and bootstrap networking

Create `management` first, fix kubeconfig server, install Cilium, then create workload clusters.

```bash
kind create cluster --name management --config kind/management-kind-config.yaml
kubectl config use-context kind-management
kubectl config set-cluster kind-management --server=https://127.0.0.1:33443

helm repo add cilium https://helm.cilium.io 2>/dev/null || true
helm repo update
helm upgrade --install cilium cilium/cilium -n kube-system --create-namespace \
  --version 1.19.2 \
  --wait --timeout 15m

kind create cluster --name dev --config kind/dev-kind-config.yaml
kind create cluster --name staging --config kind/staging-kind-config.yaml
kind create cluster --name prod --config kind/prod-kind-config.yaml

kubectl config set-cluster kind-dev --server=https://127.0.0.1:30443
kubectl config set-cluster kind-staging --server=https://127.0.0.1:32443
kubectl config set-cluster kind-prod --server=https://127.0.0.1:31443

kubectl config get-contexts
```

If you hit TLS or `0.0.0.0` endpoint issues, run `kubectl config set-cluster ...` again for all four contexts.

### 1.3 Install Argo CD on management

```bash
kubectl config use-context kind-management
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd wait --for=condition=Ready pods --all --timeout=300s
```

Get admin password and run port-forward:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Reset stale CLI token after Argo recreation:

```bash
rm -rf ~/.argocd
PASS=$(kubectl --context kind-management -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --insecure --username admin --password "$PASS"
```

## 2) Register workload clusters in Argo CD

```bash
kubectl --context kind-dev apply -f kind/dev-argocd-manager.yaml
kubectl --context kind-staging apply -f kind/staging-argocd-manager.yaml
kubectl --context kind-prod apply -f kind/prod-argocd-manager.yaml
sleep 5

DEV_TOKEN=$(kubectl --context kind-dev get secret argocd-manager-long-lived-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)
STAGING_TOKEN=$(kubectl --context kind-staging get secret argocd-manager-long-lived-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)
PROD_TOKEN=$(kubectl --context kind-prod get secret argocd-manager-long-lived-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)

DEV_IP=$(docker inspect dev-control-plane --format '{{.NetworkSettings.Networks.kind.IPAddress}}')
STAGING_IP=$(docker inspect staging-control-plane --format '{{.NetworkSettings.Networks.kind.IPAddress}}')
PROD_IP=$(docker inspect prod-control-plane --format '{{.NetworkSettings.Networks.kind.IPAddress}}')

kubectl --context kind-management create secret generic cluster-dev -n argocd \
  --from-literal=name=dev \
  --from-literal=server=https://$DEV_IP:6443 \
  --from-literal=config="{\"bearerToken\":\"$DEV_TOKEN\",\"tlsClientConfig\":{\"insecure\":true}}"
kubectl --context kind-management label secret cluster-dev -n argocd argocd.argoproj.io/secret-type=cluster --overwrite

kubectl --context kind-management create secret generic cluster-staging -n argocd \
  --from-literal=name=staging \
  --from-literal=server=https://$STAGING_IP:6443 \
  --from-literal=config="{\"bearerToken\":\"$STAGING_TOKEN\",\"tlsClientConfig\":{\"insecure\":true}}"
kubectl --context kind-management label secret cluster-staging -n argocd argocd.argoproj.io/secret-type=cluster --overwrite

kubectl --context kind-management create secret generic cluster-prod -n argocd \
  --from-literal=name=prod \
  --from-literal=server=https://$PROD_IP:6443 \
  --from-literal=config="{\"bearerToken\":\"$PROD_TOKEN\",\"tlsClientConfig\":{\"insecure\":true}}"
kubectl --context kind-management label secret cluster-prod -n argocd argocd.argoproj.io/secret-type=cluster --overwrite
```

## 3) Bootstrap GitOps apps

```bash
kubectl --context kind-management apply -f argocd/bootstrap/01-projects.yaml
kubectl --context kind-management apply -f argocd/bootstrap/02-dev-microservices-stack.yaml
kubectl --context kind-management apply -f argocd/bootstrap/03-staging-microservices-stack.yaml
kubectl --context kind-management apply -f argocd/bootstrap/04-prod-microservices-stack.yaml
```

## 4) External Secrets manifests (optional)

After ESO is installed on each workload cluster:

```bash
helm template external-secrets external-secrets/applications \
  -f external-secrets/applications/values.yaml \
  -f config/base/config.yaml \
  -f config/env/dev.yaml \
  | kubectl --context kind-dev apply -f -
```

Repeat for `staging` and `prod` with the corresponding env files.
