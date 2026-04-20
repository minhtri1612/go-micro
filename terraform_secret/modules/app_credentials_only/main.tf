resource "random_password" "db_password" {
  length  = 24
  special = true
}

resource "random_password" "stripe_secret_suffix" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "app_credentials" {
  name                    = "${var.project_name}/${var.environment}/app-credentials${var.app_credentials_name_suffix}"
  description             = "Application credentials for ${var.environment}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "app_credentials" {
  secret_id = aws_secretsmanager_secret.app_credentials.id
  secret_string = jsonencode({
    DB_USER           = var.db_user
    DB_PASSWORD       = random_password.db_password.result
    POSTGRES_USER     = var.db_user
    POSTGRES_PASSWORD = random_password.db_password.result
    STRIPE_SECRET_KEY = "sk_test_replace_me_${random_password.stripe_secret_suffix.result}"
  })
}
