$Profile = Get-NetConnectionProfile -InterfaceAlias Ethernet

$Profile.NetworkCategory = “Private”

Set-NetConnectionProfile -InputObject $Profile

New-VMSwitch -Name “InternalSwitchNAT” -SwitchType Internal

Get-NetAdapter

New-NetIPAddress -IPAddress 192.168.217.1 -PrefixLength 24 -InterfaceIndex 20

New-NetFirewallRule -RemoteAddress 192.168.218.0/24 -DisplayName “Allow218net” -Profile Any -Action Allow

Get-NetFirewallRule

