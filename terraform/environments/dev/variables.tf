# -----------------------------------------------------------------------------
# Dev environment variables
# -----------------------------------------------------------------------------

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "project_name" {
  type        = string
  default     = "go-micro"
  description = "Prefix AWS Secrets Manager (go-micro/<env>/...)"
}

variable "db_user" {
  type    = string
  default = "postgres"
}

variable "db_password" {
  type        = string
  sensitive   = true
  default     = "canh177"
  description = "Mật khẩu trong app-credentials JSON (Postgres / microservices) — đổi trên prod"
}

variable "stripe_secret_key" {
  type        = string
  sensitive   = true
  description = "Stripe sk_test_... hoặc sk_live_... (bắt buộc trong terraform.tfvars nếu không dùng default dev)"
  default     = "sk_test_placeholder_replace_in_tfvars"
  validation {
    condition     = can(regex("^sk_(test|live)_", var.stripe_secret_key))
    error_message = "stripe_secret_key must start with sk_test_ or sk_live_."
  }
}

variable "rke2_token_secret_suffix" {
  type        = string
  default     = "rke2-token"
  description = "Tên path segment secret RKE2 trên AWS (đổi nếu secret cũ đang scheduled deletion, vd rke2-token-v4)"
}

variable "app_credentials_name_suffix" {
  type        = string
  default     = ""
  description = "Hậu tố tên secret app-credentials (vd -v2) nếu bản cũ đang scheduled deletion"
}

variable "my_ip" {
  description = "CIDR cho phép SSH vào OpenVPN (0.0.0.0/0 = mọi nơi; nên thu hẹp cho prod)"
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
  default = 2
}

variable "use_spot_instances" {
  type    = bool
  default = false   # On-Demand: tránh dev bị AWS terminate (Spot)
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "name_prefix" {
  type    = string
  default = "k8s"
}
