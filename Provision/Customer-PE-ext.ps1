# Logging function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp $Message" | Out-File -FilePath "C:\Windows\Temp\provision.log" -Append -Encoding UTF8
}

Import-Module C:\_T\TaniumOSD
Import-Module C:\_T\TaniumClient

$macaddress = Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.NetConnectionStatus -eq 2 } | Select-Object -ExpandProperty MACAddress
$macaddress = $macaddress.Replace(":", "")
$macaddress = $macaddress.Replace("-", "")

# Appel du WS PHP pour récupérer l'info machine
$urlws = "https://nas.wuibaille.fr/WS/getcomputer.php?mac=$macaddress"
Write-Log $urlws

try {
    $response = Invoke-RestMethod -Uri $urlws -Method Get
    if ($response.computerName) {
        $computerInfo = @{
            Computername = $response.computerName
            Postype      = $response.posType
            SetKeyboard  = ""   # Non retourné par ton PHP, à adapter si besoin
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
$setkeyboard  = $computerInfo.SetKeyboard
Write-Log "APIpe : $computerName"  
Write-Log "APIpe : $postype"   
Write-Log "APIpe : $setkeyboard" 

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
                    Write-Log "The ComputerName in unattend.xml has been updated to $computerName"
                } else {
                    Write-Log "No ComputerName element found in XML."
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
