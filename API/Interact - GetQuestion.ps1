<#
.SYNOPSIS
Initialize Tanium session from config.json, ensure computer groups exist (create if missing),
then ask an Interact question and display results in Out-GridView.

.NOTES
- Keep config.json out of version control.
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
# Block 3 - Interact question + Out-GridView (no flattener)
# =========================

$canonicalText  = 'Get Computer Name and IP Address from all machines with Operating System contains Windows'
$minResponsePct = 95
$expireSeconds  = 1200

Write-Host "Asking Interact question..."
$result = Get-InteractQuestionResult `
	-CanonicalText $canonicalText `
	-MinResponsePercent $minResponsePct `
	-ExpireSeconds $expireSeconds `
	-Verbose

$result | Out-GridView -Title 'Windows endpoints'



# =========================
# Block 5 - Cleanup
# =========================
try {
    if (Test-Path $TempXml) {
        Remove-Item $TempXml -Force -ErrorAction SilentlyContinue
        Write-Host "Temporary CLIXML removed: $TempXml"
    }
} catch {
    Write-Warning "Could not remove temporary CLIXML ($TempXml): $($_.Exception.Message)"
}
