variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "project_name" {
  type    = string
  default = "go-micro"
}

variable "environments" {
  type        = set(string)
  description = "dev / staging / prod"
  default     = ["dev", "staging", "prod"]
}

variable "db_user" {
  type    = string
  default = "postgres"
}

variable "app_credentials_name_suffix_by_env" {
  type        = map(string)
  default     = {}
  description = "Optional suffix by env, e.g. { dev = \"-v2\" }"
}

variable "eso_iam_user_suffix" {
  type        = string
  default     = "multi"
  description = "Suffix for IAM user used by External Secrets Operator"
}
