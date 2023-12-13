
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

if ($natConfigure) {

    if (!$SDNConfig.MultipleHyperVHosts) { $SwitchName = $SDNConfig.InternalSwitch }
    else { $SwitchName = $SDNConfig.MultipleHyperVHostExternalSwitchName }

    Write-Verbose "Creating NAT Switch on switch $SwitchName"
    $VerbosePreference = "SilentlyContinue"

    $natSwitchTarget = $VMPlacement | Where-Object { $_.AzSHOST -eq "AzSMGMT" }
    
    $params = @{

        VMName       = $natSwitchTarget.AzSHOST
        ComputerName = $natSwitchTarget.VMHost
    }

    $exists = $false
    try { $exists = (Get-VMNetworkAdapter -VMName $natSwitchTarget.AzSHOST -Name "NAT") }
    catch { $exists = $false }
    if (!($exists)) { 
        Add-VMNetworkAdapter -VMName $natSwitchTarget.AzSHOST -ComputerName $natSwitchTarget.VMHost -DeviceNaming On     
        Get-VMNetworkAdapter @params | Where-Object { $_.Name -match "Network" } | Connect-VMNetworkAdapter -SwitchName $SDNConfig.natHostVMSwitchName
        Get-VMNetworkAdapter @params | Where-Object { $_.Name -match "Network" } | Rename-VMNetworkAdapter -NewName "NAT"
    
        Get-VM @params | Get-VMNetworkAdapter -Name NAT | Set-VMNetworkAdapter -MacAddressSpoofing On
    }
    else { Write-Host "Adapter VMName " $natSwitchTarget.AzSHOST " Name NAT exist." } 

    #Create PROVIDER NIC in order for NAT to work from SLB/MUX and RAS Gateways

    $exists = $false
    try { $exists = (Get-VMNetworkAdapter -VMName $natSwitchTarget.AzSHOST -Name PROVIDER) }
    catch { $exists = $false }
    if (!($exists)) { 
        Add-VMNetworkAdapter @params -Name PROVIDER -DeviceNaming On -SwitchName $SwitchName    
        Get-VM @params | Get-VMNetworkAdapter -Name PROVIDER | Set-VMNetworkAdapter -MacAddressSpoofing On
        Get-VM @params | Get-VMNetworkAdapter -Name PROVIDER | Set-VMNetworkAdapterVlan -Access -VlanId $SDNConfig.providerVLAN | Out-Null    
        
    }
    else { Write-Host "Adapter VMName "$natSwitchTarget.AzSHOST" Name PROVIDER exist." } 

    #Create VLAN 200 NIC in order for NAT to work from L3 Connections

    $exists = $false
    try { $exists = (Get-VMNetworkAdapter -VMName $natSwitchTarget.AzSHOST -Name VLAN200) }
    catch { $exists = $false }
    if (!($exists)) { 
        Add-VMNetworkAdapter @params -Name VLAN200 -DeviceNaming On -SwitchName $SwitchName
        Get-VM @params | Get-VMNetworkAdapter -Name VLAN200 | Set-VMNetworkAdapter -MacAddressSpoofing On
        Get-VM @params | Get-VMNetworkAdapter -Name VLAN200 | Set-VMNetworkAdapterVlan -Access -VlanId $SDNConfig.vlan200VLAN | Out-Null    
    }
    else { Write-Host "Adapter VMName "$natSwitchTarget.AzSHOST" Name VLAN200 exist." } 

    #Create Simulated Internet NIC in order for NAT to work from L3 Connections

    $exists = $false
    try { $exists = (Get-VMNetworkAdapter -VMName $natSwitchTarget.AzSHOST -Name simInternet) }
    catch { $exists = $false }
    if (!($exists)) { 
        Add-VMNetworkAdapter @params -Name simInternet -DeviceNaming On -SwitchName $SwitchName
        Get-VM @params | Get-VMNetworkAdapter -Name simInternet | Set-VMNetworkAdapter -MacAddressSpoofing On
        Get-VM @params | Get-VMNetworkAdapter -Name simInternet | Set-VMNetworkAdapterVlan -Access -VlanId $SDNConfig.simInternetVLAN | Out-Null
    }
    else { Write-Host "Adapter VMName "$natSwitchTarget.AzSHOST" Name simInternet exist." } 

}
