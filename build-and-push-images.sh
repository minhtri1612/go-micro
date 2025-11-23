#!/bin/bash

# Build and Push Docker Images to AWS ECR
# This script builds all microservices and pushes them to ECR
# Can be run standalone or integrated into CI/CD pipelines

set -e

# Configuration
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
ECR_REGISTRY="${ECR_REGISTRY:-398045402467.dkr.ecr.ap-southeast-2.amazonaws.com}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%s)}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Services to build
SERVICES=(
    "api-gateway:api-gateway"
    "product-service:product-service"
    "order-service:order-service"
    "inventory-service:inventory-service"
    "payment-service:payment-service"
    "notification-service:noti-service"
    "client:client"
)

# Function to print colored output
print_info() {
    echo -e "${GREEN}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured"
        exit 1
    fi
    
    print_info "Prerequisites check passed ✓"
}

# Login to ECR
login_to_ecr() {
    print_info "Logging in to ECR..."
    aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin "$ECR_REGISTRY"
    print_info "ECR login successful ✓"
}

# Build and push a single service
build_and_push_service() {
    local service_path=$1
    local ecr_repo_name=$2
    
    print_info "Building $ecr_repo_name..."
    
    # Build Docker image
    if [ "$service_path" = "client" ]; then
        docker build --pull \
            --build-arg VITE_API_URL="" \
            -t "$ecr_repo_name:$BUILD_NUMBER" \
            -f "$service_path/Dockerfile" \
            "$service_path"
    else
        docker build --pull \
            -t "$ecr_repo_name:$BUILD_NUMBER" \
            -f "$service_path/Dockerfile" \
            .
    fi
    
    # Tag for ECR
    docker tag "$ecr_repo_name:$BUILD_NUMBER" "$ECR_REGISTRY/$ecr_repo_name:$BUILD_NUMBER"
    docker tag "$ecr_repo_name:$BUILD_NUMBER" "$ECR_REGISTRY/$ecr_repo_name:latest"
    
    # Push to ECR
    print_info "Pushing $ecr_repo_name to ECR..."
    docker push "$ECR_REGISTRY/$ecr_repo_name:$BUILD_NUMBER"
    docker push "$ECR_REGISTRY/$ecr_repo_name:latest"
    
    # Cleanup local images
    docker rmi "$ecr_repo_name:$BUILD_NUMBER" 2>/dev/null || true
    docker rmi "$ECR_REGISTRY/$ecr_repo_name:$BUILD_NUMBER" 2>/dev/null || true
    docker rmi "$ECR_REGISTRY/$ecr_repo_name:latest" 2>/dev/null || true
    
    print_info "✅ $ecr_repo_name pushed successfully"
}

# Main execution
main() {
    print_info "Starting Docker image build and push process..."
    print_info "ECR Registry: $ECR_REGISTRY"
    print_info "AWS Region: $AWS_REGION"
    print_info "Build Number: $BUILD_NUMBER"
    echo ""
    
    check_prerequisites
    login_to_ecr
    echo ""
    
    # Build and push each service
    for service in "${SERVICES[@]}"; do
        IFS=':' read -r service_path ecr_repo_name <<< "$service"
        build_and_push_service "$service_path" "$ecr_repo_name"
        echo ""
    done
    
    # Cleanup
    print_info "Cleaning up Docker system..."
    docker system prune -af --volumes 2>/dev/null || true
    
    print_info "🎉 All images built and pushed successfully!"
    print_info "Build Number: $BUILD_NUMBER"
}

# Run main function
main

