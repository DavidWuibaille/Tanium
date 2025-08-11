# Logging function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp $Message" | Out-File -FilePath "C:\Windows\Temp\provision.log" -Append -Encoding UTF8
    Write-Host $Message
}

Import-Module C:\_T\TaniumOSD
Import-Module C:\_T\TaniumClient

$macaddress = Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.NetConnectionStatus -eq 2 } | Select-Object -ExpandProperty MACAddress
$macaddress = $macaddress.Replace(":", "")
$macaddress = $macaddress.Replace("-", "")

# Appel du WS PHP pour récupérer l'info machine (API doit renvoyer aussi keyboard/language)
$urlws = "https://nas.wuibaille.fr/WS/getcomputer.php?mac=$macaddress"
Write-Log $urlws

try {
    $response = Invoke-RestMethod -Uri $urlws -Method Get
    if ($response.computerName) {
        $computerInfo = @{
            Computername = $response.computerName
            Postype      = $response.posType
            Keyboard     = $response.keyboard
            Language     = $response.language
        }
    } else {
        $computerInfo = $null
    }
} catch {
    $computerInfo = $null
    Write-Log "Erreur appel API PHP: $_"
}

$computerInfo
$computerName = $computerInfo.Computername
$postype      = $computerInfo.Postype
$setkeyboard  = $computerInfo.Keyboard
$setlanguage  = $computerInfo.Language

Write-Log "APIpe : $computerName"  
Write-Log "APIpe : $postype"   
Write-Log "APIpe : $setkeyboard"
Write-Log "APIpe : $setlanguage"

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
        $xmlFilePath = Join-Path -Path $drive -ChildPath $relativePath
        Write-Log "Checking for unattend.xml at $xmlFilePath"

        if (Test-Path $xmlFilePath) {
            Write-Log "unattend.xml file found at $xmlFilePath."
            try {
                [xml]$xmlDoc = Get-Content $xmlFilePath

                $ns = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
                $ns.AddNamespace("ns", "urn:schemas-microsoft-com:unattend")

                # Change ComputerName
                $computerNameNode = $xmlDoc.SelectSingleNode("//ns:settings[@pass='specialize']/ns:component/ns:ComputerName", $ns)
                if ($computerNameNode -ne $null) {
                    $computerNameNode.InnerText = $computerName
                    Write-Log "The ComputerName in unattend.xml has been updated to $computerName"
                } else {
                    Write-Log "No ComputerName element found in XML."
                }

                # Exemple : changer KeyboardLayout (InputLocale) si besoin
                if ($setkeyboard) {
                    $keyboardNode = $xmlDoc.SelectSingleNode("//ns:settings/ns:component/ns:InputLocale", $ns)
                    if ($keyboardNode -ne $null) {
                        $keyboardNode.InnerText = $setkeyboard
                        Write-Log "Keyboard/InputLocale updated to $setkeyboard"
                    }
                }

                $xmlDoc.Save($xmlFilePath)
            } catch {
                Write-Log "Error processing unattend.xml at $xmlFilePath - $_"
            }
        } else {
            Write-Log "The unattend.xml file does not exist at $xmlFilePath."
        }
    }
}

Write-Log "Script completed."
