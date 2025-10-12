# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# ECR Repositories for each service
resource "aws_ecr_repository" "repositories" {
  for_each = toset(var.repository_list)
  
  name                 = each.key
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

# ECR Lifecycle Policy to manage image retention
resource "aws_ecr_lifecycle_policy" "repository_policy" {
  for_each = toset(var.repository_list)
  
  repository = aws_ecr_repository.repositories[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR Login Token
data "aws_ecr_authorization_token" "token" {}

# Build and push Docker images to ECR using local-exec
resource "null_resource" "build_and_push_images" {
  for_each = toset(var.repository_list)
  
  provisioner "local-exec" {
    command = <<-EOT
      # Login to ECR
      aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${local.aws_ecr_url}
      
      # Build image
      docker build -t ${each.key}:latest -f ../${each.key}/Dockerfile ../${each.key}
      
      # Tag for ECR
      docker tag ${each.key}:latest ${aws_ecr_repository.repositories[each.key].repository_url}:latest
      
      # Push to ECR
      docker push ${aws_ecr_repository.repositories[each.key].repository_url}:latest
    EOT
  }
  
  depends_on = [aws_ecr_repository.repositories]
}

# Output ECR registry URL for docker-compose
output "ecr_registry_url" {
  value = local.aws_ecr_url
}

# Output repository URLs
output "repository_urls" {
  value = {
    for k, v in aws_ecr_repository.repositories : k => v.repository_url
  }
}

# Generate docker-compose.yml with ECR images
resource "local_file" "docker_compose" {
  content = templatefile("${path.module}/docker-compose.tftpl", {
    ecr_registry_url = local.aws_ecr_url
  })
  filename = "${path.module}/../docker-compose.ecr.yml"
  
  depends_on = [null_resource.build_and_push_images]
}