

. ([scriptblock]::Create((Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DavidWuibaille/Repository/main/Function/tanium.ps1" -UseBasicParsing).Content))
Import-Module C:\_T\TaniumOSD
Import-Module C:\_T\TaniumClient

# ----------------------- create log file
if (Test-Path -Path "C:\") {  
    if (-not (Test-Path -Path "C:\Systools"))        { New-Item -Path "C:\Systools" -ItemType Directory } 
    if (-not (Test-Path -Path "C:\Systools\OptLog")) { New-Item -Path "C:\Systools\OptLog" -ItemType Directory }
}
$logFilePath = "C:\Systools\OptLog\provision.log"
Log-Message "Customer Script started."

# -----------------------get API
$webserviceUrl = "http://epm2024.monlab.lan:12176/GetName"
# Obtain all network interfaces with their MAC addresses
$macAddresses = Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.NetConnectionStatus -eq 2 } | Select-Object -ExpandProperty MACAddress
$macAddresses = $macAddresses.replace(":","")
$macAddresses = $macAddresses.replace("-","")
Log-Message "MAC Addresses: $macAddresses"
$urlws = $webserviceUrl + "?macaddress=$macAddresses"
Log-Message $urlws 
$EnvValue= ""
try {
	$response = Invoke-RestMethod -Uri $urlws
	# Check if the response contains the ComputerName
	if ($response.Computername) {
		Log-Message "Response received from server for MAC $macAddresses : postype = $($response.postype)"
		$EnvValue = $($response.postype)
	} else {
		Log-Message "No valid computer found for MAC $macAddresses"
	}
} catch {
	Log-Message "Error contacting webservice for MAC $macAddresses : $_"
}

$setkeyboard = Get-OSDVariable -Name "setkeyboard"
Log-Message "setkeyboard $setkeyboard"

# Set the environment variable POSTYPE persistently for the System
[Environment]::SetEnvironmentVariable("POSTYPE", $EnvValue, [EnvironmentVariableTarget]::Machine)




$url = "https://nas.wuibaille.fr/DML/Chrome/googlechromestandaloneenterprise64.msi"
$destination = "C:\Windows\Temp\GoogleChromeStandaloneEnterprise64.msi"
$appName = "Google Chrome"
TaniumDownloadAndInstallMsi -Url $url -Destination $destination -AppName $appName


Log-Message "Script ended."

$computerInfo = Get-ComputerInfoFromAPI -WebServiceUrl "http://epm2024.monlab.lan:12176/GetName"
$computerName = $computerInfo.Computername
$postype = $computerInfo.Postype
$setkeyboard = $computerInfo.SetKeyboard
Log-Message "API : $computerName"  
Log-Message "API : $postype"   
Log-Message "API : $setkeyboard"   
