variable "environment" {
  type = string
}

variable "dns_names" {
  type        = list(string)
  description = "SANs cho ACM self-signed (Ingress ALB) — khớp host *.go-micro.local + Argo"
  default     = ["argocd.local", "dev-go-micro.local", "prod-go-micro.local", "*.go-micro.local", "*.local"]
}
