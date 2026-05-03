variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "aks_node_count" {
  description = "Number of AKS worker nodes"
  type        = number
  default     = 1
}

variable "postgres_admin" {
  description = "Postgres admin username"
  type        = string
}

variable "postgres_password" {
  description = "Postgres admin password"
  type        = string
  sensitive   = true
}

variable "subscription_id" {
  description = "Subscription ID"
  type        = string
  sensitive   = true
}

