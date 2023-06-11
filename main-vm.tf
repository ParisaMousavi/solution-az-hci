
module "rg_name" {
  source             = "github.com/ParisaMousavi/az-naming//rg?ref=2022.10.07"
  prefix             = var.prefix
  name               = var.name
  stage              = var.stage
  location_shortname = var.location_shortname
}

module "resourcegroup" {
  # https://{PAT}@dev.azure.com/{organization}/{project}/_git/{repo-name}
  source   = "github.com/ParisaMousavi/az-resourcegroup?ref=2022.10.07"
  location = var.location
  name     = module.rg_name.result
  tags = {
    CostCenter = "ABC000CBA"
    By         = "parisamoosavinezhad@hotmail.com"
  }
}

#-----------------------------------------------
# Deploy Hyper-V supported host server
# Install hyper-v on machine
# https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/get-started/install-the-hyper-v-role-on-windows-server
# I used this command: Install-WindowsFeature -Name Hyper-V -ComputerName <computer_name> -IncludeManagementTools -Restart
#-----------------------------------------------
module "vm_name" {
  source             = "github.com/ParisaMousavi/az-naming//vm?ref=main"
  prefix             = var.prefix
  name               = var.name
  stage              = var.stage
  location_shortname = var.location_shortname
}

resource "azurerm_public_ip" "this_win" {
  name                = "${module.vm_name.result}-pip"
  location            = module.resourcegroup.location
  resource_group_name = module.resourcegroup.name
  allocation_method   = "Static"
  sku                 = "Standard" # because I use it for bastion must be standard
  tags = {
    CostCenter = "ABC000CBA"
    By         = "parisamoosavinezhad@hotmail.com"
  }
}

resource "azurerm_network_interface" "this_win" {
  name                = "${module.vm_name.result}-nic"
  location            = module.resourcegroup.location
  resource_group_name = module.resourcegroup.name

  ip_configuration {
    primary                       = true
    name                          = "internal"
    subnet_id                     = data.terraform_remote_state.network.outputs.subnets["vm-win"].id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = azurerm_public_ip.this_win.id
    # I added the PIP to the Bastion instead of VM
  }
}


module "nsg_win_name" {
  source             = "github.com/ParisaMousavi/az-naming//nsg?ref=main"
  prefix             = var.prefix
  name               = var.name
  stage              = var.stage
  assembly           = "win"
  location_shortname = var.location_shortname
}

module "nsg_win" {
  source              = "github.com/ParisaMousavi/az-nsg-v2?ref=main"
  name                = module.nsg_win_name.result
  location            = module.resourcegroup.location
  resource_group_name = module.resourcegroup.name
  security_rules = [
    {
      name                       = "RDP"
      priority                   = 110
      access                     = "Allow"
      direction                  = "Inbound"
      protocol                   = "Tcp"
      description                = "RDP: Allow inbound from any to 3389"
      destination_address_prefix = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "*"
      source_port_range          = "*"
    }
  ]
  additional_tags = {
    CostCenter = "ABC000CBA"
    By         = "parisamoosavinezhad@hotmail.com"
  }
}

resource "azurerm_network_interface_security_group_association" "this_win" {
  network_interface_id      = azurerm_network_interface.this_win.id
  network_security_group_id = module.nsg_win.id
}

resource "azurerm_windows_virtual_machine" "this_win" {
  name                = module.vm_name.result
  location            = module.resourcegroup.location
  resource_group_name = module.resourcegroup.name
  size                = "Standard_E16s_v4" #"Standard_B2s" #"Standard_F2"
  admin_username      = "adminuser" # administrator
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.this_win.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # az vm image list --all --publisher "MicrosoftWindowsServer" --location westeurope --offer "WindowsServer"
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

}

resource "azurerm_bastion_host" "this" {
  name                = "examplebastion"
  location            = module.resourcegroup.location
  resource_group_name = module.resourcegroup.name
  ip_configuration {
    name                 = "configuration"
    subnet_id            = data.terraform_remote_state.network.outputs.subnets["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.this_win.id
  }
}
