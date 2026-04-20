# Kind setup for go-micro (same framework as old project)

This repo keeps the same platform workflow as your old project:
- 1 management cluster with Argo CD
- 3 workload clusters: dev, staging, prod
- app-of-apps bootstrap from `argocd/bootstrap`

The difference is workload shape:
- old project: monolithic (`backend` + `database`)
- this project: microservices (`api-gateway`, `product`, `inventory`, `order`, `payment`, `noti`, `client` + DB services)

## 1) Create 4 clusters

```bash
kind create cluster --name management --config kind/management-kind-config.yaml
kind create cluster --name dev --config kind/dev-kind-config.yaml
kind create cluster --name staging --config kind/staging-kind-config.yaml
kind create cluster --name prod --config kind/prod-kind-config.yaml
```

## 2) Fix kubeconfig API endpoints

```bash
kubectl config set-cluster kind-management --server=https://127.0.0.1:33443
kubectl config set-cluster kind-dev --server=https://127.0.0.1:30443
kubectl config set-cluster kind-staging --server=https://127.0.0.1:32443
kubectl config set-cluster kind-prod --server=https://127.0.0.1:31443
```

## 3) Install Cilium on management first

`kind/management-kind-config.yaml` has `disableDefaultCNI: true`, so you must install a CNI before Argo CD.

```bash
kubectl config use-context kind-management
helm repo add cilium https://helm.cilium.io 2>/dev/null || true
helm repo update
helm upgrade --install cilium cilium/cilium -n kube-system --create-namespace --version 1.19.2 --wait --timeout 15m
```

## 4) Install Argo CD (server-side apply)

```bash
kubectl config use-context kind-management
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd wait --for=condition=Ready pods --all --timeout=300s
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

In another terminal:

```bash
PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --insecure --username admin --password "$PASS"
```

## 5) Register workload clusters to Argo CD

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
kubectl --context kind-management label secret cluster-dev -n argocd argocd.argoproj.io/secret-type=cluster

kubectl --context kind-management create secret generic cluster-staging -n argocd \
  --from-literal=name=staging \
  --from-literal=server=https://$STAGING_IP:6443 \
  --from-literal=config="{\"bearerToken\":\"$STAGING_TOKEN\",\"tlsClientConfig\":{\"insecure\":true}}"
kubectl --context kind-management label secret cluster-staging -n argocd argocd.argoproj.io/secret-type=cluster

kubectl --context kind-management create secret generic cluster-prod -n argocd \
  --from-literal=name=prod \
  --from-literal=server=https://$PROD_IP:6443 \
  --from-literal=config="{\"bearerToken\":\"$PROD_TOKEN\",\"tlsClientConfig\":{\"insecure\":true}}"
kubectl --context kind-management label secret cluster-prod -n argocd argocd.argoproj.io/secret-type=cluster
```

## 6) Bootstrap microservices apps

```bash
kubectl --context kind-management apply -f argocd/bootstrap/01-projects.yaml
kubectl --context kind-management apply -f argocd/bootstrap/02-dev-microservices-stack.yaml
kubectl --context kind-management apply -f argocd/bootstrap/03-staging-microservices-stack.yaml
kubectl --context kind-management apply -f argocd/bootstrap/04-prod-microservices-stack.yaml
```

## 7) Apply External Secrets manifests (optional but recommended)

Install External Secrets Operator on workload clusters first, then apply chart values:

```bash
helm template external-secrets external-secrets/applications \
  -f external-secrets/applications/values.yaml \
  -f config/base/config.yaml \
  -f config/env/dev.yaml \
  | kubectl --context kind-dev apply -f -
```

Repeat with `staging.yaml` and `prod.yaml` for other clusters.
