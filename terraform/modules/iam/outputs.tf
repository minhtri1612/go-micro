output "instance_profile_name" {
  value = aws_iam_instance_profile.k8s.name
}

output "role_name" {
  value = aws_iam_role.k8s.name
}

output "eso_access_key_id" {
  value       = aws_iam_access_key.eso.id
  description = "Access key cho ESO (configure.py → Secret aws-credentials trong cluster)"
}

output "eso_secret_access_key" {
  value       = aws_iam_access_key.eso.secret
  sensitive   = true
  description = "Secret key cho ESO (configure.py; không in log)"
}
