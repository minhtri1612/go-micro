# Kind setup for go-micro GitOps

This repo uses a multi-cluster local layout:
- `kind-management`: runs Argo CD
- `kind-dev`, `kind-staging`, `kind-prod`: workload clusters

## 1) Create clusters

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

## 3) Install Argo CD on management

```bash
kubectl config use-context kind-management
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd wait --for=condition=Ready pods --all --timeout=300s
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

In another terminal:

```bash
PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --insecure --username admin --password "$PASS"
```

## 4) Grant Argo CD access to workload clusters

```bash
kubectl --context kind-dev apply -f kind/dev-argocd-manager.yaml
kubectl --context kind-staging apply -f kind/staging-argocd-manager.yaml
kubectl --context kind-prod apply -f kind/prod-argocd-manager.yaml
sleep 5
```

Get tokens:

```bash
DEV_TOKEN=$(kubectl --context kind-dev get secret argocd-manager-long-lived-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)
STAGING_TOKEN=$(kubectl --context kind-staging get secret argocd-manager-long-lived-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)
PROD_TOKEN=$(kubectl --context kind-prod get secret argocd-manager-long-lived-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)
```

Register clusters in Argo CD (Linux + kind bridge network):

```bash
kubectl config use-context kind-management

DEV_IP=$(docker inspect dev-control-plane --format '{{.NetworkSettings.Networks.kind.IPAddress}}')
STAGING_IP=$(docker inspect staging-control-plane --format '{{.NetworkSettings.Networks.kind.IPAddress}}')
PROD_IP=$(docker inspect prod-control-plane --format '{{.NetworkSettings.Networks.kind.IPAddress}}')

kubectl create secret generic cluster-dev -n argocd \
  --from-literal=name=dev \
  --from-literal=server=https://$DEV_IP:6443 \
  --from-literal=config="{\"bearerToken\":\"$DEV_TOKEN\",\"tlsClientConfig\":{\"insecure\":true}}"
kubectl label secret cluster-dev -n argocd argocd.argoproj.io/secret-type=cluster

kubectl create secret generic cluster-staging -n argocd \
  --from-literal=name=staging \
  --from-literal=server=https://$STAGING_IP:6443 \
  --from-literal=config="{\"bearerToken\":\"$STAGING_TOKEN\",\"tlsClientConfig\":{\"insecure\":true}}"
kubectl label secret cluster-staging -n argocd argocd.argoproj.io/secret-type=cluster

kubectl create secret generic cluster-prod -n argocd \
  --from-literal=name=prod \
  --from-literal=server=https://$PROD_IP:6443 \
  --from-literal=config="{\"bearerToken\":\"$PROD_TOKEN\",\"tlsClientConfig\":{\"insecure\":true}}"
kubectl label secret cluster-prod -n argocd argocd.argoproj.io/secret-type=cluster
```

## 5) Bootstrap this repo

```bash
kubectl config use-context kind-management
kubectl apply -f argocd/bootstrap/01-projects.yaml
kubectl apply -f argocd/bootstrap/02-dev-microservices-stack.yaml
kubectl apply -f argocd/bootstrap/03-staging-microservices-stack.yaml
kubectl apply -f argocd/bootstrap/04-prod-microservices-stack.yaml
```

Open Argo CD at `https://localhost:8080` (while port-forward is running).
