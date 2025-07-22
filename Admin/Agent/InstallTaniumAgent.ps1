# Fonction de log
Function Write-Log {
    param (
        [string]$message,
        [string]$level = "INFO"
    )
    $logPath = "C:\Windows\temp\TaniumClientinstall.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "$timestamp [$level] $message"
}

# Paramètres généraux
$port = 17472
$computerName = $env:COMPUTERNAME
$taniumLog = "c:\systools\tanium\install.log"
$destInstall = "c:\systools\tanium"

# Sélection du dossier et du serveur selon le nom de la machine
if ($computerName -like "PP-*") {
    $clientFolder = "ClientTaniumPreProd"
    $serverAddress = "tanium.preprod.fr"
} else {
    $clientFolder = "ClientTaniumProd"
    $serverAddress = "tanium.prod.fr"
}

# Construction des chemins
$setupDir = Join-Path $PSScriptRoot $clientFolder
$exePath = Join-Path $setupDir "SetupClient.exe"

# Vérifie si le port est déjà ouvert sur l'hostname courant
$test = Test-NetConnection -ComputerName $computerName -Port $port
if ($test.TcpTestSucceeded) {
    Write-Host "Port $port already open. Exiting." -ForegroundColor Green
    Write-Log "Port $port already open. Exiting installation." "INFO"
    Exit 0
}

# Teste l'accessibilité du serveur Tanium sur le port 17472 avant installation
$serverTest = Test-NetConnection -ComputerName $serverAddress -Port $port
if (-not $serverTest.TcpTestSucceeded) {
    Write-Host "Error: Port $port not open on $serverAddress. Exiting." -ForegroundColor Red
    Write-Log "Port $port not open on $serverAddress. Exiting installation." "ERROR"
    Exit 6
}

# Exécute SetupClient.exe dans le bon dossier avec le bon serverAddress
$process = Start-Process -FilePath $exePath `
    -ArgumentList "/S", "/ServerAddress=$serverAddress", "/D=$destInstall" `
    -Wait -PassThru -WorkingDirectory $setupDir

if ($process.ExitCode -eq 0) {
    Write-Host "Setup complete." -ForegroundColor Green
    Write-Log "Setup complete." "INFO"
} else {
    Write-Host "Setup failed. Exit code: $($process.ExitCode)" -ForegroundColor Red
    Write-Log "Setup failed. Exit code: $($process.ExitCode)" "ERROR"
    Exit $process.ExitCode
}

# Attente d'une mention dans le log Tanium Client (10 min max)
$timeoutSec = 60
$intervalSec = 5
$elapsed = 0

while ($elapsed -lt $timeoutSec) {
    if (Test-Path $taniumLog) {
        $logContent = Get-Content $taniumLog -Raw
        if ($logContent -match "(?i)error") {
            Write-Host "Error detected in Tanium install.log." -ForegroundColor Red
            Write-Log "Error detected in Tanium install.log." "ERROR"
            Exit 3
        }
		if ($logContent -match "Done with main installation") {
			Write-Host "Tanium Client installation finished (log status OK)." -ForegroundColor Green
			Write-Log "Tanium Client installation finished (log status OK)." "INFO"

			break
		}
    }
    Start-Sleep -Seconds $intervalSec
    $elapsed += $intervalSec
}

if ($elapsed -ge $timeoutSec) {
    Write-Host "Timeout waiting for Tanium Client install.log status." -ForegroundColor Red
    Write-Log "Timeout waiting for Tanium Client install.log status." "ERROR"
    Exit 4
}

# Attente port 17472 (10 min max)
$timeoutSec = 60
$intervalSec = 5
$elapsed = 0

while ($elapsed -lt $timeoutSec) {
    $test = Test-NetConnection -ComputerName $computerName -Port $port
    if ($test.TcpTestSucceeded) {
        Write-Host "Port $port is open." -ForegroundColor Green
        Write-Log "Port $port is open." "INFO"
        break
    }
    Start-Sleep -Seconds $intervalSec
    $elapsed += $intervalSec
}

if ($elapsed -ge $timeoutSec) {
    Write-Host "Timeout waiting for port $port to open." -ForegroundColor Red
    Write-Log "Timeout waiting for port $port to open." "ERROR"
    Exit 2
}
