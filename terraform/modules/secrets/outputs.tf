output "rke2_token" {
  value       = random_password.rke2_token.result
  sensitive   = true
  description = "RKE2 cluster token (cũng lưu trong Secrets Manager)"
}

output "secret_arn" {
  value       = aws_secretsmanager_secret.rke2_token.arn
  description = "ARN của secret RKE2 token trong AWS Secrets Manager"
}

output "secret_name" {
  value       = aws_secretsmanager_secret.rke2_token.name
  description = "Tên secret RKE2 token"
}

output "app_credentials_secret_name" {
  value       = aws_secretsmanager_secret.app_credentials.name
  description = "Tên AWS secret app-credentials (remoteRef cho ExternalSecret)"
}

output "app_credentials_secret_arn" {
  value       = aws_secretsmanager_secret.app_credentials.arn
  description = "ARN secret app-credentials"
}
