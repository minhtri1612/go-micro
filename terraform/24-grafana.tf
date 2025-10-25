# Grafana will be deployed manually after EKS is ready
# This avoids Kubernetes client configuration issues during terraform apply

# Output Grafana URL
output "grafana_url" {
  description = "Grafana UI URL"
  value       = "https://grafana.${aws_eip.jenkins_eip.public_ip}.nip.io"
}

output "grafana_credentials" {
  description = "Grafana login credentials"
  value = {
    username = "admin"
    password = "admin123"
  }
  sensitive = true
}
