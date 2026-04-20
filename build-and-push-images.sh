#!/bin/bash

# Build and Push Docker Images to Docker Hub
# Usage: ./build-and-push-images.sh <tag>
# Example: ./build-and-push-images.sh v1.0.1

set -e

DOCKER_REPO="minhtri1612/go-microservice"
TAG=${1:-"v1.0.1"}

echo "Building and pushing images to Docker Hub..."
echo "Repository: $DOCKER_REPO"
echo "Tag: $TAG"

# Build and push API Gateway
echo "Building api-gateway..."
docker build -t $DOCKER_REPO:api-gateway-$TAG -f ./api-gateway/Dockerfile .
docker push $DOCKER_REPO:api-gateway-$TAG

# Build and push Product Service
echo "Building product-service..."
docker build -t $DOCKER_REPO:product-service-$TAG -f ./product-service/Dockerfile .
docker push $DOCKER_REPO:product-service-$TAG

# Build and push Inventory Service
echo "Building inventory-service..."
docker build -t $DOCKER_REPO:inventory-service-$TAG -f ./inventory-service/Dockerfile .
docker push $DOCKER_REPO:inventory-service-$TAG

# Build and push Order Service
echo "Building order-service..."
docker build -t $DOCKER_REPO:order-service-$TAG -f ./order-service/Dockerfile .
docker push $DOCKER_REPO:order-service-$TAG

# Build and push Payment Service
echo "Building payment-service..."
docker build -t $DOCKER_REPO:payment-service-$TAG -f ./payment-service/Dockerfile .
docker push $DOCKER_REPO:payment-service-$TAG

# Build and push Notification Service
echo "Building notification-service..."
docker build -t $DOCKER_REPO:notification-service-$TAG -f ./notification-service/Dockerfile .
docker push $DOCKER_REPO:notification-service-$TAG

# Build and push Client
echo "Building client..."
docker build -t $DOCKER_REPO:client-$TAG -f ./client/Dockerfile ./client
docker push $DOCKER_REPO:client-$TAG

echo "All images built and pushed successfully!"
echo ""
echo "Images pushed:"
echo "- $DOCKER_REPO:api-gateway-$TAG"
echo "- $DOCKER_REPO:product-service-$TAG"
echo "- $DOCKER_REPO:inventory-service-$TAG"
echo "- $DOCKER_REPO:order-service-$TAG"
echo "- $DOCKER_REPO:payment-service-$TAG"
echo "- $DOCKER_REPO:notification-service-$TAG"
echo "- $DOCKER_REPO:client-$TAG"