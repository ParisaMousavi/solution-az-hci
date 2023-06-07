module "vm_disk_name" {
  source             = "github.com/ParisaMousavi/az-naming//disk?ref=main"
  prefix             = var.prefix
  name               = var.name
  stage              = var.stage
  location_shortname = var.location_shortname
}

resource "azurerm_managed_disk" "this" {
  name                 = module.vm_disk_name.result
  location                 = var.location
  resource_group_name      = data.terraform_remote_state.parent.outputs.resource_group_name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = 256
}

resource "azurerm_virtual_machine_data_disk_attachment" "this" {
  managed_disk_id    = azurerm_managed_disk.this.id
  virtual_machine_id = data.terraform_remote_state.parent.outputs.vm_id
  lun                = "0"
  caching            = "ReadWrite"
}
