variable "prefix" {
  type = string
}

variable "location" {
  type    = string
  default = "East US"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "aks_node_count" {
  type    = number
  default = 1
}

variable "postgres_admin" {
  type = string
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "subscription_id" {
  description = "Subscription ID"
  type        = string
  sensitive   = true
}
