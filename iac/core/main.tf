# Terraform settings
terraform {
  required_providers { # providers for the infrastructure
    azurerm = {
        source = "hashicorp/azurerm" # provider host name, namespace and type
        version = "~>3.0.2" # provider version enforcement
    }
  }

  required_version = ">=1.5" # terraform version enforcement}
}

# Azure provider setup with subscription context
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "rg" {
  name     = "bratislava2024"
  location = "West Europe"
}
