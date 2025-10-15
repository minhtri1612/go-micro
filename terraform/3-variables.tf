variable "repository_list" {
  description = "List of repository names"
  type = list
  default = ["api-gateway", "client","inventory-service", "notification-service", "order-service", "payment-service", "product-service"]
}

variable "region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "ap-southeast-2"
}

variable "instance_name" {
  description = "The name of the EC2 instance."
  default     = "jenkins-server"
}

variable "instance_type" {
  description = "Type of EC2 instance"
  default     = "t2.2xlarge"
}


# Key Pair

variable "key_name" {
  description = "The name of the SSH key pair to access the instance."
  default     = "jenkins-key"
}

# IAM Role

variable "iam_role_name" {
  description = "The IAM role name for jenkins instance."
  default     = "jenkins-server-iam-role"
}