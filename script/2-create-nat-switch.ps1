$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 

Write-Host "Import Configuration Module"
$ConfigurationDataFile = '.\AzSHCISandbox-Config.psd1'
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

$VerbosePreference = "SilentlyContinue" 
Import-Module Hyper-V 
$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

Write-Verbose "Creating NAT Switch"

$VerbosePreference = "Continue" 

$switchExist = Get-NetAdapter | Where-Object { $_.Name -match $SDNConfig.natHostVMSwitchName }

if (!$switchExist) {

    Write-Host "Step 4 - Create Internal VM Switch for NAT"

    New-VMSwitch -Name $SDNConfig.natHostVMSwitchName -SwitchType Internal | Out-Null

    Write-Host "Step 5 - Applying IP Address to NAT Switch: $($SDNConfig.natHostVMSwitchName)"

    $intIdx = (Get-NetAdapter | Where-Object { $_.Name -match $SDNConfig.natHostVMSwitchName }).ifIndex

    $natIP = $SDNConfig.natHostSubnet.Replace("0/24", "1") # 192.168.128.1

    New-NetIPAddress -IPAddress $natIP -PrefixLength 24 -InterfaceIndex $intIdx | Out-Null

    Write-Host "Step 6 - Create Creating new NETNAT"

    New-NetNat -Name $SDNConfig.natHostVMSwitchName  -InternalIPInterfaceAddressPrefix $SDNConfig.natHostSubnet | Out-Null

}
Else { Write-Host "Internal NetNAT Switch $SDNConfig.natHostVMSwitchName already exists. Not creating a new internal NetNAT switch." }
