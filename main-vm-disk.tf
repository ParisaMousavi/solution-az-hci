module "vm_disk_name" {
  source             = "github.com/ParisaMousavi/az-naming//disk?ref=main"
  prefix             = var.prefix
  name               = var.name
  stage              = var.stage
  location_shortname = var.location_shortname
}

resource "azurerm_managed_disk" "this" {
  count                = 1
  name                 = "${module.vm_disk_name.result}-${count.index}"
  location             = module.resourcegroup.location
  resource_group_name  = module.resourcegroup.name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = 200
}

resource "azurerm_virtual_machine_data_disk_attachment" "this" {
  count              = length(azurerm_managed_disk.this)
  managed_disk_id    = azurerm_managed_disk.this[count.index].id
  virtual_machine_id = azurerm_windows_virtual_machine.this_win.id
  lun                = count.index
  caching            = "ReadWrite"
}

