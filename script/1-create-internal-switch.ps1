$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 

Write-Host "Import Configuration Module"
$ConfigurationDataFile = '.\AzSHCISandbox-Config.psd1'
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

$VerbosePreference = "SilentlyContinue" 
Import-Module Hyper-V 
$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

$InternalSwitch = $SDNConfig.InternalSwitch

Write-Verbose "Creating Internal Switch"


$pswitchname = $InternalSwitch
$SDNConfig = $SDNConfig

$querySwitch = Get-VMSwitch -Name $pswitchname -ErrorAction Ignore

if (!$querySwitch) {
    New-VMSwitch -SwitchType Internal -MinimumBandwidthMode None -Name $pswitchname | Out-Null

    #Assign IP to Internal Switch
    $InternalAdapter = Get-Netadapter -Name "vEthernet ($pswitchname)"
    $IP = $SDNConfig.PhysicalHostInternalIP
    $Prefix = ($SDNConfig.AzSMGMTIP.Split("/"))[1]
    $Gateway = $SDNConfig.SDNLABRoute
    $DNS = $SDNConfig.SDNLABDNS

    $params = @{

        AddressFamily  = "IPv4"
        IPAddress      = $IP
        PrefixLength   = $Prefix
        DefaultGateway = $Gateway
        
    }

    $InternalAdapter | New-NetIPAddress @params | Out-Null
    $InternalAdapter | Set-DnsClientServerAddress -ServerAddresses $DNS | Out-Null
}
Else { Write-Verbose "Internal Switch $pswitchname already exists. Not creating a new internal switch." }
