$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Continue" 

Write-Host "Import Configuration Module"
$ConfigurationDataFile = '.\AzSHCISandbox-Config.psd1'
$SDNConfig = Import-PowerShellDataFile -Path $ConfigurationDataFile

$VerbosePreference = "SilentlyContinue" 
Import-Module Hyper-V 
$VerbosePreference = "Continue"

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

Write-Host "Create Virtual Machines"

Write-Verbose "Generating Single Host Placement"

$VMPlacement = @()

foreach ($AzSHOST in $AzSHOSTs) {

    $VMPlacement = $VMPlacement + [pscustomobject]@{AzSHOST = $AzSHOST; VMHost = $env:COMPUTERNAME }
}

$vmMacs = @()

foreach ($VM in $VMPlacement) {

    Write-Verbose "Generating the VM: $VM" 

    $parentpath = "$HostVMPath\GUI.vhdx"
    $coreparentpath = "$HostVMPath\AzSHCI.vhdx"

    $vmMac = Invoke-Command -ComputerName $VM.VMHost -ScriptBlock { 

        $VerbosePreference = "SilentlyContinue"

        Import-Module Hyper-V

        $VerbosePreference = "Continue"

        $AzSHOST = $using:VM.AzSHOST
        $VMHost = $using:VM.VMHost        
        $HostVMPath = $using:HostVMPath
        $VMSwitch = $using:SDNConfig.InternalSwitch
        $parentpath = $using:parentpath
        $coreparentpath = $using:coreparentpath
        $SDNConfig = $using:SDNConfig                         
        $S2DDiskSize = $SDNConfig.S2D_Disk_Size
        $NestedVMMemoryinGB = $SDNConfig.NestedVMMemoryinGB
        $AzSMGMTMemoryinGB = $SDNConfig.AzSMGMTMemoryinGB

        # Create Differencing Disk. Note: AzSMGMT is GUI
        Write-Host "VHD $HostVMPath\$AzSHOST.vhdx"
        if ($AzSHOST -eq "AzSMGMT") {

            $exists= $false
            try { $exists=(Get-VHD -Path "$HostVMPath\$AzSHOST.vhdx") }
            catch { $exists=$false  }
            if (!($exists)) {

                Write-Host "VHD $HostVMPath\$AzSHOST.vhdx doesn't exist."
                $VHDX1 = New-VHD -ParentPath $parentpath -Path "$HostVMPath\$AzSHOST.vhdx" -Differencing 

            }else{ 
                Write-Host "VHD $HostVMPath\$AzSHOST.vhdx exist." 
                $VHDX1 = Get-VHD -Path "$HostVMPath\$AzSHOST.vhdx" 
            }          
            
            $exists= $false
            try { $exists=(Get-VHD -Path "$HostVMPath\$AzSHOST-Data.vhdx") }
            catch { $exists=$false  }
            if (!($exists)) {

                Write-Host "VHD $HostVMPath\$AzSHOST-Data.vhdx doesn't exist."
                $VHDX2 = New-VHD -Path "$HostVMPath\$AzSHOST-Data.vhdx" -SizeBytes 268435456000 -Dynamic

            }else{ 
                Write-Host "VHD $HostVMPath\$AzSHOST-Data.vhdx exist." 
                $VHDX2 = Get-VHD -Path "$HostVMPath\$AzSHOST-Data.vhdx"
            }              


            $NestedVMMemoryinGB = $AzSMGMTMemoryinGB
        }
    
        Else { 

            $exists= $false
            try { $exists=(Get-VHD -Path "$HostVMPath\$AzSHOST.vhdx") }
            catch { $exists=$false  }
            if (!($exists)) {

                Write-Host "VHD $HostVMPath\$AzSHOST.vhdx doesn't exist."
                $VHDX1 = New-VHD -ParentPath $coreparentpath -Path "$HostVMPath\$AzSHOST.vhdx" -Differencing 

            }else{ 
                Write-Host "VHD $HostVMPath\$AzSHOST.vhdx exist." 
                $VHDX1 = Get-VHD -Path "$HostVMPath\$AzSHOST.vhdx"
            } 

            $exists= $false
            try { $exists=(Get-VHD -Path "$HostVMPath\$AzSHOST-Data.vhdx") }
            catch { $exists=$false  }
            if (!($exists)) {

                Write-Host "VHD $HostVMPath\$AzSHOST-Data.vhdx doesn't exist."
                $VHDX2 = New-VHD -Path "$HostVMPath\$AzSHOST-Data.vhdx" -SizeBytes 268435456000 -Dynamic

            }else{ 
                Write-Host "VHD $HostVMPath\$AzSHOST-Data.vhdx exist." 
                $VHDX2 = Get-VHD -Path "$HostVMPath\$AzSHOST-Data.vhdx" 
            } 
    
            # # Create S2D Storage       

            $exists= $false
            try { $exists=(Get-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk1.vhdx") }
            catch { $exists=$false  }
            if (!($exists)) {

                Write-Host "VHD $HostVMPath\$AzSHOST-S2D_Disk1.vhdx doesn't exist."
                New-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk1.vhdx" -SizeBytes $S2DDiskSize -Dynamic | Out-Null

            }else{ Write-Host "VHD $HostVMPath\$AzSHOST-S2D_Disk1.vhdx exist." } 
            
            $exists= $false
            try { $exists=(Get-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk2.vhdx") }
            catch { $exists=$false  }
            if (!($exists)) {

                Write-Host "VHD $HostVMPath\$AzSHOST-S2D_Disk2.vhdx doesn't exist."
                New-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk2.vhdx" -SizeBytes $S2DDiskSize -Dynamic | Out-Null

            }else{ Write-Host "VHD $HostVMPath\$AzSHOST-S2D_Disk2.vhdx exist." } 
            
            $exists= $false
            try { $exists=(Get-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk3.vhdx") }
            catch { $exists=$false  }
            if (!($exists)) {

                Write-Host "VHD $HostVMPath\$AzSHOST-S2D_Disk3.vhdx doesn't exist."
                New-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk3.vhdx" -SizeBytes $S2DDiskSize -Dynamic | Out-Null

            }else{ Write-Host "VHD $HostVMPath\$AzSHOST-S2D_Disk3.vhdx exist." } 

            $exists= $false
            try { $exists=(Get-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk4.vhdx") }
            catch { $exists=$false  }
            if (!($exists)) {

                Write-Host "VHD $HostVMPath\$AzSHOST-S2D_Disk4.vhdx doesn't exist."
                New-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk4.vhdx" -SizeBytes $S2DDiskSize -Dynamic | Out-Null

            }else{ Write-Host "VHD $HostVMPath\$AzSHOST-S2D_Disk4.vhdx exist." } 

            $exists= $false
            try { $exists=(Get-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk5.vhdx") }
            catch { $exists=$false  }
            if (!($exists)) {

                Write-Host "VHD $HostVMPath\$AzSHOST-S2D_Disk5.vhdx doesn't exist."
                New-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk5.vhdx" -SizeBytes $S2DDiskSize -Dynamic | Out-Null

            }else{ Write-Host "VHD $HostVMPath\$AzSHOST-S2D_Disk5.vhdx exist." } 

            $exists= $false
            try { $exists=(Get-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk6.vhdx") }
            catch { $exists=$false  }
            if (!($exists)) {

                Write-Host "VHD $HostVMPath\$AzSHOST-S2D_Disk6.vhdx doesn't exist."
                New-VHD -Path "$HostVMPath\$AzSHOST-S2D_Disk6.vhdx" -SizeBytes $S2DDiskSize -Dynamic | Out-Null

            }else{ Write-Host "VHD $HostVMPath\$AzSHOST-S2D_Disk6.vhdx exist." } 
        }  
        
        Write-Host  "Create Nested VM $AzSHOST"

        $params = @{

            Name               = $AzSHOST
            MemoryStartupBytes = $NestedVMMemoryinGB 
            VHDPath            = $VHDX1.Path 
            SwitchName         = $VMSwitch
            Generation         = 2

        }
        $exists= $false
        try { $exists=(Get-VM -Name $AzSHOST) }
        catch { $exists=$false  }
        if (!($exists)) { New-VM @params | Out-Null  }
        else{ Write-Host "VM $AzSHOST exist." } 

    }
}