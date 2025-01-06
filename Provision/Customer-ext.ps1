. ([scriptblock]::Create((Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Repository/main/Function/tanium.ps1" -UseBasicParsing).Content))
Import-Module C:\_T\TaniumOSD
Import-Module C:\_T\TaniumClient
$macaddress = (Get-NetAdapter | Where-Object Status -eq 'Up').MacAddress -replace ":", ""
$computername = (Get-ComputerInfo).CsName

Set-OSDProgressDisplay -Message "Applications"

# Installation de Google Chrome
$info = "$computername - Installation Google Chrome"
Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Packaging/main/DML/chrome.ps1" -UseBasicParsing).Content

# Installation de 7-Zip
$info = "$computername - Installation 7zip"
Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Packaging/main/DML/7zip.ps1" -UseBasicParsing).Content

# Installation de Adobe Acrobat DC
$info = "$computername - Installation Acrobat DC"
Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Packaging/main/DML/acrobatdc.ps1" -UseBasicParsing).Content

Set-OSDProgressDisplay -Message "Web Service"
$computerInfo = Get-ComputerInfoFromAPI -WebServiceUrl "http://epm2024.monlab.lan:12176/GetName"
$computerName = $computerInfo.Computername
$postype      = $computerInfo.Postype
$setkeyboard  = $computerInfo.SetKeyboard
Log-Message "API : $computerName"  
Log-Message "API : $postype"   
Log-Message "API : $setkeyboard" 
$info = "$computername - API $computerName $postype $setkeyboard"
Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post

# Set the environment variable POSTYPE persistently for the System
[Environment]::SetEnvironmentVariable("POSTYPE",  $postype, [EnvironmentVariableTarget]::Machine)

Set-OSDProgressDisplay -Message "Drivers"
$info = "$computername - Install Drivers"
Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post
InstallDrivers

Set-OSDProgressDisplay -Message "Domain"
$info = "$computername - Integrate domain"
Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post
SetDns -DnsServers @("192.168.0.240", "192.168.0.3")
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Tanium/main/Provision/joindomain.ps1" -UseBasicParsing).Content

$info = "$computername - END"
Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post
Set-OSDProgressDisplay -Message "End"
