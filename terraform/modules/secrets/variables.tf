variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "secret_name_suffix" {
  type        = string
  default     = "rke2-token"
  description = "Suffix for Secrets Manager secret name (RKE2 token path segment)"
}

variable "app_credentials_name_suffix" {
  type        = string
  default     = ""
  description = "Suffix for app-credentials secret name (e.g. -v2 when old secret is scheduled for deletion)"
}

variable "db_user" {
  type        = string
  default     = "postgres"
  description = "DB user stored in app-credentials (maps to ESO keys DB_USER / POSTGRES_USER)"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "DB password for app-credentials JSON (same as Postgres DBs when provisioned separately)"
}

variable "stripe_secret_key" {
  type        = string
  sensitive   = true
  description = "Stripe API secret (sk_test_... / sk_live_...) — giống terraform_secret"
  validation {
    condition     = can(regex("^sk_(test|live)_", var.stripe_secret_key))
    error_message = "stripe_secret_key must start with sk_test_ or sk_live_."
  }
}
