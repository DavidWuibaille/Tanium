# Variables
$scriptUrl = "https://raw.githubusercontent.com/DavidWuibaille/Packaging/main/DML/chrome.ps1"
$destinationFolder = "C:\Windows\Temp"
$scriptFile = "chrome.ps1"

# Téléchargement du script
$destinationPath = Join-Path -Path $destinationFolder -ChildPath $scriptFile

Write-Host "Downloading $scriptUrl to $destinationPath..."
try {
    Invoke-WebRequest -Uri $scriptUrl -OutFile $destinationPath -ErrorAction Stop
    Write-Host "$scriptFile downloaded successfully."
} catch {
    Write-Host "Failed to download $scriptFile. Error: $_" -ForegroundColor Red
    exit 1
}

# Exécution du script avec ExecutionPolicy Bypass
Write-Host "Executing the downloaded script with ExecutionPolicy Bypass..."
try {
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$destinationPath`"" -Wait
    Write-Host "Script executed successfully."
} catch {
    Write-Host "Script execution failed. Error: $_" -ForegroundColor Red
    exit 1
}
