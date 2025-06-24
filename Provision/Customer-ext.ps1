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
$computerInfo = Get-ComputerInfoFromAPI -WebServiceUrl "http://InstallIvantiAgent.ps1:12176/GetName"
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

Restart-Computer -Force
# Log available drives
$availableDrives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
Write-Log "Available Drives: $($availableDrives -join ', ')"

# Define paths to check for unattend.xml
$unattendPaths = @(
    "Windows\Panther\unattend.xml",
    "_T\unattend.xml",
    "Windows\Panther\Unattend\unattend.xml"
)

foreach ($drive in $availableDrives) {
    foreach ($relativePath in $unattendPaths) {
        # Construct the full path to the unattend.xml file in the current drive
        $xmlFilePath = Join-Path -Path $drive -ChildPath $relativePath
        Write-Log "Checking for unattend.xml at $xmlFilePath"

        # Ensure the XML file exists before proceeding
        if (Test-Path $xmlFilePath) {
            Write-Log "unattend.xml file found at $xmlFilePath."

            try {
                # Load the XML file
                [xml]$xmlDoc = Get-Content $xmlFilePath

                # Define the namespace manager
                $ns = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
                $ns.AddNamespace("ns", "urn:schemas-microsoft-com:unattend")

                # Attempt to find and modify the ComputerName element
                $computerNameNode = $xmlDoc.SelectSingleNode("//ns:settings[@pass='specialize']/ns:component/ns:ComputerName", $ns)
                if ($computerNameNode -ne $null) {
                    $computerNameNode.InnerText = $computerName
                    # Save the modified XML file
                    $xmlDoc.Save($xmlFilePath)
                    Write-Log "The ComputerName in unattend.xml has been updated to $($response.Computername)"
                } else {
                    Write-Log "No ComputerName element found in XML."Add commentMore actions
                }
            } catch {
                Write-Log "Error processing unattend.xml at $xmlFilePath - $_"
            }
        } else {
            Write-Log "The unattend.xml file does not exist at $xmlFilePath."
        }
    }
}

Write-Log "Script completed."
