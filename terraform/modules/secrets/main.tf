# RKE2 token: tạo bằng Terraform, lưu trong AWS Secrets Manager (không cần tfvars)

resource "random_password" "rke2_token" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "rke2_token" {
  name                    = "${var.project_name}/${var.environment}/${var.secret_name_suffix}"
  description             = "RKE2 cluster join token (managed by Terraform)"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rke2_token" {
  secret_id     = aws_secretsmanager_secret.rke2_token.id
  secret_string = random_password.rke2_token.result
}

# -----------------------------------------------------------------------------
# App credentials — cùng JSON với terraform_secret/modules/app_credentials_only
# (External Secrets / config/env/*.yaml → go-micro/<env>/app-credentials)
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "app_credentials" {
  name                    = "${var.project_name}/${var.environment}/app-credentials${var.app_credentials_name_suffix}"
  description             = "Application credentials for ${var.environment} (go-micro / ESO)"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "app_credentials" {
  secret_id = aws_secretsmanager_secret.app_credentials.id
  secret_string = jsonencode({
    DB_USER              = var.db_user
    DB_PASSWORD          = var.db_password
    POSTGRES_USER        = var.db_user
    POSTGRES_PASSWORD    = var.db_password
    PRODUCT_DB_NAME      = "products_db"
    ORDER_DB_NAME        = "orders_db"
    INVENTORY_DB_NAME    = "inventory_db"
    NOTIFICATION_DB_NAME = "notification_db"
    PAYMENT_DB_NAME      = "payment_db"
    STRIPE_SECRET_KEY    = var.stripe_secret_key
  })
}
