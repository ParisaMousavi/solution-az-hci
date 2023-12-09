# Enable PSRemoting

Write-Verbose "Enabling PS Remoting on client..."
$VerbosePreference = "SilentlyContinue"
Enable-PSRemoting
Set-Item WSMan:\localhost\Client\TrustedHosts * -Confirm:$false -Force
$VerbosePreference = "Continue"