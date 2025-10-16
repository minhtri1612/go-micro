# ----------------------------
# General Configuration
# ----------------------------
variable "region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "The environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "staging"
}

variable "project_name" {
  description = "Name of the project for tagging and identification."
  type        = string
  default     = "go-micro"
}

# ----------------------------
# Repository List
# ----------------------------
variable "repository_list" {
  description = "List of repository names for CI/CD."
  type        = list(string)
  default     = [
    "api-gateway",
    "client",
    "inventory-service",
    "notification-service",
    "order-service",
    "payment-service",
    "product-service"
  ]
}

# ----------------------------
# EC2 / Jenkins Instance
# ----------------------------
variable "instance_name" {
  description = "The name of the Jenkins EC2 instance."
  type        = string
  default     = "jenkins-server"
}

variable "instance_type" {
  description = "EC2 instance type for Jenkins server."
  type        = string
  default     = "t3.medium"
}

variable "instance_volume_size" {
  description = "Root EBS volume size (GB)."
  type        = number
  default     = 30
}

variable "jenkins_port" {
  description = "Port on which Jenkins will run."
  type        = number
  default     = 8080
}

# ----------------------------
# Network Configuration
# ----------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDRs for public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDRs for private subnets."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# ----------------------------
# Key Pair & IAM
# ----------------------------
variable "key_name" {
  description = "The name of the SSH key pair to access the instance."
  type        = string
  default     = "jenkins-key"
}

variable "iam_role_name" {
  description = "The IAM role name for the Jenkins instance."
  type        = string
  default     = "jenkins-server-iam-role"
}

# ----------------------------
# Tags & Metadata
# ----------------------------
variable "default_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Owner       = "Tri"
    Department  = "DevOps"
    Purpose     = "Jenkins + EKS CI/CD"
  }
}

# ----------------------------
# EKS Cluster
# ----------------------------
variable "eks_cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "staging-demo"
}

variable "eks_version" {
  description = "Version of Kubernetes for the EKS cluster."
  type        = string
  default     = "1.30"
}

variable "node_instance_type" {
  description = "Instance type for EKS worker nodes."
  type        = string
  default     = "t3.large"
}

variable "desired_node_count" {
  description = "Desired number of nodes in the EKS cluster."
  type        = number
  default     = 2
}