Import-Module C:\_T\TaniumOSD
Import-Module C:\_T\TaniumClient
$macaddress      = (Get-NetAdapter | Where-Object Status -eq 'Up').MacAddress -replace ":", ""
$computernameGet = (Get-ComputerInfo).CsName

# Logging function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp $Message" | Out-File -FilePath "C:\Windows\Temp\provision.log" -Append -Encoding UTF8
}

# disabled windows update
Set-OSDProgressDisplay -Message "Cofigure Windows Update"
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 1 -Type DWord
Import-Module C:\_T\TaniumOSD
Import-Module C:\_T\TaniumClient

$macaddress = Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.NetConnectionStatus -eq 2 } | Select-Object -ExpandProperty MACAddress
$macaddress = $macaddress.Replace(":", "-")

# Installation de Google Chrome
Set-OSDProgressDisplay -Message "Installation Google Chrome"
$info = "$computernameGet - Installation Google Chrome"
Invoke-RestMethod -Uri "http://192.168.50.10:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post
$url         = "https://nas.wuibaille.fr/labo777/DML/chrome/googlechromestandaloneenterprise64.msi"
$destination = "c:\windows\temp\googlechromestandaloneenterprise64.msi"
Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
$installCmd = "msiexec /i `"$destination`" /qn /norestart"
Start-Process -FilePath "cmd.exe" -ArgumentList "/c $installCmd" -Wait -NoNewWindow

# Installation de 7-Zip
Set-OSDProgressDisplay -Message "Installation 7zip"
$info = "$computernameGet - Installation 7zip"
Invoke-RestMethod -Uri "http:///192.168.50.10:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post
$url = "https://nas.wuibaille.fr/labo777/DML/7zip/7z1900-x64.msi"
$destination = "c:\windows\temp\7z1900-x64.msi"
Invoke-WebRequest -Uri $url -OutFile $destination
$installCmd = "msiexec /i `"$destination`" /qn /norestart"
Start-Process -FilePath "cmd.exe" -ArgumentList "/c $installCmd" -Wait -NoNewWindow

# SetPostype
Set-OSDProgressDisplay -Message "POSTYPE"
$computerInfo = Get-ComputerInfoFromAPI -WebServiceUrl "http://192.168.50.10:12176/GetName"
$computerName = $computerInfo.Computername
$postype      = $computerInfo.Postype
$setkeyboard  = $computerInfo.SetKeyboard
Write-Log "API : $computerName"  
Write-Log "API : $postype"   
Write-Log "API : $setkeyboard" 
$info = "$computernameGet - Web Service $computerName $postype $setkeyboard"
Invoke-RestMethod -Uri "http://192.168.50.10:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post
[Environment]::SetEnvironmentVariable("POSTYPE",  $postype, [EnvironmentVariableTarget]::Machine)
Write-Log "APIpe : $computerName"  
Write-Log "APIpe : $postype"   
Write-Log "APIpe : $setkeyboard" 

Set-OSDProgressDisplay -Message "END"
$info = "$computernameGet - END"
$info = "WinPE - Web Service $computerName $postype $setkeyboard"
Invoke-RestMethod -Uri "http://192.168.50.10:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post


