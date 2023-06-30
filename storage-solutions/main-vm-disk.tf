# module "vm_disk_name" {
#   source             = "github.com/ParisaMousavi/az-naming//disk?ref=main"
#   prefix             = var.prefix
#   name               = var.name
#   stage              = var.stage
#   location_shortname = var.location_shortname
# }

# resource "azurerm_managed_disk" "this" {
#   count = 4
#   name                 = "${module.vm_disk_name.result}-${count.index}"
#   location                 = var.location
#   resource_group_name      = data.terraform_remote_state.parent.outputs.resource_group_name
#   storage_account_type = "StandardSSD_LRS"
#   create_option        = "Empty"
#   disk_size_gb         = 256
# }

# resource "azurerm_virtual_machine_data_disk_attachment" "this" {
#   count = 4
#   managed_disk_id    = azurerm_managed_disk.this[count.index].id
#   virtual_machine_id = data.terraform_remote_state.parent.outputs.vm_id
#   lun                = count.index
#   caching            = "ReadWrite"
# }
