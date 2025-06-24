. ([scriptblock]::Create((Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Repository/main/Function/tanium.ps1" -UseBasicParsing).Content))
Import-Module C:\_T\TaniumOSD
Import-Module C:\_T\TaniumClient
$macaddress = (Get-NetAdapter | Where-Object Status -eq 'Up').MacAddress -replace ":", ""
$computernameGet = (Get-ComputerInfo).CsName

# disabled windows update
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 1 -Type DWord

# Installation de Google Chrome
Set-OSDProgressDisplay -Message "Installation Google Chrome"
$info = "$computernameGet - Installation Google Chrome"
Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Packaging/main/DML/chrome.ps1" -UseBasicParsing).Content

# Installation de 7-Zip
Set-OSDProgressDisplay -Message "Installation 7zip"
$info = "$computernameGet - Installation 7zip"
Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Packaging/main/DML/7zip.ps1" -UseBasicParsing).Content

# Installation de Adobe Acrobat DC
# Set-OSDProgressDisplay -Message "Installation Acrobat DC"
# $info = "$computernameGet - Installation Acrobat DC"
# Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post
# Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Packaging/main/DML/acrobatdc.ps1" -UseBasicParsing).Content

Set-OSDProgressDisplay -Message "Web Service"
$computerInfo = Get-ComputerInfoFromAPI -WebServiceUrl "http://192.168.50.87:12176/GetName"
$computerName = $computerInfo.Computername
$postype      = $computerInfo.Postype
$setkeyboard  = $computerInfo.SetKeyboard
Log-Message "API : $computerName"  
Log-Message "API : $postype"   
Log-Message "API : $setkeyboard" 
$info = "$computernameGet - Web Service $computerName $postype $setkeyboard"
Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post

# Set the environment variable POSTYPE persistently for the System
[Environment]::SetEnvironmentVariable("POSTYPE",  $postype, [EnvironmentVariableTarget]::Machine)

Set-OSDProgressDisplay -Message "Install Drivers"
$info = "$computernameGet - Install Drivers"
Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post
InstallDrivers

Set-OSDProgressDisplay -Message "Integrate Domain"
$info = "$computernameGet - Integrate domain"
Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post
SetDns -DnsServers @("192.168.0.240", "192.168.0.3")
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Tanium/main/Provision/joindomain.ps1" -UseBasicParsing).Content

Set-OSDProgressDisplay -Message "END"
$info = "$computernameGet - END"
Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post

Restart-Computer -Force
