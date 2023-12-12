$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 

Write-Host "Import Configuration Module"
$ConfigurationDataFile = '.\AzSHCISandbox-Config.psd1'
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

$VerbosePreference = "SilentlyContinue" 
Import-Module Hyper-V 
$VerbosePreference = "Continue"
$ErrorActionPreference = "Continue" 

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

Write-Verbose "Generating Single Host Placement"

$VMPlacement = @()
foreach ($AzSHOST in $AzSHOSTs) {
    $VMPlacement = $VMPlacement + [pscustomobject]@{AzSHOST = $AzSHOST; VMHost = $env:COMPUTERNAME }
}

# Start Virtual Machines

foreach ($VMHost in $VMPlacement) {

    Write-Verbose "Starting VM: $VMHost"
    Start-VM -ComputerName $VMHost.VMhost -Name $VMHost.AzSHOST

} 

