module "stg_name" {
  source             = "github.com/ParisaMousavi/az-naming//st?ref=main"
  prefix             = var.prefix
  name               = var.name
  stage              = var.stage
  location_shortname = var.location_shortname
}

resource "azurerm_storage_account" "this" {
  name                     = module.stg_name.result
  location                 = var.location
  resource_group_name      = data.terraform_remote_state.parent.outputs.resource_group_name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "this" {
  name                 = "sharename"
  storage_account_name = azurerm_storage_account.this.name
  quota                = 50
}

