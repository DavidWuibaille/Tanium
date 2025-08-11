<#
.SYNOPSIS
List Tanium Deploy Software Packages using Get-DeploySoftware.
Reads URL/token from config.json, initializes the session, then queries by:
  - All | ByName | ByID | ByVendor | ByCommand | NameRegex
and displays results in Out-GridView (fallback to console table).
#>

# =========================
# Block 1 - Prerequisites
# =========================
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
Import-Module Redden-TanREST -Force

# =========================
# Block 2 - Load config & init session
# =========================
$configPath = Join-Path $PSScriptRoot 'config.json'
$TempXml    = Join-Path $env:TEMP 'tanium-session-tmp.apicred'

if (-not (Test-Path $configPath)) { throw "Configuration file not found: $configPath" }

Write-Host "Reading configuration from: $configPath"
$config      = Get-Content -Path $configPath -Raw | ConvertFrom-Json
$TaniumUrl   = $config.TaniumUrl
$TaniumToken = $config.TaniumApiToken

if ([string]::IsNullOrWhiteSpace($TaniumUrl) -or [string]::IsNullOrWhiteSpace($TaniumToken)) {
    throw "Both TaniumUrl and TaniumApiToken must be provided (config.json or environment variables)."
}
if ($TaniumUrl -match '^https?://') {
    $TaniumUrl = $TaniumUrl -replace '^https?://','' -replace '/+$',''
    Write-Host "Normalized TaniumUrl to host: $TaniumUrl"
}

$ExportObject = @{
  baseURI = $TaniumUrl
  token   = ($TaniumToken | ConvertTo-SecureString -AsPlainText -Force)
}
$ExportObject | Export-Clixml -Path $TempXml

Write-Host "Initializing Tanium session..."
Initialize-TaniumSession -PathToXML $TempXml
Write-Host "Tanium session initialized."

# =========================
# Block 3 - Choose query mode
# =========================
Get-DeploySoftware -All | Out-GridView

# =========================
# Block 5 - Cleanup
# =========================
if (Test-Path $TempXml) {
	Remove-Item $TempXml -Force -ErrorAction SilentlyContinue
	Write-Host "Temporary CLIXML removed: $TempXml"
}

