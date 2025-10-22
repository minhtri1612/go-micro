# 🚀 Simple AWS EKS Deployment Guide

## ✅ What's Been Fixed

1. **Service Types**: All services now use `ClusterIP` (not LoadBalancer)
2. **Ingress**: Changed from `nginx-ingress` to AWS `ALB` 
3. **Single Load Balancer**: All services share 1 ALB via `group.name: go-micro-app`
4. **Frontend API**: Uses same-origin (no CORS issues)
5. **Terraform Cleanup**: Removed ArgoCD, Prometheus, nginx-ingress

---

## 📋 Prerequisites

```bash
# Install required tools
aws configure  # Set your AWS credentials
terraform --version  # v1.0+
kubectl version --client  # v1.28+
helm version  # v3.0+
docker --version
```

---

## 🏗️ Step 1: Build & Push Images to ECR

```bash
cd /home/minhtri/cloud/go-micro

# Login to ECR
aws ecr get-login-password --region ap-southeast-2 | \
  docker login --username AWS --password-stdin \
  675613596870.dkr.ecr.ap-southeast-2.amazonaws.com

# Build and push all services
for service in api-gateway client product-service order-service \
               payment-service inventory-service notification-service; do
  echo "Building $service..."
  docker build -t $service:latest ./$service
  docker tag $service:latest \
    675613596870.dkr.ecr.ap-southeast-2.amazonaws.com/$service:latest
  docker push \
    675613596870.dkr.ecr.ap-southeast-2.amazonaws.com/$service:latest
done
```

---

## ☁️ Step 2: Deploy EKS Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Plan (review changes)
terraform plan

# Apply (creates EKS cluster, VPC, nodes, ALB controller)
terraform apply -auto-approve

# This takes ~15-20 minutes
# Creates:
# - VPC with public/private subnets
# - EKS cluster
# - Node groups (2-4 t2.medium nodes)
# - AWS Load Balancer Controller
# - EBS CSI driver
# - Cluster autoscaler
```

---

## 🔧 Step 3: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --name staging-demo --region ap-southeast-2

# Verify connection
kubectl get nodes
# Should show 2-4 nodes in Ready state
```

---

## 📦 Step 4: Deploy Your Application

```bash
cd /home/minhtri/cloud/go-micro

# Deploy via Helm
helm install go-micro ./main \
  --namespace go-microservice \
  --create-namespace \
  --wait \
  --timeout 5m

# Check deployment
kubectl get pods -n go-microservice
# All pods should be Running

# Check ALB creation
kubectl get ingress -n go-microservice
# Should show 1 ALB DNS for both client and api-gateway
```

---

## 🌐 Step 5: Access Your Application

```bash
# Get the ALB URL
ALB_URL=$(kubectl get ingress -n go-microservice \
  go-micro-client -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Your app is at: http://$ALB_URL"

# Test endpoints
curl http://$ALB_URL/               # Frontend
curl http://$ALB_URL/health         # API Gateway health
curl http://$ALB_URL/api/v1/products  # Products API
```

---

## 🔍 Troubleshooting

### Pods not starting?
```bash
kubectl get pods -n go-microservice
kubectl describe pod <pod-name> -n go-microservice
kubectl logs <pod-name> -n go-microservice
```

### ALB not created?
```bash
# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Check controller logs
kubectl logs -n kube-system \
  deployment/aws-load-balancer-controller
```

### Frontend not loading?
```bash
# Check client service
kubectl get svc go-micro-client -n go-microservice

# Check ingress
kubectl describe ingress go-micro-client -n go-microservice
```

---

## 🧹 Cleanup (Delete Everything)

```bash
# Delete application
helm uninstall go-micro -n go-microservice

# Delete namespace
kubectl delete namespace go-microservice

# Wait 2 minutes for ALB to be deleted, then:
cd terraform
terraform destroy -auto-approve
```

---

## 💰 Cost Estimate

| Resource | Cost/Month |
|----------|-----------|
| EKS Cluster | $73 |
| 2x t2.medium nodes (24/7) | $68 |
| ALB (1 shared) | $16 |
| EBS volumes (50GB) | $5 |
| **Total** | **~$162/month** |

**Cost savings vs old setup:** $32/month (removed 2 extra load balancers)

---

## 📁 What's Deployed

```
AWS ALB (1 shared)
├─ / → go-micro-client (React Frontend)
└─ /api → go-micro-api-gateway (Go API)
            ├─ /api/v1/products → product-service
            ├─ /api/v1/orders → order-service
            ├─ /api/v1/payments → payment-service
            ├─ /api/v1/inventory → inventory-service
            └─ /api/v1/notifications → notification-service

Databases (ClusterIP):
├─ product-db (PostgreSQL)
├─ order-db (PostgreSQL)
├─ payment-db (PostgreSQL)
├─ inventory-db (PostgreSQL)
├─ notification-db (PostgreSQL)
├─ redis (Cache)
└─ rabbitmq (Message Queue)
```

---

## 🎯 Key Differences from Before

| Before | After |
|--------|-------|
| 3 LoadBalancers | 1 ALB |
| nginx-ingress | AWS ALB Controller |
| LoadBalancer services | ClusterIP services |
| CORS errors | Same-origin (no CORS) |
| Manual helm install | Automated flow |
| ArgoCD, Prometheus | Removed (optional) |

---

**🎉 That's it! Simple, clean EKS deployment!**






