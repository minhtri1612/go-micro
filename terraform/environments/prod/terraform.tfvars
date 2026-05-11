# -----------------------------------------------------------------------------
# Prod – copy to terraform.tfvars và điền giá trị thật (không commit terraform.tfvars)
# RKE2 token: tự tạo và lưu trong AWS Secrets Manager bởi Terraform (module secrets)
# -----------------------------------------------------------------------------
environment        = "prod"
region             = "ap-southeast-2"
project_name       = "go-micro"
my_ip              = "0.0.0.0/0"   # Thu hẹp cho prod
instance_type      = "t3.medium"
master_count       = 1
worker_count       = 2
use_spot_instances = false
vpc_cidr = "10.2.0.0/16"
name_prefix       = "k8s"
# Bắt buộc chỉnh trước apply prod:
db_password        = "CHANGE_ME_STRONG_DB_PASSWORD"
stripe_secret_key  = "sk_live_CHANGE_ME_OR_sk_test_FOR_LAB"
