#!/bin/bash

# Import existing ECR repositories
echo "Importing ECR repositories..."
terraform import 'aws_ecr_repository.repositories["api-gateway"]' api-gateway
terraform import 'aws_ecr_repository.repositories["client"]' client
terraform import 'aws_ecr_repository.repositories["inventory-service"]' inventory-service
terraform import 'aws_ecr_repository.repositories["notification-service"]' notification-service
terraform import 'aws_ecr_repository.repositories["order-service"]' order-service
terraform import 'aws_ecr_repository.repositories["payment-service"]' payment-service
terraform import 'aws_ecr_repository.repositories["product-service"]' product-service

# Import existing IAM roles
echo "Importing IAM roles..."
terraform import aws_iam_role.eks staging-demo-eks-cluster
terraform import aws_iam_role.nodes staging-demo-eks-nodes
terraform import aws_iam_role.jenkins_role jenkins-ec2-role

# Import existing key pair
echo "Importing key pair..."
terraform import aws_key_pair.jenkins_key jenkins-key

echo "Import completed!"

