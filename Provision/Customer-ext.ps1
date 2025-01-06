. ([scriptblock]::Create((Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Repository/main/Function/tanium.ps1" -UseBasicParsing).Content))
Import-Module C:\_T\TaniumOSD
Import-Module C:\_T\TaniumClient

Set-OSDProgressDisplay -Message "Applications"

# Installation de Google Chrome
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Packaging/main/DML/chrome.ps1" -UseBasicParsing).Content

# Installation de 7-Zip
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Packaging/main/DML/7zip.ps1" -UseBasicParsing).Content

# Installation de Adobe Acrobat DC
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Packaging/main/DML/acrobatdc.ps1" -UseBasicParsing).Content

Set-OSDProgressDisplay -Message "Web Service"
$computerInfo = Get-ComputerInfoFromAPI -WebServiceUrl "http://epm2024.monlab.lan:12176/GetName"
$computerName = $computerInfo.Computername
$postype      = $computerInfo.Postype
$setkeyboard  = $computerInfo.SetKeyboard
Log-Message "API : $computerName"  
Log-Message "API : $postype"   
Log-Message "API : $setkeyboard" 

# Set the environment variable POSTYPE persistently for the System
[Environment]::SetEnvironmentVariable("POSTYPE",  $postype, [EnvironmentVariableTarget]::Machine)

Set-OSDProgressDisplay -Message "Drivers"
InstallDrivers

Set-OSDProgressDisplay -Message "Domain"
SetDns -DnsServers @("192.168.0.240", "192.168.0.3")
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Tanium/main/Provision/joindomain.ps1" -UseBasicParsing).Content


Set-OSDProgressDisplay -Message "End"
