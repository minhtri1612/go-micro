variable "environment" {
  type        = string
  description = "Environment name"
}

variable "name_prefix" {
  type    = string
  default = "k8s"
}

variable "project_name" {
  type        = string
  description = "Project name (IAM policy ESO: GetSecretValue trên prefix project trong Secrets Manager)"
  default     = "go-micro"
}
