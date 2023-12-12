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

        Add-VMHardDiskDrive -VMName $AzSHOST -Path $VHDX2.Path

        if ($AzSHOST -ne "AzSMGMT") {

            Add-VMHardDiskDrive -Path "$HostVMPath\$AzSHOST-S2D_Disk1.vhdx" -VMName $AzSHOST | Out-Null
            Add-VMHardDiskDrive -Path "$HostVMPath\$AzSHOST-S2D_Disk2.vhdx" -VMName $AzSHOST | Out-Null
            Add-VMHardDiskDrive -Path "$HostVMPath\$AzSHOST-S2D_Disk3.vhdx" -VMName $AzSHOST | Out-Null
            Add-VMHardDiskDrive -Path "$HostVMPath\$AzSHOST-S2D_Disk4.vhdx" -VMName $AzSHOST | Out-Null
            Add-VMHardDiskDrive -Path "$HostVMPath\$AzSHOST-S2D_Disk5.vhdx" -VMName $AzSHOST | Out-Null
            Add-VMHardDiskDrive -Path "$HostVMPath\$AzSHOST-S2D_Disk6.vhdx" -VMName $AzSHOST | Out-Null

        }

        Set-VM -Name $AzSHOST -ProcessorCount 4 -AutomaticStartAction Start

        $exists= $false
        try { $exists=(Get-VMNetworkAdapter -VMName $AzSHOST -Name "SDN") }
        catch { $exists=$false  }
        if (!($exists)) { 
            Get-VMNetworkAdapter -VMName $AzSHOST | Rename-VMNetworkAdapter -NewName "SDN"
            Get-VMNetworkAdapter -VMName $AzSHOST | Set-VMNetworkAdapter -DeviceNaming On -StaticMacAddress  ("{0:D12}" -f ( Get-Random -Minimum 0 -Maximum 99999 ))                
         }
        else{  Write-Host "Adapter VMName $AzSHOST Name SDN exist." } 

        $exists= $false
        try { $exists=(Get-VMNetworkAdapter -VMName $AzSHOST -Name "SDN2") }
        catch { $exists=$false  }
        if (!($exists)) { 
            Add-VMNetworkAdapter -VMName $AzSHOST -Name SDN2 -DeviceNaming On -SwitchName $VMSwitch
         }
        else{  Write-Host "Adapter VMName $AzSHOST Name SDN2 exist." } 
       
        $vmMac = ((Get-VMNetworkAdapter -Name SDN -VMName $AzSHOST).MacAddress) -replace '..(?!$)', '$&-'
        Write-Verbose "Virtual Machine FABRIC NIC MAC is = $vmMac"


        if ($AzSHOST -ne "AzSMGMT") {

            $exists= $false
            try { $exists=(Get-VMNetworkAdapter -VMName $AzSHOST -Name StorageA) }
            catch { $exists=$false  }
            if (!($exists)) { 
                Add-VMNetworkAdapter -VMName $AzSHOST -SwitchName $VMSwitch -DeviceNaming On -Name StorageA
             }
            else{  Write-Host "Adapter VMName $AzSHOST Name StorageA exist." } 

            
            $exists= $false
            try { $exists=(Get-VMNetworkAdapter -VMName $AzSHOST -Name StorageB) }
            catch { $exists=$false  }
            if (!($exists)) { 
                Add-VMNetworkAdapter -VMName $AzSHOST -SwitchName $VMSwitch -DeviceNaming On -Name StorageB
             }
            else{  Write-Host "Adapter VMName $AzSHOST Name StorageB exist." }             
            
        }

        Get-VM $AzSHOST | Set-VMProcessor -ExposeVirtualizationExtensions $true
        Get-VM $AzSHOST | Set-VMMemory -DynamicMemoryEnabled $false
        Get-VM $AzSHOST | Get-VMNetworkAdapter | Set-VMNetworkAdapter -MacAddressSpoofing On

        Set-VMNetworkAdapterVlan -VMName $AzSHOST -VMNetworkAdapterName SDN -Trunk -NativeVlanId 0 -AllowedVlanIdList 1-200
        Set-VMNetworkAdapterVlan -VMName $AzSHOST -VMNetworkAdapterName SDN2 -Trunk -NativeVlanId 0 -AllowedVlanIdList 1-200  
        
        if ($AzSHOST -ne "AzSMGMT") {

            Set-VMNetworkAdapterVlan -VMName $AzSHOST -VMNetworkAdapterName StorageA -Access -VlanId $SDNConfig.StorageAVLAN 
            Set-VMNetworkAdapterVlan -VMName $AzSHOST -VMNetworkAdapterName StorageB -Access -VlanId $SDNConfig.StorageBVLAN 


        }     
        
        Enable-VMIntegrationService -VMName $AzSHOST -Name "Guest Service Interface"
        return $vmMac
    }

    $vmMacs += [pscustomobject]@{

        Hostname = $VM.AzSHOST
        vmMAC    = $vmMac

    }

}

Write-Host $vmMacs