# -----------------------------------------------------------------------------
# Dev – giá trị mặc định cho dev (file này bị .gitignore, tạo local khi cần)
# -----------------------------------------------------------------------------
environment        = "dev"
region             = "ap-southeast-2"
project_name       = "go-micro"
my_ip              = "0.0.0.0/0"
instance_type      = "t3.medium"
master_count       = 1
worker_count       = 2
use_spot_instances = false
vpc_cidr = "10.1.0.0/16"
name_prefix        = "k8s"
# stripe_secret_key = "sk_test_..."   # optional: override default in variables.tf
# Nếu secret RKE2/app-credentials cũ trên AWS đang scheduled deletion, bật 2 dòng:
# rke2_token_secret_suffix       = "rke2-token-v4"
# app_credentials_name_suffix    = "-v2"
