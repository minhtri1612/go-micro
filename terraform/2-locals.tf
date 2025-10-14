locals {
  tags = {
    created_by = "terraform"
  }

  aws_ecr_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
  env         = "staging"
  region      = "ap-southeast-2"
  zone1       = "ap-southeast-2a"
  zone2       = "ap-southeast-2b"
  eks_name    = "demo"
  eks_version = "1.29"
}