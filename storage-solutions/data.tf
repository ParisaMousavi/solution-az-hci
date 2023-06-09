data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.remote_state_resource_group_name
    storage_account_name = var.remote_state_storage_account_name
    container_name       = "enterprise-network"
    key                  = "terraform.tfstate"
  }
}

data "terraform_remote_state" "monitoring" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.remote_state_resource_group_name
    storage_account_name = var.remote_state_storage_account_name
    container_name       = "enterprise-monitoring"
    key                  = "terraform.tfstate"
  }
}

data "terraform_remote_state" "parent" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.remote_state_resource_group_name
    storage_account_name = var.remote_state_storage_account_name
    container_name       = "solution-az-hci"
    key                  = "terraform.tfstate"
  }
}

data "azuread_group" "aks_cluster_admin" {
  display_name     = "AKS Cluster Admin"
  security_enabled = true
}