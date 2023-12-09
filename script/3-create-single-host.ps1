$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 

Write-Host "Import Configuration Module"
$ConfigurationDataFile = '.\AzSHCISandbox-Config.psd1'
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

$VerbosePreference = "SilentlyContinue" 
Import-Module Hyper-V 
$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

# Set Variables from config file

$NestedVMMemoryinGB = $SDNConfig.NestedVMMemoryinGB
$guiVHDXPath = $SDNConfig.guiVHDXPath
$azSHCIVHDXPath = $SDNConfig.azSHCIVHDXPath
$HostVMPath = $SDNConfig.HostVMPath
$InternalSwitch = $SDNConfig.InternalSwitch
$natDNS = $SDNConfig.natDNS
$natSubnet = $SDNConfig.natSubnet
$natConfigure = $SDNConfig.natConfigure  

# Define SDN host Names. Please do not change names as these names are hardcoded in the setup.
$AzSHOSTs = @("AzSMGMT", "AzSHOST1", "AzSHOST2")

Write-Verbose "No Multiple Hyper-V Hosts defined. Using Single Hyper-V Host Installation"

Write-Verbose "Getting local Parent VHDX Path"

$ParentVHDXPath = $HostVMPath + 'GUI.vhdx'

Write-Verbose "Set-LocalHyperVSettings"
$params = @{

    VirtualHardDiskPath       = $HostVMPath
    VirtualMachinePath        = $HostVMPath
    EnableEnhancedSessionMode = $true

}

Set-VMhost @params 

$coreParentVHDXPath = $HostVMPath + 'AzSHCI.vhdx'

