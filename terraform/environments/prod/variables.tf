# -----------------------------------------------------------------------------
# Prod environment variables (defaults hướng production: on-demand, thu hẹp my_ip)
# -----------------------------------------------------------------------------

variable "environment" {
  type    = string
  default = "prod"
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
  description = "Bắt buộc set trong terraform.tfvars trên prod (không dùng default yếu)"
}

variable "stripe_secret_key" {
  type        = string
  sensitive   = true
  description = "Stripe sk_live_... hoặc sk_test_... — set trong terraform.tfvars"
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
  description = "CIDR cho phép SSH vào OpenVPN (prod: nên set IP/VPN cụ thể, không dùng 0.0.0.0/0)"
  type        = string
  default     = ""
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
  default = 2
}

variable "use_spot_instances" {
  type    = bool
  default = false   # On-Demand: tránh prod bị AWS terminate (Spot)
}

variable "vpc_cidr" {
  type    = string
  default = "10.2.0.0/16"
}

variable "name_prefix" {
  type    = string
  default = "k8s"
}
