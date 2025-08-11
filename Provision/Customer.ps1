Import-Module C:\_T\TaniumOSD
Import-Module C:\_T\TaniumClient

$macaddress = (Get-NetAdapter | Where-Object Status -eq 'Up').MacAddress
$macaddress = $macaddress.Replace(":", "")
$macaddress = $macaddress.Replace("-", "")
$computernameGet = (Get-ComputerInfo).CsName

# Logging function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp $Message" | Out-File -FilePath "C:\Windows\Temp\provision.log" -Append -Encoding UTF8
}

# Désactivation Windows Update
Set-OSDProgressDisplay -Message "Configure Windows Update"
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 1 -Type DWord

# Installation Google Chrome
Set-OSDProgressDisplay -Message "Installation Google Chrome"
$info = "$computernameGet - Installation Google Chrome"
# Pas d'API SaveInfo côté PHP => logger local uniquement ou ajouter si besoin
Write-Log $info
$url         = "https://nas.wuibaille.fr/labo777/DML/chrome/googlechromestandaloneenterprise64.msi"
$destination = "c:\windows\temp\googlechromestandaloneenterprise64.msi"
Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
$installCmd = "msiexec /i `"$destination`" /qn /norestart"
Start-Process -FilePath "cmd.exe" -ArgumentList "/c $installCmd" -Wait -NoNewWindow

# Installation 7-Zip
Set-OSDProgressDisplay -Message "Installation 7zip"
$info = "$computernameGet - Installation 7zip"
Write-Log $info
$url = "https://nas.wuibaille.fr/labo777/DML/7zip/7z1900-x64.msi"
$destination = "c:\windows\temp\7z1900-x64.msi"
Invoke-WebRequest -Uri $url -OutFile $destination
$installCmd = "msiexec /i `"$destination`" /qn /norestart"
Start-Process -FilePath "cmd.exe" -ArgumentList "/c $installCmd" -Wait -NoNewWindow

# SetPostype
Set-OSDProgressDisplay -Message "POSTYPE"

# Call PHP API and get info
$urlws = "https://nas.wuibaille.fr/WS/getcomputer.php?mac=$macaddress"
Write-Log $urlws
try {
    $response = Invoke-RestMethod -Uri $urlws -Method Get
    if ($response.computerName) {
        $computerInfo = @{
            Computername = $response.computerName
            Postype      = $response.posType
            SetKeyboard  = "" # Champ non fourni dans le JSON PHP
        }
    } else {
        $computerInfo = $null
    }
} catch {
    $computerInfo = $null
    Write-Log "Erreur appel API PHP: $_"
}

$computerName = $computerInfo.Computername
$postype      = $computerInfo.Postype
$setkeyboard  = $computerInfo.SetKeyboard
Write-Log "API : $computerName"  
Write-Log "API : $postype"   
Write-Log "API : $setkeyboard" 

# (Pas de SaveInfo sur l’API PHP, tu peux logger local ou ignorer)
[Environment]::SetEnvironmentVariable("POSTYPE",  $postype, [EnvironmentVariableTarget]::Machine)

Set-OSDProgressDisplay -Message "END"
$info = "$computernameGet - END"
Write-Log $info
