
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


$domainCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist (($SDNConfig.SDNDomainFQDN.Split(".")[0]) + "\Administrator"), `
(ConvertTo-SecureString $SDNConfig.SDNAdminPassword  -AsPlainText -Force)

# Set-Credentials
$localCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist "Administrator", (ConvertTo-SecureString $SDNConfig.SDNAdminPassword -AsPlainText -Force)

$azsmgmtip = $SDNConfig.AzSMGMTIP.Replace('/24', '')
Write-Host "azsmgmtip is " $azsmgmtip

# Sleep to get around race condition on fast systems
Start-Sleep -Seconds 10

Invoke-Command -ComputerName azsmgmt -Credential $localCred  -ScriptBlock {

    # Creds

    $localCred = $using:localCred
    $domainCred = $using:domainCred
    $SDNConfig = $using:SDNConfig

    # Set variables

    $ParentDiskPath = "C:\VMs\Base\"
    $vmpath = "D:\VMs\"
    $OSVHDX = "GUI.vhdx"
    $coreOSVHDX = "AzSHCI.vhdx"
    $VMStoragePathforOtherHosts = $SDNConfig.HostVMPath
    $SourcePath = 'C:\VMConfigs'
    $Assetspath = "$SourcePath\Assets"

    $ErrorActionPreference = "Stop"
    $VerbosePreference = "Continue"
    $WarningPreference = "SilentlyContinue"

    # Disable Fabric2 Network Adapter
    
    $fabTwo = $null
    while ($fabTwo -ne 'Disabled') {
        Write-Verbose "Disabling Fabric2 Adapter"
        Get-Netadapter FABRIC2 | Disable-NetAdapter -Confirm:$false | Out-Null
        $fabTwo = (Get-Netadapter -Name FABRIC2).Status 

    }
    # # Enable WinRM on AzSMGMT
    # $VerbosePreference = "Continue"
    # Write-Verbose "Enabling PSRemoting on $env:COMPUTERNAME"
    # $VerbosePreference = "SilentlyContinue"
    # Set-Item WSMan:\localhost\Client\TrustedHosts *  -Confirm:$false -Force
    # Enable-PSRemoting | Out-Null
    

    # #Disable ServerManager Auto-Start

    # Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask | Out-Null

    # # Create Hyper-V Networking for AzSMGMT

    # Import-Module Hyper-V 

    # Try {

    #     $VerbosePreference = "Continue"
    #     Write-Verbose "Creating VM Switch on $env:COMPUTERNAME"

    #     New-VMSwitch  -AllowManagementOS $true -Name "vSwitch-Fabric" -NetAdapterName FABRIC -MinimumBandwidthMode None | Out-Null

    #     # Configure NAT on AzSMGMT

    #     if ($SDNConfig.natConfigure) {

    #         Write-Verbose "Configuring NAT on $env:COMPUTERNAME"

    #         $VerbosePreference = "SilentlyContinue"

    #         $natSubnet = $SDNConfig.natSubnet
    #         $Subnet = ($natSubnet.Split("/"))[0]
    #         $Prefix = ($natSubnet.Split("/"))[1]
    #         $natEnd = $Subnet.Split(".")
    #         $natIP = ($natSubnet.TrimEnd("0./$Prefix")) + (".1")
    #         $provIP = $SDNConfig.BGPRouterIP_ProviderNetwork.TrimEnd("1/24") + "254"
    #         $vlan200IP = $SDNConfig.BGPRouterIP_VLAN200.TrimEnd("1/24") + "250"
    #         $provGW = $SDNConfig.BGPRouterIP_ProviderNetwork.TrimEnd("/24")
    #         $vlanGW = $SDNConfig.BGPRouterIP_VLAN200.TrimEnd("/24")
    #         $provpfx = $SDNConfig.BGPRouterIP_ProviderNetwork.Split("/")[1]
    #         $vlanpfx = $SDNConfig.BGPRouterIP_VLAN200.Split("/")[1]
    #         $simInternetIP = $SDNConfig.BGPRouterIP_SimulatedInternet.TrimEnd("1/24") + "254"
    #         $simInternetGW = $SDNConfig.BGPRouterIP_SimulatedInternet.TrimEnd("/24")
    #         $simInternetPFX = $SDNConfig.BGPRouterIP_SimulatedInternet.Split("/")[1]

    #         New-VMSwitch -SwitchName NAT -SwitchType Internal -MinimumBandwidthMode None | Out-Null
    #         New-NetIPAddress -IPAddress $natIP -PrefixLength $Prefix -InterfaceAlias "vEthernet (NAT)" | Out-Null
    #         New-NetNat -Name NATNet -InternalIPInterfaceAddressPrefix $natSubnet | Out-Null

    #         $VerbosePreference = "Continue"
    #         Write-Verbose "Configuring Provider NIC on $env:COMPUTERNAME"
    #         $VerbosePreference = "SilentlyContinue"

    #         $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "PROVIDER" }
    #         Rename-NetAdapter -name $NIC.name -newname "PROVIDER" | Out-Null
    #         New-NetIPAddress -InterfaceAlias "PROVIDER" –IPAddress $provIP -PrefixLength $provpfx | Out-Null

    #         <#
    #         $index = (Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.netconnectionid -eq "PROVIDER" }).InterfaceIndex
    #         $NetInterface = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.InterfaceIndex -eq $index }     
    #         $NetInterface.SetGateways($tranpfx) | Out-Null
    #         #>

    #         $VerbosePreference = "Continue"
    #         Write-Verbose "Configuring VLAN200 NIC on $env:COMPUTERNAME"
    #         $VerbosePreference = "SilentlyContinue"

    #         $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "VLAN200" }
    #         Rename-NetAdapter -name $NIC.name -newname "VLAN200" | Out-Null
    #         New-NetIPAddress -InterfaceAlias "VLAN200" –IPAddress $vlan200IP -PrefixLength $vlanpfx | Out-Null

    #         <#
    #         $index = (Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.netconnectionid -eq "VLAN200" }).InterfaceIndex
    #         $NetInterface = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.InterfaceIndex -eq $index }     
    #         $NetInterface.SetGateways($vlanGW) | Out-Null
    #         #>

    #         $VerbosePreference = "Continue"
    #         Write-Verbose "Configuring simulatedInternet NIC on $env:COMPUTERNAME"
    #         $VerbosePreference = "SilentlyContinue"


    #         $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "simInternet" }
    #         Rename-NetAdapter -name $NIC.name -newname "simInternet" | Out-Null
    #         New-NetIPAddress -InterfaceAlias "simInternet" –IPAddress $simInternetIP -PrefixLength $simInternetPFX | Out-Null

    #         <#
    #         $index = (Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.netconnectionid -eq "simInternet" }).InterfaceIndex
    #         $NetInterface = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.InterfaceIndex -eq $index }     
    #         $NetInterface.SetGateways($simInternetGW) | Out-Null
    #         #>

    #         Write-Verbose "Making NAT Work"


    #         $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" `
    #         | Where-Object { $_.RegistryValue -eq "Network Adapter" -or $_.RegistryValue -eq "NAT" }

    #         Rename-NetAdapter -name $NIC.name -newname "Internet" | Out-Null 

    #         $internetIP = $SDNConfig.natHostSubnet.Replace("0/24", "5")
    #         $internetGW = $SDNConfig.natHostSubnet.Replace("0/24", "1")

    #         Start-Sleep -Seconds 30

    #         $internetIndex = (Get-NetAdapter | Where-Object { $_.Name -eq "Internet" }).ifIndex

    #         Start-Sleep -Seconds 30

    #         New-NetIPAddress -IPAddress $internetIP -PrefixLength 24 -InterfaceIndex $internetIndex -DefaultGateway $internetGW -AddressFamily IPv4 | Out-Null
    #         Set-DnsClientServerAddress -InterfaceIndex $internetIndex -ServerAddresses ($SDNConfig.natDNS) | Out-Null

    #         #Enable Large MTU

    #         $VerbosePreference = "Continue"
    #         Write-Verbose "Configuring MTU on all Adapters"
    #         $VerbosePreference = "SilentlyContinue"
    #         Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -ne "Ethernet" } | Set-NetAdapterAdvancedProperty `
    #             -RegistryValue $SDNConfig.SDNLABMTU -RegistryKeyword "*JumboPacket"
    #         $VerbosePreference = "Continue"

    #         Start-Sleep -Seconds 30

    #         #Provision Public and Private VIP Route

    #         New-NetRoute -DestinationPrefix $SDNConfig.PublicVIPSubnet -NextHop $provGW -InterfaceAlias PROVIDER | Out-Null

    #         # Remove Gateway from Fabric NIC
    #         Write-Verbose "Removing Gateway from Fabric NIC" 
    #         $index = (Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.netconnectionid -match "vSwitch-Fabric" }).InterfaceIndex
    #         Remove-NetRoute -InterfaceIndex $index -DestinationPrefix "0.0.0.0/0" -Confirm:$false

    #     }

    # }

    # Catch {

    #     throw $_

    # }

}

# # Provision DC

# Write-Verbose "Provisioning Domain Controller in Managment VM"

#   # Provision BGP TOR Router

#   Invoke-Command -VMName AzSMGMT -Credential $localCred -ScriptBlock {

#     $SDNConfig = $using:SDNConfig
#     $localcred = $using:localcred
#     $domainCred = $using:domainCred
#     $ParentDiskPath = "C:\VMs\Base\"
#     $vmpath = "D:\VMs\"
#     $OSVHDX = "AzSHCI.vhdx"
#     $VMStoragePathforOtherHosts = $SDNConfig.HostVMPath
#     $SourcePath = 'C:\VMConfigs'

#     $ProgressPreference = "SilentlyContinue"
#     $ErrorActionPreference = "Stop"
#     $VerbosePreference = "Continue"
#     $WarningPreference = "SilentlyContinue"    

#     $VMName = "bgp-tor-router"

#     # Create Host OS Disk

#     Write-Verbose "Creating $VMName differencing disks"

#     $params = @{

#         ParentPath = ($ParentDiskPath + $OSVHDX)
#         Path       = ($vmpath + $VMName + '\' + $VMName + '.vhdx') 

#     }

#     New-VHD @params -Differencing | Out-Null

#     # Create VM

#     $params = @{

#         Name       = $VMName
#         VHDPath    = ($vmpath + $VMName + '\' + $VMName + '.vhdx')
#         Path       = ($vmpath + $VMName)
#         Generation = 2

#     }

#     Write-Verbose "Creating the $VMName VM."
#     New-VM @params | Out-Null

#     # Set VM Configuration

#     Write-Verbose "Setting $VMName's VM Configuration"

#     $params = @{

#         VMName               = $VMName
#         DynamicMemoryEnabled = $true
#         StartupBytes         = $SDNConfig.MEM_BGP
#         MaximumBytes         = $SDNConfig.MEM_BGP
#         MinimumBytes         = 500MB
#     }

#     Set-VMMemory @params | Out-Null
#     Remove-VMNetworkAdapter -VMName $VMName -Name "Network Adapter" | Out-Null 
#     Set-VMProcessor -VMName $VMName -Count 2 | Out-Null
#     set-vm -Name $VMName -AutomaticStopAction TurnOff | Out-Null

#     # Configure VM Networking

#     Write-Verbose "Configuring $VMName's Networking"
#     Add-VMNetworkAdapter -VMName $VMName -Name Mgmt -SwitchName vSwitch-Fabric -DeviceNaming On
#     Add-VMNetworkAdapter -VMName $VMName -Name Provider -SwitchName vSwitch-Fabric -DeviceNaming On
#     Add-VMNetworkAdapter -VMName $VMName -Name VLAN200 -SwitchName vSwitch-Fabric -DeviceNaming On
#     Add-VMNetworkAdapter -VMName $VMName -Name SIMInternet -SwitchName vSwitch-Fabric -DeviceNaming On
#     Set-VMNetworkAdapterVlan -VMName $VMName -VMNetworkAdapterName Provider -Access -VlanId $SDNConfig.providerVLAN
#     Set-VMNetworkAdapterVlan -VMName $VMName -VMNetworkAdapterName VLAN200 -Access -VlanId $SDNConfig.vlan200VLAN
#     Set-VMNetworkAdapterVlan -VMName $VMName -VMNetworkAdapterName SIMInternet -Access -VlanId $SDNConfig.simInternetVLAN
       

#     # Add NAT Adapter

#     if ($SDNConfig.natConfigure) {

#         Add-VMNetworkAdapter -VMName $VMName -Name NAT -SwitchName NAT -DeviceNaming On
#     }    

#     # Configure VM
#     Set-VMProcessor -VMName $VMName  -Count 2
#     Set-VM -Name $VMName -AutomaticStartAction Start -AutomaticStopAction ShutDown | Out-Null      

#     # Inject Answer File

#     Write-Verbose "Mounting Disk Image and Injecting Answer File into the $VMName VM." 
#     New-Item -Path "C:\TempBGPMount" -ItemType Directory | Out-Null
#     Mount-WindowsImage -Path "C:\TempBGPMount" -Index 1 -ImagePath ($vmpath + $VMName + '\' + $VMName + '.vhdx') | Out-Null

#     New-Item -Path C:\TempBGPMount\windows -ItemType Directory -Name Panther -Force | Out-Null

#     $Password = $SDNConfig.SDNAdminPassword
#     $ProductKey = $SDNConfig.GUIProductKey

#     $Unattend = @"
# <?xml version="1.0" encoding="utf-8"?>
# <unattend xmlns="urn:schemas-microsoft-com:unattend">
#     <servicing>
#         <package action="configure">
#             <assemblyIdentity name="Microsoft-Windows-Foundation-Package" version="10.0.14393.0" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="" />
#             <selection name="RemoteAccessServer" state="true" />
#             <selection name="RasRoutingProtocols" state="true" />
#         </package>
#     </servicing>
#     <settings pass="specialize">
#         <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
#             <DomainProfile_EnableFirewall>false</DomainProfile_EnableFirewall>
#             <PrivateProfile_EnableFirewall>false</PrivateProfile_EnableFirewall>
#             <PublicProfile_EnableFirewall>false</PublicProfile_EnableFirewall>
#         </component>
#         <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
#             <ComputerName>$VMName</ComputerName>
#         </component>
#         <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
#             <fDenyTSConnections>false</fDenyTSConnections>
#         </component>
#         <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
#             <UserLocale>en-us</UserLocale>
#             <UILanguage>en-us</UILanguage>
#             <SystemLocale>en-us</SystemLocale>
#             <InputLocale>en-us</InputLocale>
#         </component>
#     </settings>
#     <settings pass="oobeSystem">
#         <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
#             <OOBE>
#                 <HideEULAPage>true</HideEULAPage>
#                 <SkipMachineOOBE>true</SkipMachineOOBE>
#                 <SkipUserOOBE>true</SkipUserOOBE>
#                 <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
#             </OOBE>
#             <UserAccounts>
#                 <AdministratorPassword>
#                     <Value>$Password</Value>
#                     <PlainText>true</PlainText>
#                 </AdministratorPassword>
#             </UserAccounts>
#         </component>
#     </settings>
#     <cpi:offlineImage cpi:source="" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
# </unattend>    
# "@
#     Set-Content -Value $Unattend -Path "C:\TempBGPMount\Windows\Panther\Unattend.xml" -Force

#     Write-Verbose "Enabling Remote Access"
#     Enable-WindowsOptionalFeature -Path C:\TempBGPMount -FeatureName RasRoutingProtocols -All -LimitAccess | Out-Null
#     Enable-WindowsOptionalFeature -Path C:\TempBGPMount -FeatureName RemoteAccessPowerShell -All -LimitAccess | Out-Null
#     Write-Verbose "Dismounting Disk Image for $VMName VM." 
#     Dismount-WindowsImage -Path "C:\TempBGPMount" -Save | Out-Null
#     Remove-Item "C:\TempBGPMount"

#     # Start the VM

#     Write-Verbose "Starting $VMName VM."
#     Start-VM -Name $VMName      

#     # Wait for VM to be started

#     while ((Invoke-Command -VMName $VMName -Credential $localcred { "Test" } -ea SilentlyContinue) -ne "Test") { Start-Sleep -Seconds 1 }    

#     Write-Verbose "Configuring $VMName" 

#     Invoke-Command -VMName $VMName -Credential $localCred -ArgumentList $SDNConfig -ScriptBlock {

#         $ErrorActionPreference = "Stop"
#         $VerbosePreference = "Continue"
#         $WarningPreference = "SilentlyContinue"

#         $SDNConfig = $args[0]
#         $Gateway = $SDNConfig.SDNLABRoute
#         $DNS = $SDNConfig.SDNLABDNS
#         $Domain = $SDNConfig.SDNDomainFQDN
#         $natSubnet = $SDNConfig.natSubnet
#         $natDNS = $SDNConfig.natSubnet
#         $MGMTIP = $SDNConfig.BGPRouterIP_MGMT.Split("/")[0]
#         $MGMTPFX = $SDNConfig.BGPRouterIP_MGMT.Split("/")[1]
#         $PNVIP = $SDNConfig.BGPRouterIP_ProviderNetwork.Split("/")[0]
#         $PNVPFX = $SDNConfig.BGPRouterIP_ProviderNetwork.Split("/")[1]
#         $VLANIP = $SDNConfig.BGPRouterIP_VLAN200.Split("/")[0]
#         $VLANPFX = $SDNConfig.BGPRouterIP_VLAN200.Split("/")[1]
#         $simInternetIP = $SDNConfig.BGPRouterIP_SimulatedInternet.Split("/")[0]
#         $simInternetPFX = $SDNConfig.BGPRouterIP_SimulatedInternet.Split("/")[1]

#         # Renaming NetAdapters and setting up the IPs inside the VM using CDN parameters

#         Write-Verbose "Configuring $env:COMPUTERNAME's Networking"
#         $VerbosePreference = "SilentlyContinue"  
#         $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "Mgmt" }
#         Rename-NetAdapter -name $NIC.name -newname "Mgmt" | Out-Null
#         New-NetIPAddress -InterfaceAlias "Mgmt" –IPAddress $MGMTIP -PrefixLength $MGMTPFX | Out-Null
#         Set-DnsClientServerAddress -InterfaceAlias “Mgmt” -ServerAddresses $DNS] | Out-Null
#         $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "PROVIDER" }
#         Rename-NetAdapter -name $NIC.name -newname "PROVIDER" | Out-Null
#         New-NetIPAddress -InterfaceAlias "PROVIDER" –IPAddress $PNVIP -PrefixLength $PNVPFX | Out-Null
#         $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "VLAN200" }
#         Rename-NetAdapter -name $NIC.name -newname "VLAN200" | Out-Null
#         New-NetIPAddress -InterfaceAlias "VLAN200" –IPAddress $VLANIP -PrefixLength $VLANPFX | Out-Null
#         $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "SIMInternet" }
#         Rename-NetAdapter -name $NIC.name -newname "SIMInternet" | Out-Null
#         New-NetIPAddress -InterfaceAlias "SIMInternet" –IPAddress $simInternetIP -PrefixLength $simInternetPFX | Out-Null      

#         # if NAT is selected, configure the adapter
   
#         if ($SDNConfig.natConfigure) {

#             $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" `
#             | Where-Object { $_.RegistryValue -eq "NAT" }
#             Rename-NetAdapter -name $NIC.name -newname "NAT" | Out-Null
#             $Subnet = ($natSubnet.Split("/"))[0]
#             $Prefix = ($natSubnet.Split("/"))[1]
#             $natEnd = $Subnet.Split(".")
#             $natIP = ($natSubnet.TrimEnd("0./$Prefix")) + (".10")
#             $natGW = ($natSubnet.TrimEnd("0./$Prefix")) + (".1")
#             New-NetIPAddress -InterfaceAlias "NAT" –IPAddress $natIP -PrefixLength $Prefix -DefaultGateway $natGW | Out-Null
#             if ($natDNS) {
#                 Set-DnsClientServerAddress -InterfaceAlias "NAT" -ServerAddresses $natDNS | Out-Null
#             }
#         }

#         # Configure Trusted Hosts

#         Write-Verbose "Configuring Trusted Hosts"
#         Set-Item WSMan:\localhost\Client\TrustedHosts * -Confirm:$false -Force
        
        
#         # Installing Remote Access

#         Write-Verbose "Installing Remote Access on $env:COMPUTERNAME" 
#         $VerbosePreference = "SilentlyContinue"
#         Install-RemoteAccess -VPNType RoutingOnly | Out-Null

#         # Adding a BGP Router to the VM

#         $VerbosePreference = "Continue"
#         Write-Verbose "Installing BGP Router on $env:COMPUTERNAME"
#         $VerbosePreference = "SilentlyContinue"

#         $params = @{

#             BGPIdentifier  = $PNVIP
#             LocalASN       = $SDNConfig.BGPRouterASN
#             TransitRouting = 'Enabled'
#             ClusterId      = 1
#             RouteReflector = 'Enabled'

#         }

#         Add-BgpRouter @params

#         #Add-BgpRouter -BGPIdentifier $PNVIP -LocalASN $SDNConfig.BGPRouterASN `
#         # -TransitRouting Enabled -ClusterId 1 -RouteReflector Enabled

#         # Configure BGP Peers

#         if ($SDNConfig.ConfigureBGPpeering -and $SDNConfig.ProvisionNC) {

#             Write-Verbose "Peering future MUX/GWs"

#             $Mux01IP = ($SDNConfig.BGPRouterIP_ProviderNetwork.TrimEnd("1/24")) + "4"
#             $GW01IP = ($SDNConfig.BGPRouterIP_ProviderNetwork.TrimEnd("1/24")) + "5"
#             $GW02IP = ($SDNConfig.BGPRouterIP_ProviderNetwork.TrimEnd("1/24")) + "6"

#             $params = @{

#                 Name           = 'MUX01'
#                 LocalIPAddress = $PNVIP
#                 PeerIPAddress  = $Mux01IP
#                 PeerASN        = $SDNConfig.SDNASN
#                 OperationMode  = 'Mixed'
#                 PeeringMode    = 'Automatic'
#             }

#             Add-BgpPeer @params -PassThru

#             $params.Name = 'GW01'
#             $params.PeerIPAddress = $GW01IP

#             Add-BgpPeer @params -PassThru

#             $params.Name = 'GW02'
#             $params.PeerIPAddress = $GW02IP

#             Add-BgpPeer @params -PassThru    

#         }

#         # Enable Large MTU

#         Write-Verbose "Configuring MTU on all Adapters"
#         Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Set-NetAdapterAdvancedProperty -RegistryValue $SDNConfig.SDNLABMTU -RegistryKeyword "*JumboPacket"   

#     }     

#     $ErrorActionPreference = "Continue"
#     $VerbosePreference = "SilentlyContinue"
#     $WarningPreference = "Continue"

# } -AsJob
