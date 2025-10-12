variable "repository_list" {
  description = "List of repository names"
  type = list
  default = ["api-gateway", "client","inventory-service", "notification-service", "order-service", "payment-service", "product-service"]
}

variable "region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "ap-southeast-2"
}