# -----------------------------------------------------------------------------
# Management environment variables
# -----------------------------------------------------------------------------

variable "environment" {
  type    = string
  default = "management"
}

variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "project_name" {
  type    = string
  default = "go-micro"
}

variable "db_user" {
  type    = string
  default = "postgres"
}

variable "db_password" {
  type        = string
  sensitive   = true
  default     = "canh177"
  description = "Chỉ dùng nếu tạo app-credentials trên management (thường không sync app lên đây)"
}

variable "stripe_secret_key" {
  type        = string
  sensitive   = true
  default     = "sk_test_placeholder_replace_in_tfvars"
  validation {
    condition     = can(regex("^sk_(test|live)_", var.stripe_secret_key))
    error_message = "stripe_secret_key must start with sk_test_ or sk_live_."
  }
}

variable "rke2_token_secret_suffix" {
  type    = string
  default = "rke2-token"
}

variable "app_credentials_name_suffix" {
  type    = string
  default = ""
}

variable "my_ip" {
  description = "CIDR cho phép SSH vào OpenVPN (0.0.0.0/0 = mọi nơi)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ami_id" {
  type        = string
  description = "AMI override (để trống thì dùng Ubuntu 22.04 mới nhất)"
  default     = ""
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "master_count" {
  type    = number
  default = 1
}

variable "worker_count" {
  type    = number
  default = 1
}

variable "use_spot_instances" {
  type    = bool
  default = false   # On-Demand: tránh management bị AWS terminate (Spot)
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "name_prefix" {
  type    = string
  default = "k8s"
}
