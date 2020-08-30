provider "azuread" {
  version = "= 0.11"
}

provider "azurerm" {
  version = "~> 2.0"
  features {}
}

provider "random" {
  version = "=2.2.1"
}

locals {
  region_codes = {
    westeurope = "we"
  }
}

module "spinku_label" {
  source      = "git::https://github.com/cloudposse/terraform-null-label.git?ref=0.16.0"
  namespace   = "spinku"
  name        = var.projectName
  environment = "${local.region_codes[var.location]}-${var.environment}"
  delimiter   = "-"
}

resource "azurerm_resource_group" "spinku" {
  name     = "${module.spinku_label.id}-rg"
  location = var.location
}

resource "azuread_application" "spinku" {
  name                       = "${module.spinku_label.id}-ar"
  homepage                   = "http://placeholder"
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = true
}

resource "azuread_service_principal" "spinku" {
  application_id               = azuread_application.spinku.application_id
  app_role_assignment_required = false
  
}

resource "random_password" "sp_password" {
  length = 16
}

resource "azuread_service_principal_password" "spinku" {
  service_principal_id = azuread_service_principal.spinku.id
  description          = "Managed password"
  value                = random_password.sp_password.result
  end_date             = "2099-01-01T01:02:03Z"
}

resource "azurerm_kubernetes_cluster" "spinku" {
  name                = "${module.spinku_label.id}-aks"
  location            = azurerm_resource_group.spinku.location
  resource_group_name = azurerm_resource_group.spinku.name
  dns_prefix          = "${module.spinku_label.id}-k8s"

  kubernetes_version  = "1.15.12"

  default_node_pool {
    name            = "default"
    node_count      = 2
    vm_size         = "Standard_D2_v2"
    os_disk_size_gb = 30
  }

  service_principal {
    client_id     = azuread_application.spinku.application_id
    client_secret = random_password.sp_password.result
  }

  role_based_access_control {
    enabled = true
  }

  addon_profile {
    kube_dashboard {
      enabled = true
    }
  }

  tags = {
    environment = var.environment
  }

  lifecycle {
    ignore_changes = [
      service_principal
    ]
  }

  depends_on = [
    azuread_service_principal.spinku,
    azuread_service_principal_password.spinku
  ]
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.spinku.kube_config_raw
}