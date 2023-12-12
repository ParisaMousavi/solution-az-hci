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
$vmMacs = @()
foreach ($AzSHOST in $AzSHOSTs) {

    $VMPlacement = $VMPlacement + [pscustomobject]@{AzSHOST = $AzSHOST; VMHost = $env:COMPUTERNAME }
    $vmMac = ((Get-VMNetworkAdapter -Name SDN -VMName $AzSHOST).MacAddress) -replace '..(?!$)', '$&-'
    $vmMacs += [pscustomobject]@{
        Hostname = $VM.AzSHOST
        vmMAC    = $vmMac
    }
}

# Inject Answer Files and Binaries into Virtual Machines

$corevhdx = 'AzSHCI.vhdx'
$guivhdx = 'GUI.vhdx'

foreach ($AzSHOST in $VMPlacement) {
    
    # Get Drive Paths 

    $HypervHost = $AzSHOST.VMHost
    $DriveLetter = $HostVMPath.Split(':')
    $path = (("\\$HypervHost\") + ($DriveLetter[0] + "$") + ($DriveLetter[1]) + "\" + $AzSHOST.AzSHOST + ".vhdx")       

    # Install Hyper-V Offline

    Write-Verbose "Performing offline installation of Hyper-V to path $path"
    Install-WindowsFeature -Vhd $path -Name Hyper-V, RSAT-Hyper-V-Tools, Hyper-V-Powershell -Confirm:$false | Out-Null
    Start-Sleep -Seconds 20       


    # Mount VHDX

    Write-Verbose "Mounting VHDX file at $path"
    [string]$MountedDrive = (Mount-VHD -Path $path -Passthru | Get-Disk | Get-Partition | Get-Volume).DriveLetter
    $MountedDrive = $MountedDrive.Replace(" ", "")
    Write-Host "MountedDrive is $MountedDrive"

    # Get Assigned MAC Address so we know what NIC to assign a static IP to
    $vmMac = ($vmMacs | Where-Object { $_.Hostname -eq $AzSHost.AzSHOST }).vmMac


    # Inject Answer File

    Write-Verbose "Injecting answer file to $path"

    $AzSHOSTComputerName = $AzSHOST.AzSHOST
    $AzSHOSTIP = $SDNConfig.($AzSHOSTComputerName + "IP")
    $SDNAdminPassword = $SDNConfig.SDNAdminPassword
    $SDNDomainFQDN = $SDNConfig.SDNDomainFQDN
    $SDNLABDNS = $SDNConfig.SDNLABDNS    
    $SDNLabRoute = $SDNConfig.SDNLABRoute         
    $ProductKey = $SDNConfig.GUIProductKey

    # Only inject product key if host is AzSMGMT
    $azsmgmtProdKey = $null
    if ($AzSHOST.AzSHOST -eq "AzSMGMT") { $azsmgmtProdKey = "<ProductKey>$ProductKey</ProductKey>" }
        

    $UnattendXML = @"
    <?xml version="1.0" encoding="utf-8"?>
    <unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
    <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <DomainProfile_EnableFirewall>false</DomainProfile_EnableFirewall>
    <PrivateProfile_EnableFirewall>false</PrivateProfile_EnableFirewall>
    <PublicProfile_EnableFirewall>false</PublicProfile_EnableFirewall>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <ComputerName>$AzSHOSTComputerName</ComputerName>
    $azsmgmtProdKey
    </component>
    <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <fDenyTSConnections>false</fDenyTSConnections>
    </component>
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <UserLocale>en-us</UserLocale>
    <UILanguage>en-us</UILanguage>
    <SystemLocale>en-us</SystemLocale>
    <InputLocale>en-us</InputLocale>
    </component>
    <component name="Microsoft-Windows-IE-ESC" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <IEHardenAdmin>false</IEHardenAdmin>
    <IEHardenUser>false</IEHardenUser>
    </component>
    <component name="Microsoft-Windows-TCPIP" processorArchitecture="wow64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <Interfaces>
    <Interface wcm:action="add">
    <Identifier>$vmMac</Identifier>
    <Ipv4Settings>
    <DhcpEnabled>false</DhcpEnabled>
    </Ipv4Settings>
    <UnicastIpAddresses>
    <IpAddress wcm:action="add" wcm:keyValue="1">$AzSHOSTIP</IpAddress>
    </UnicastIpAddresses>
    <Routes>
    <Route wcm:action="add">
    <Identifier>1</Identifier>
    <NextHopAddress>$SDNLabRoute</NextHopAddress>
    <Prefix>0.0.0.0/0</Prefix>
    <Metric>100</Metric>
    </Route>
    </Routes>
    </Interface>
    </Interfaces>
    </component>
    <component name="Microsoft-Windows-DNS-Client" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <DNSSuffixSearchOrder>
    <DomainName wcm:action="add" wcm:keyValue="1">$SDNDomainFQDN</DomainName>
    </DNSSuffixSearchOrder>
    <Interfaces>
    <Interface wcm:action="add">
    <DNSServerSearchOrder>
    <IpAddress wcm:action="add" wcm:keyValue="1">$SDNLABDNS</IpAddress>
    </DNSServerSearchOrder>
    <Identifier>$vmMac</Identifier>
    <DisableDynamicUpdate>true</DisableDynamicUpdate>
    <DNSDomain>$SDNDomainFQDN</DNSDomain>
    <EnableAdapterDomainNameRegistration>true</EnableAdapterDomainNameRegistration>
    </Interface>
    </Interfaces>
    </component>
    </settings>
    <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <OOBE>
    <HideEULAPage>true</HideEULAPage>
    <SkipMachineOOBE>true</SkipMachineOOBE>
    <SkipUserOOBE>true</SkipUserOOBE>
    <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
     </OOBE>
    <UserAccounts>
    <AdministratorPassword>
    <Value>$SDNAdminPassword</Value>
    <PlainText>true</PlainText>
    </AdministratorPassword>
    </UserAccounts>
    </component>
    </settings>
    <cpi:offlineImage cpi:source="" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
    </unattend>
"@

    Write-Verbose "Mounted Disk Volume is: $MountedDrive" 
    $PantherDir = Get-ChildItem -Path ($MountedDrive + ":\Windows")  -Filter "Panther"
    if (!$PantherDir) { New-Item -Path ($MountedDrive + ":\Windows\Panther") -ItemType Directory -Force | Out-Null }

    Set-Content -Value $UnattendXML -Path ($MountedDrive + ":\Windows\Panther\Unattend.xml") -Force

    # Inject VMConfigs and create folder structure if host is AzSMGMT

    if ($AzSHOST.AzSHOST -eq "AzSMGMT") {

        # Creating folder structure on AzSMGMT

        Write-Verbose "Creating VMs\Base folder structure on AzSMGMT"
        New-Item -Path ($MountedDrive + ":\VMs\Base") -ItemType Directory -Force | Out-Null

        Write-Verbose "Injecting VMConfigs to $path"
        Copy-Item -Path .\AzSHCISandbox-Config.psd1 -Destination ($MountedDrive + ":\") -Recurse -Force
        New-Item -Path ($MountedDrive + ":\") -Name VMConfigs -ItemType Directory -Force | Out-Null
        Copy-Item -Path $guiVHDXPath -Destination ($MountedDrive + ":\VMs\Base\GUI.vhdx") -Force
        Copy-Item -Path $azSHCIVHDXPath -Destination ($MountedDrive + ":\VMs\Base\AzSHCI.vhdx") -Force
        Copy-Item -Path .\Applications\SCRIPTS -Destination ($MountedDrive + ":\VmConfigs") -Recurse -Force
        Copy-Item -Path .\Applications\SDNEXAMPLES -Destination ($MountedDrive + ":\VmConfigs") -Recurse -Force
        Copy-Item -Path '.\Applications\Windows Admin Center' -Destination ($MountedDrive + ":\VmConfigs") -Recurse -Force  

    }       

    # Dismount VHDX

    Write-Verbose "Dismounting VHDX File at path $path"
    Dismount-VHD -Path $path

                                   
}    
