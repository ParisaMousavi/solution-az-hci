terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.41.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "tfstate"
    storage_account_name = "parisatfstateaziac2weu"
    container_name       = "solution-az-hci"
    key                  = "terraform.tfstate"
  }

}

provider "azurerm" {
  features {
    # I have commended out these lines to prevent the Azure Storage File share deletion
    # resource_group {
    #   prevent_deletion_if_contains_resources = false
    # }
  }
}