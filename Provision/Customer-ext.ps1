# Logging function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp $Message" | Out-File -FilePath "C:\Windows\Temp\provision.log" -Append -Encoding UTF8
}

Import-Module C:\_T\TaniumOSD
Import-Module C:\_T\TaniumClient

$macaddress = Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.NetConnectionStatus -eq 2 } | Select-Object -ExpandProperty MACAddress
$macaddress = $macaddress.Replace(":", "-")

# Get active MAC address (network up)
$macAddresses = Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.NetConnectionStatus -eq 2 } | Select-Object -ExpandProperty MACAddress
$macAddresses = $macAddresses -replace "[:\-]", "" # Remove : and -

# Build request URL
$WebServiceUrl = "http://192.168.50.10:12176/GetName"
$urlws = "$WebServiceUrl?macaddress=$macAddresses"

# Call API and get info
try {
    $response = Invoke-RestMethod -Uri $urlws
    if ($response.Computername) {
        $computerInfo = @{
            Computername = $response.Computername
            Postype      = $response.postype
            SetKeyboard  = $response.setkeyboard
        }
    } else {

        $computerInfo = $null
    }
} catch {
    $computerInfo = $null
}


$computerName = $computerInfo.Computername
$postype      = $computerInfo.Postype
$setkeyboard  = $computerInfo.SetKeyboard
Write-Log "APIpe : $computerName"  
Write-Log "APIpe : $postype"   
Write-Log "APIpe : $setkeyboard" 

$info = "WinPE - Web Service $computerName $postype $setkeyboard"
Invoke-RestMethod -Uri "http://192.168.50.10:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post

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
