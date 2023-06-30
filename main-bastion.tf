module "bastion_name" {
  source             = "github.com/ParisaMousavi/az-naming//bastion?ref=main"
  prefix             = var.prefix
  name               = var.name
  stage              = var.stage
  location_shortname = var.location_shortname
}

resource "azurerm_public_ip" "this_bastion" {
  name                = "${module.bastion_name.result}-pip"
  location            = module.resourcegroup.location
  resource_group_name = module.resourcegroup.name
  allocation_method   = "Static"
  sku                 = "Standard" # because I use it for bastion must be standard
  tags = {
    CostCenter = "ABC000CBA"
    By         = "parisamoosavinezhad@hotmail.com"
  }
}

resource "azurerm_bastion_host" "this" {
  name                = module.bastion_name.result
  location            = module.resourcegroup.location
  resource_group_name = module.resourcegroup.name
  ip_configuration {
    name                 = "configuration"
    subnet_id            = data.terraform_remote_state.network.outputs.subnets["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.this_bastion.id
  }
}
