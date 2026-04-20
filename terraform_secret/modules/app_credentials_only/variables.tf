variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "db_user" {
  type    = string
  default = "postgres"
}

variable "app_credentials_name_suffix" {
  type        = string
  default     = ""
  description = "Optional secret name suffix, e.g. -v2"
}
