# provider configuration and version constraints
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Azure provider setup with subscription context
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Get current Azure client configuration for dynamic values (e.g., tenant ID for role assignments)
data "azurerm_client_config" "current" { }

# Local values for consistent naming across resources
locals {
  prefix = "${var.prefix}-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

# Resource Group (logical container for all resources)
resource "azurerm_resource_group" "rg" {
  name     = "${local.prefix}-rg"
  location = var.location
  tags     = var.tags
}

# VNet + Subnets (secure isolation)
# - One subnet for AKS (Cervilog runtime)
# - One subnet for Postgres (secure, private)
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "${local.prefix}-aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "postgres" {
  name                 = "${local.prefix}-postgres-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  delegation {
    name = "postgres-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
    }
  }
}

# ACR for Cervilog images
resource "azurerm_container_registry" "acr" {
  name                = replace("${local.prefix}acr", "-", "")
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = var.tags
}

# Log Analytics (healthcare compliance logging)
# collects logs from AKS and other resources for monitoring and compliance
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "${local.prefix}-logs"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# AKS (Cervilog runtime)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${local.prefix}-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = local.prefix

  network_profile {
    network_plugin = "azure"
    service_cidr = "192.168.0.0/16" # separate CIDR for AKS services to aviod conflicts with VNet address space
    dns_service_ip = "192.168.0.10" # IP from service CIDR range, required for Cluster Networking config.
  }

  # Worker pools (Cervilog runtime nodes)
  default_node_pool {
    name           = "default"
    node_count     = var.aks_node_count
    vm_size        = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  # Provide AKS with a system-assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  azure_policy_enabled = true # Enforce Azure Policy for security and compliance

  # Integrate with Log Analytics for monitoring and compliance
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
  }

  tags = var.tags
}

# PostgreSQL Database Server
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                   = "${local.prefix}-postgres"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = "15" # version, ideally long-term supported
  tags = var.tags
  
  delegated_subnet_id    = azurerm_subnet.postgres.id # deploy in isolated subnet for security
  private_dns_zone_id    = azurerm_private_dns_zone.private.id # integrate with private DNS for secure connectivity inside VNet
  public_network_access_enabled = false # disable public access for security
  
  administrator_login    = var.postgres_admin
  administrator_password = var.postgres_password
  
  zone                   = "1"
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
}

# Private DNS Zone for PostgreSQL (secure name resolution within VNet)
resource "azurerm_private_dns_zone" "private" {
  name                = "postgres.database.azure.com."
  resource_group_name = azurerm_resource_group.rg.name
}

# Outputs for pipeline/Cervilog
output "resource_group" { 
	value = azurerm_resource_group.rg.name 
}

output "aks_kubeconfig" { 
	value = azurerm_kubernetes_cluster.aks.kube_config_raw 
	sensitive = true # required by policy
}

output "acr_login_server" { 
	value = azurerm_container_registry.acr.login_server 
}

output "postgres_fqdn" { 
	value = azurerm_postgresql_flexible_server.postgres.fqdn 
}

output "log_analytics_workspace_id" { 
	value = azurerm_log_analytics_workspace.logs.id 
}
