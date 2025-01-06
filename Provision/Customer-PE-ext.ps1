. ([scriptblock]::Create((Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Repository/main/Function/tanium.ps1" -UseBasicParsing).Content))
Import-Module C:\_T\TaniumOSD
Import-Module C:\_T\TaniumClient

$macaddress = Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.NetConnectionStatus -eq 2 } | Select-Object -ExpandProperty MACAddress
$macaddress = $macaddress.Replace(":", "").Replace("-", "")

$computerInfo = Get-ComputerInfoFromAPI -WebServiceUrl "http://epm2024.monlab.lan:12176/GetName"
$computerName = $computerInfo.Computername
$postype      = $computerInfo.Postype
$setkeyboard  = $computerInfo.SetKeyboard
Log-Message "APIpe : $computerName"  
Log-Message "APIpe : $postype"   
Log-Message "APIpe : $setkeyboard" 


$info = "WinPE - Web Service $computerName $postype $setkeyboard"
Invoke-RestMethod -Uri "http://epm2024.monlab.lan:12176/SaveInfo?macaddress=$macaddress&info=$info" -Method Post

# Log available drives
$availableDrives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
Log-Message "Available Drives: $($availableDrives -join ', ')"

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
        Log-Message "Checking for unattend.xml at $xmlFilePath"

        # Ensure the XML file exists before proceeding
        if (Test-Path $xmlFilePath) {
            Log-Message "unattend.xml file found at $xmlFilePath."

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
                    Log-Message "The ComputerName in unattend.xml has been updated to $($response.Computername)"
                } else {
                    Log-Message "No ComputerName element found in XML."
                }
            } catch {
                Log-Message "Error processing unattend.xml at $xmlFilePath - $_"
            }
        } else {
            Log-Message "The unattend.xml file does not exist at $xmlFilePath."
        }
    }
}

Log-Message "Script completed."
