. ([scriptblock]::Create((Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Repository/main/Function/tanium.ps1" -UseBasicParsing).Content))
Import-Module C:\_T\TaniumOSD
Import-Module C:\_T\TaniumClient

$url = "https://nas.wuibaille.fr/DML/Chrome/googlechromestandaloneenterprise64.msi"
$destination = "C:\Windows\Temp\GoogleChromeStandaloneEnterprise64.msi"
$appName = "Google Chrome"
TaniumDownloadAndInstallMsi -Url $url -Destination $destination -AppName $appName

$url = "https://nas.wuibaille.fr/DML/7zip/7z1900-x64.msi"
$destination = "C:\Windows\Temp\7z1900-x64.msi"
$appName = "7z"
TaniumDownloadAndInstallMsi -Url $url -Destination $destination -AppName $appName


$computerInfo = Get-ComputerInfoFromAPI -WebServiceUrl "http://epm2024.monlab.lan:12176/GetName"
$computerName = $computerInfo.Computername
$postype      = $computerInfo.Postype
$setkeyboard  = $computerInfo.SetKeyboard
Log-Message "API : $computerName"  
Log-Message "API : $postype"   
Log-Message "API : $setkeyboard" 

# Set the environment variable POSTYPE persistently for the System
[Environment]::SetEnvironmentVariable("POSTYPE",  $postype, [EnvironmentVariableTarget]::Machine)

InstallDrivers
SetDns -DnsServers @("192.168.0.240", "192.168.0.3")
