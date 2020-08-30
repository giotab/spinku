terraform {
  required_version = "~>0.12.0"
  required_providers {
    azuread = "= 0.11"
    azurerm = ">= 2.0"
    random  = "~> 2.2"
  }
  backend "azurerm" {
    resource_group_name  = "spinku-terraform"
    storage_account_name = "spinkuterraform"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
