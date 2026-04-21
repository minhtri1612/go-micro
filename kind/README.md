# Kind - Daily Recreate Guide

Run from repo root:

```bash
cd ~/Downloads/go-micro
```

Argo CD runs only on `kind-management`.

API servers:
- management: `https://127.0.0.1:33443`
- dev: `https://127.0.0.1:30443`
- staging: `https://127.0.0.1:32443`
- prod: `https://127.0.0.1:31443`

## 1) Full recreate flow (after reboot)

### 1.1 Delete old clusters

```bash
kind delete cluster --name management
kind delete cluster --name dev
kind delete cluster --name staging
kind delete cluster --name prod
```

### 1.2 Create clusters and bootstrap Cilium on management

Important:
- `kind/*-kind-config.yaml` uses `disableDefaultCNI: true`
- install Cilium on management before Argo CD
- use bootstrap values on first install (`ServiceMonitor` CRD not ready yet)

```bash
kind create cluster --name management --config kind/management-kind-config.yaml

kubectl config use-context kind-management
kubectl config set-cluster kind-management --server=https://127.0.0.1:33443

helm repo add cilium https://helm.cilium.io 2>/dev/null || true
helm repo update

helm upgrade --install cilium cilium/cilium -n kube-system --create-namespace \
  --version 1.19.2 \
  -f cilium/cilium-values-management.yaml \
  -f cilium/cilium-values-management-bootstrap.yaml \
  --wait --timeout 15m

kind create cluster --name dev --config kind/dev-kind-config.yaml
kind create cluster --name staging --config kind/staging-kind-config.yaml
kind create cluster --name prod --config kind/prod-kind-config.yaml

kubectl config set-cluster kind-dev --server=https://127.0.0.1:30443
kubectl config set-cluster kind-staging --server=https://127.0.0.1:32443
kubectl config set-cluster kind-prod --server=https://127.0.0.1:31443
```

If kubeconfig got reset to `0.0.0.0`, run:

```bash
bash scripts/kind-fix-kubeconfig-servers.sh
```

### 1.3 Install Argo CD on management

```bash
kubectl config use-context kind-management
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl --context kind-management apply -f argocd/bootstrap/00-argocd-cm-health.yaml
kubectl --context kind-management -n argocd wait --for=condition=Ready pods --all --timeout=300s
```

Login Argo CLI:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Open another terminal:

```bash
rm -rf ~/.argocd
PASS=$(kubectl --context kind-management -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --insecure --username admin --password "$PASS"
```

### 1.4 Register workload clusters (dev/staging/prod)

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
  --from-literal=config="{\"bearerToken\":\"$DEV_TOKEN\",\"tlsClientConfig\":{\"insecure\":true}}" --dry-run=client -o yaml | kubectl --context kind-management apply -f -
kubectl --context kind-management label secret cluster-dev -n argocd argocd.argoproj.io/secret-type=cluster --overwrite

kubectl --context kind-management create secret generic cluster-staging -n argocd \
  --from-literal=name=staging \
  --from-literal=server=https://$STAGING_IP:6443 \
  --from-literal=config="{\"bearerToken\":\"$STAGING_TOKEN\",\"tlsClientConfig\":{\"insecure\":true}}" --dry-run=client -o yaml | kubectl --context kind-management apply -f -
kubectl --context kind-management label secret cluster-staging -n argocd argocd.argoproj.io/secret-type=cluster --overwrite

kubectl --context kind-management create secret generic cluster-prod -n argocd \
  --from-literal=name=prod \
  --from-literal=server=https://$PROD_IP:6443 \
  --from-literal=config="{\"bearerToken\":\"$PROD_TOKEN\",\"tlsClientConfig\":{\"insecure\":true}}" --dry-run=client -o yaml | kubectl --context kind-management apply -f -
kubectl --context kind-management label secret cluster-prod -n argocd argocd.argoproj.io/secret-type=cluster --overwrite
```

### 1.5 Apply bootstrap Applications

```bash
kubectl --context kind-management apply -f argocd/bootstrap/01-projects.yaml
kubectl --context kind-management apply -f argocd/bootstrap/02-dev-microservices-stack.yaml
kubectl --context kind-management apply -f argocd/bootstrap/03-staging-microservices-stack.yaml
kubectl --context kind-management apply -f argocd/bootstrap/04-prod-microservices-stack.yaml

kubectl --context kind-management apply -f argocd/bootstrap/12-argo-rollouts-dev.yaml
kubectl --context kind-management apply -f argocd/bootstrap/13-argo-rollouts-staging.yaml
kubectl --context kind-management apply -f argocd/bootstrap/14-argo-rollouts-prod.yaml

kubectl --context kind-management apply -f argocd/bootstrap/09-cilium-dev.yaml
kubectl --context kind-management apply -f argocd/bootstrap/10-cilium-staging.yaml
kubectl --context kind-management apply -f argocd/bootstrap/11-cilium-prod.yaml
kubectl --context kind-management apply -f argocd/bootstrap/18-cilium-management.yaml

kubectl --context kind-management apply -f argocd/bootstrap/19-traefik-dev.yaml
kubectl --context kind-management apply -f argocd/bootstrap/20-traefik-staging.yaml
kubectl --context kind-management apply -f argocd/bootstrap/21-traefik-prod.yaml
```

### 1.6 Sync order (critical)

Always sync `argocd-projects` first, then wait a bit so Argo cache sees `dev/staging/prod` projects.

```bash
argocd app sync argocd/argocd-projects
sleep 3

argocd app sync argocd/argo-rollouts-dev
argocd app sync argocd/argo-rollouts-staging
argocd app sync argocd/argo-rollouts-prod

argocd app sync argocd/cilium-management
argocd app sync argocd/cilium-dev
argocd app sync argocd/cilium-staging
argocd app sync argocd/cilium-prod

argocd app sync argocd/traefik-dev
argocd app sync argocd/traefik-staging
argocd app sync argocd/traefik-prod
```

If Argo CLI returns `permission denied` or invalid token:

```bash
rm -rf ~/.argocd
PASS=$(kubectl --context kind-management -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --insecure --username admin --password "$PASS"
```

## 2) Important notes

### 2.1 Why `cilium-management` needs bootstrap values first

`argocd/bootstrap/18-cilium-management.yaml` must include:

```yaml
valueFiles:
  - $values/cilium/cilium-values-management.yaml
  - $values/cilium/cilium-values-management-bootstrap.yaml
```

Reason:
- before monitoring CRDs exist, `ServiceMonitor` resources fail
- before MetalLB is ready, `LoadBalancer` wait can hang

After monitoring/MetalLB are healthy, you can remove bootstrap file from app values if you want full mode only.

### 2.2 Quick verify

```bash
argocd proj list
argocd app list
kubectl --context kind-management -n argocd get appprojects
kubectl --context kind-dev -n kube-system get pods -l k8s-app=cilium
kubectl --context kind-staging -n kube-system get pods -l k8s-app=cilium
kubectl --context kind-prod -n kube-system get pods -l k8s-app=cilium
```
