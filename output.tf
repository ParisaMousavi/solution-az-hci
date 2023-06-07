output "resource_group_name" {
  value = module.resourcegroup.name
}

output "vm_name" {
  value = azurerm_windows_virtual_machine.this_win.name
}

output "vm_id" {
  value = azurerm_windows_virtual_machine.this_win.id
}