# -----------------------------------------------------------------------------
# Management – cluster chỉ chạy ArgoCD (GitOps)
# Copy to terraform.tfvars và chỉnh my_ip nếu cần
# -----------------------------------------------------------------------------
environment        = "management"
region             = "ap-southeast-2"
project_name       = "go-micro"
my_ip              = "0.0.0.0/0"
instance_type      = "t3.medium"
master_count       = 1
worker_count       = 0
use_spot_instances = false
vpc_cidr           = "10.0.0.0/16"
name_prefix        = "k8s"
