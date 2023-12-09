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

Write-Verbose "Generating Single Host Placement"

$VMPlacement = @()

foreach ($AzSHOST in $AzSHOSTs) {

    $VMPlacement = $VMPlacement + [pscustomobject]@{AzSHOST = $AzSHOST; VMHost = $env:COMPUTERNAME }
}

Write-Verbose "Copying VHDX Files to Host"

Write-Verbose "Copying $guiVHDXPath to $HostVMPath\GUI.VHDX"
Copy-Item -Path $guiVHDXPath -Destination "$HostVMPath\GUI.VHDX" -Force | Out-Null
Write-Verbose "Copying $azSHCIVHDXPath to $HostVMPath\AzSHCI.VHDX"
Copy-Item -Path $azSHCIVHDXPath -Destination "$HostVMPath\AzSHCI.VHDX" -Force | Out-Null

Write-Host "Create Virtual Machines"

$vmMacs = @()

foreach ($VM in $VMPlacement) {
    Write-Verbose "Generating the VM: $VM" 

    $params = @{

        VMHost     = $VM.VMHost
        AzSHOST    = $VM.AzSHOST
        HostVMPath = $HostVMPath
        VMSwitch   = $VMSwitch
        SDNConfig  = $SDNConfig

    }

    $parentpath = "$HostVMPath\GUI.vhdx"
    $coreparentpath = "$HostVMPath\AzSHCI.vhdx"

    $vmMac = Invoke-Command -ComputerName $VM.VMHost -ScriptBlock { 

        $VerbosePreference = "SilentlyContinue"

        Import-Module Hyper-V

        $VerbosePreference = "Continue"

        $AzSHOST = $using:AzSHOST
        $VMHost = $using:VMHost        
        $HostVMPath = $using:HostVMPath
        $VMSwitch = $using:VMSwitch
        $parentpath = $using:parentpath
        $coreparentpath = $using:coreparentpath
        $SDNConfig = $using:SDNConfig                         
        $S2DDiskSize = $SDNConfig.S2D_Disk_Size
        $NestedVMMemoryinGB = $SDNConfig.NestedVMMemoryinGB
        $AzSMGMTMemoryinGB = $SDNConfig.AzSMGMTMemoryinGB


        Write-Host "Create Differencing Disk. Note: AzSMGMT is GUI"

        if ($AzSHOST -eq "AzSMGMT") {

            $ans = Get-VHD -Path "$HostVMPath\$AzSHOST.vhdx"
            IIf !$ans ( $VHDX1 = New-VHD -ParentPath $parentpath -Path "$HostVMPath\$AzSHOST.vhdx" -Differencing) Write-Host "VHD $HostVMPath\$AzSHOST.vhdx exists."
            
            # $VHDX2 = New-VHD -Path "$HostVMPath\$AzSHOST-Data.vhdx" -SizeBytes 268435456000 -Dynamic
            # $NestedVMMemoryinGB = $AzSMGMTMemoryinGB
        }
        Else { 
           
            $ans = Get-VHD -Path "$HostVMPath\$AzSHOST.vhdx"
            IIf !$ans ( $VHDX1 = New-VHD -ParentPath $coreparentpath -Path "$HostVMPath\$AzSHOST.vhdx" -Differencing ) Write-Host "VHD $HostVMPath\$AzSHOST.vhdx exists."

            # $VHDX1 = New-VHD -ParentPath $coreparentpath -Path "$HostVMPath\$AzSHOST.vhdx" -Differencing 
            # $VHDX2 = New-VHD -Path "$HostVMPath\$AzSHOST-Data.vhdx" -SizeBytes 268435456000 -Dynamic
    
            # # Create S2D Storage       

            # New-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk1.vhdx" -SizeBytes $S2DDiskSize -Dynamic | Out-Null
            # New-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk2.vhdx" -SizeBytes $S2DDiskSize -Dynamic | Out-Null
            # New-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk3.vhdx" -SizeBytes $S2DDiskSize -Dynamic | Out-Null
            # New-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk4.vhdx" -SizeBytes $S2DDiskSize -Dynamic | Out-Null
            # New-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk5.vhdx" -SizeBytes $S2DDiskSize -Dynamic | Out-Null
            # New-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk6.vhdx" -SizeBytes $S2DDiskSize -Dynamic | Out-Null    
    
        } 


    }
}