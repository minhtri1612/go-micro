#!/bin/bash

# Deploy Go Microservices to AWS EKS
set -e

echo "🚀 Deploying Go Microservices to AWS EKS..."

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ kubectl is not configured or cluster is not accessible"
    echo "Please run: aws eks update-kubeconfig --region <region> --name <cluster-name>"
    exit 1
fi

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed"
    exit 1
fi

# Create namespace
echo "📦 Creating namespace..."
kubectl create namespace go-micro --dry-run=client -o yaml | kubectl apply -f -

# Create required secrets
echo "🔐 Creating required secrets..."
kubectl create secret docker-registry ecr-secret \
  --docker-server=398045402467.dkr.ecr.ap-southeast-2.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region ap-southeast-2) \
  --namespace=go-micro \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic aws-secret \
  --from-literal=AWS_ACCESS_KEY_ID=dummy \
  --from-literal=AWS_SECRET_ACCESS_KEY=dummy \
  --from-literal=AWS_DEFAULT_REGION=ap-southeast-2 \
  --namespace=go-micro \
  --dry-run=client -o yaml | kubectl apply -f -
          # Create application secrets
echo "🔐 Creating application secrets..."

# Update Helm dependencies
echo "📋 Updating Helm dependencies..."
cd main
helm dependency update

# Deploy the application
echo "🚀 Deploying application..."
helm upgrade --install go-micro . \
  --namespace go-micro \
  --create-namespace \
  --timeout 15m \
  --wait

# Wait for pods to be ready
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=api-gateway -n go-micro --timeout=300s
kubectl wait --for=condition=ready pod -l app=client -n go-micro --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=inventory-service -n go-micro --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=order-service -n go-micro --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=payment-service -n go-micro --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=product-service -n go-micro --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=noti-service -n go-micro --timeout=300s

# Check deployment status
echo "✅ Checking deployment status..."
kubectl get pods -n go-micro
kubectl get services -n go-micro
kubectl get ingress -n go-micro

echo "🎉 Deployment completed!"
echo ""
echo "To access your application:"
echo "1. Get the ALB URL: kubectl get ingress -n go-micro"
echo "2. Update your DNS to point to the ALB URL"
echo "3. Or use the ALB URL directly to test"

