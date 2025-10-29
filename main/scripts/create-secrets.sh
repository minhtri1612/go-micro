#!/bin/bash

# Create missing secrets for the go-micro application
# This script should be run after terraform apply but before helm install

set -e

NAMESPACE="go-micro"

echo "Creating missing secrets for go-micro application..."

# Create rabbitmq secret
kubectl create secret generic rabbitmq \
  --from-literal=RABBITMQ_DEFAULT_USER=guest \
  --from-literal=RABBITMQ_DEFAULT_PASS=guest \
  -n $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

# Create order-db secret
kubectl create secret generic order-db \
  --from-literal=POSTGRES_PASSWORD=canh177 \
  -n $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

# Create product-db secret
kubectl create secret generic go-micro-product-db \
  --from-literal=POSTGRES_PASSWORD=canh177 \
  -n $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

# Create payment-db secret
kubectl create secret generic payment-db \
  --from-literal=POSTGRES_PASSWORD=canh177 \
  -n $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

# Create inventory-db secret
kubectl create secret generic inventory-db \
  --from-literal=POSTGRES_PASSWORD=canh177 \
  -n $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

# Create notification-db secret
kubectl create secret generic notification-db \
  --from-literal=POSTGRES_PASSWORD=canh177 \
  -n $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

echo "All secrets created successfully!"
