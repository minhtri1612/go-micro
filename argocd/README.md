# ArgoCD Applications for Go-Micro Project

This directory contains ArgoCD application manifests for deploying the go-micro microservices project.

## Applications

### 1. go-micro-application.yaml
Deploys the main microservices application including:
- API Gateway
- Product Service
- Order Service
- Inventory Service
- Payment Service
- Notification Service
- Client (Frontend)
- Redis
- RabbitMQ

### 2. go-micro-databases.yaml
Deploys the database services:
- Product Database (PostgreSQL)
- Order Database (PostgreSQL)
- Payment Database (PostgreSQL)
- Inventory Database (PostgreSQL)
- Notification Database (PostgreSQL)

## Usage

1. **Install ArgoCD in your EKS cluster:**
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

2. **Expose ArgoCD UI:**
```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
kubectl get svc -n argocd
```

3. **Get ArgoCD admin password:**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

4. **Deploy the applications:**
```bash
kubectl apply -f go-micro-application.yaml
kubectl apply -f go-micro-databases.yaml
```

## GitOps Benefits

- **Automated Deployments**: Changes to the GitHub repository automatically trigger deployments
- **Rollback Capability**: Easy rollback to previous versions
- **Health Monitoring**: Visual health status of all services
- **Sync Management**: Manual or automatic synchronization
- **Resource Management**: Centralized view of all Kubernetes resources

## Access URLs

- **ArgoCD UI**: `https://<loadbalancer-url>`
- **Go-Micro App**: `https://<your-app-loadbalancer-url>`

## Monitoring

In ArgoCD UI, you can:
- View application health status
- Check deployment logs
- Monitor resource usage
- Trigger manual syncs
- View application topology
