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
kubectl --context kind-management apply -f argocd/bootstrap/00-argocd-cm-health.yaml
kubectl --context kind-management -n argocd rollout restart statefulset/argocd-application-controller deployment/argocd-repo-server
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

### 1.4 Register workload clusters in Argo CD

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

### 1.5 Secrets for microservices (after cluster recreate)

`go-micro` needs DB secrets for `product`, `inventory`, `order`, `noti`, `payment`.

#### 1.5.1 External Secrets Operator + AWS Secrets Manager (recommended)

1) Install ESO on workload clusters (`kind-dev`, `kind-staging`, `kind-prod`):

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

for ctx in kind-dev kind-staging kind-prod; do
  helm upgrade --install external-secrets external-secrets/external-secrets \
    --version 0.19.2 \
    -n external-secrets --create-namespace \
    --kube-context "$ctx"
done
```

2) Wait webhook ready before applying `ClusterSecretStore` / `ExternalSecret`:

```bash
for ctx in kind-dev kind-staging kind-prod; do
  kubectl --context "$ctx" -n external-secrets rollout status deployment/external-secrets-webhook --timeout=300s
  kubectl --context "$ctx" -n external-secrets wait --for=condition=Ready pods --all --timeout=300s
done
```

3) Create `aws-credentials` secret for ESO auth on each workload cluster:

```bash
for ctx in kind-dev kind-staging kind-prod; do
  kubectl --context "$ctx" -n external-secrets create secret generic aws-credentials \
    --from-literal=access-key-id='YOUR_AWS_ACCESS_KEY_ID' \
    --from-literal=secret-access-key='YOUR_AWS_SECRET_ACCESS_KEY' \
    --dry-run=client -o yaml | kubectl --context "$ctx" apply -f -
done
```

4) Ensure target namespaces exist:

```bash
for ctx in kind-dev kind-staging kind-prod; do
  env=${ctx#kind-}
  kubectl --context "$ctx" create namespace "microservices-$env" --dry-run=client -o yaml | kubectl --context "$ctx" apply -f -
  kubectl --context "$ctx" create namespace "databases-$env" --dry-run=client -o yaml | kubectl --context "$ctx" apply -f -
done
```

5) Apply External Secrets manifests from this repo:

```bash
helm template external-secrets external-secrets/applications \
  -f external-secrets/applications/values.yaml \
  -f config/base/config.yaml \
  -f config/env/dev.yaml \
  | kubectl --context kind-dev apply -f -

helm template external-secrets external-secrets/applications \
  -f external-secrets/applications/values.yaml \
  -f config/base/config.yaml \
  -f config/env/staging.yaml \
  | kubectl --context kind-staging apply -f -

helm template external-secrets external-secrets/applications \
  -f external-secrets/applications/values.yaml \
  -f config/base/config.yaml \
  -f config/env/prod.yaml \
  | kubectl --context kind-prod apply -f -
```

6) Verify sync:

```bash
kubectl --context kind-dev get externalsecret,secret -A | rg "go-micro-|ExternalSecret"
kubectl --context kind-staging get externalsecret,secret -A | rg "go-micro-|ExternalSecret"
kubectl --context kind-prod get externalsecret,secret -A | rg "go-micro-|ExternalSecret"
```

#### 1.5.2 Static secrets with kubectl (when not using AWS/ESO)

If AWS is not available yet, create app secrets manually in workload namespaces:

```bash
kubectl --context kind-dev create namespace microservices-dev --dry-run=client -o yaml | kubectl --context kind-dev apply -f -
kubectl --context kind-dev -n microservices-dev create secret generic go-micro-product-secrets-dev \
  --from-literal=DB_USER=postgres --from-literal=DB_PASSWORD=localdev --from-literal=DB_NAME=product
kubectl --context kind-dev -n microservices-dev create secret generic go-micro-inventory-secrets-dev \
  --from-literal=DB_USER=postgres --from-literal=DB_PASSWORD=localdev --from-literal=DB_NAME=inventory
kubectl --context kind-dev -n microservices-dev create secret generic go-micro-order-secrets-dev \
  --from-literal=DB_USER=postgres --from-literal=DB_PASSWORD=localdev --from-literal=DB_NAME=order
kubectl --context kind-dev -n microservices-dev create secret generic go-micro-noti-secrets-dev \
  --from-literal=DB_USER=postgres --from-literal=DB_PASSWORD=localdev --from-literal=DB_NAME=notification
kubectl --context kind-dev -n microservices-dev create secret generic go-micro-payment-secrets-dev \
  --from-literal=DB_USER=postgres --from-literal=DB_PASSWORD=localdev --from-literal=DB_NAME=payment
```

Repeat for `kind-staging` and `kind-prod` using names from `config/env/staging.yaml` and `config/env/prod.yaml`.

### 1.6 Apply bootstrap and sync GitOps apps

```bash
kubectl --context kind-management apply -f argocd/bootstrap/01-projects.yaml
kubectl --context kind-management apply -f argocd/bootstrap/02-dev-microservices-stack.yaml
kubectl --context kind-management apply -f argocd/bootstrap/03-staging-microservices-stack.yaml
kubectl --context kind-management apply -f argocd/bootstrap/04-prod-microservices-stack.yaml
```

Sync order (important: sync projects first):

```bash
argocd app sync argocd/argocd-projects
sleep 3
argocd app sync argocd/dev-microservices
argocd app sync argocd/staging-microservices
argocd app sync argocd/prod-microservices
argocd app list
```

If Argo CLI shows `token signature is invalid`, reset and login again:

```bash
rm -rf ~/.argocd
PASS=$(kubectl --context kind-management -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --insecure --username admin --password "$PASS"
```
