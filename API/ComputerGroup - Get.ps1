<#
.SYNOPSIS
Initialize Tanium session from config.json, then display all Computer Groups in Out-GridView.
#>

# =========================
# Block 1 - Prerequisites
# =========================
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
Import-Module Redden-TanREST -Force

# =========================
# Block 2 - Load config.json & init session
# =========================
$configPath = Join-Path $PSScriptRoot 'config.json'

try {
    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    Write-Host "Reading configuration from: $configPath"
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

    # Values (fallback to environment variables)
    $TaniumUrl      = $config.TaniumUrl
    $TaniumApiToken = $config.TaniumApiToken
    if ([string]::IsNullOrWhiteSpace($TaniumUrl))      { $TaniumUrl      = $env:TANIUM_URL }
    if ([string]::IsNullOrWhiteSpace($TaniumApiToken)) { $TaniumApiToken = $env:TANIUM_TOKEN }
    if ([string]::IsNullOrWhiteSpace($TaniumUrl) -or [string]::IsNullOrWhiteSpace($TaniumApiToken)) {
        throw "Both TaniumUrl and TaniumApiToken must be provided (config.json or environment variables)."
    }

    # Normalize: bare host (no scheme / trailing slash)
    if ($TaniumUrl -match '^https?://') {
        $TaniumUrl = $TaniumUrl -replace '^https?://', '' -replace '/+$', ''
        Write-Host "Normalized TaniumUrl to host: $TaniumUrl"
    }

    # Build temporary CLIXML for Initialize-TaniumSession
    $TempXml = Join-Path $env:TEMP 'tanium-session-tmp.apicred'
    $ExportObject = @{
        baseURI = $TaniumUrl
        token   = ($TaniumApiToken | ConvertTo-SecureString -AsPlainText -Force)
    }
    Write-Host "Writing temporary CLIXML to: $TempXml"
    $ExportObject | Export-Clixml -Path $TempXml

    Write-Host "Initializing Tanium session..."
    Initialize-TaniumSession -PathToXML $TempXml
    Write-Host "Tanium session initialized successfully."
}
catch {
    Write-Error "Failed to initialize Tanium session. Details: $($_.Exception.Message)"
    throw
}

# =========================
# Block 3 - Retrieve & show Computer Groups
# =========================
Write-Host "Retrieving all Computer Groups..."
$groups = Get-ComputerGroup -All

# Show in Out-GridView if available; otherwise fallback to console table
if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
    $groups | Out-GridView -Title 'Tanium Computer Groups'
} else {
    Write-Warning "Out-GridView not available; showing a console table instead."
    $groups | Format-Table -Auto
}

# =========================
# Block 4 - Cleanup
# =========================
try {
    if (Test-Path $TempXml) {
        Remove-Item $TempXml -Force -ErrorAction SilentlyContinue
        Write-Host "Temporary CLIXML removed: $TempXml"
    }
} catch {
    Write-Warning "Could not remove temporary CLIXML ($TempXml): $($_.Exception.Message)"
}
