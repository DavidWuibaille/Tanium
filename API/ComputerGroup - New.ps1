<#
.SYNOPSIS
Initialize Tanium session from config.json, then create Computer Groups only if they do not already exist.
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
$TempXml    = Join-Path $env:TEMP 'tanium-session-tmp.apicred'

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

try {
    # =========================
    # Block 3 - Ensure Computer Groups exist
    # =========================

    # Hashtable of groups to ensure: Name => Filter text
    $ComputerGroups = @{
        "David_LTSC2019" = "(Computer Name contains 2019)"
        "David_LTSC2021" = "(Computer Name contains 2021)"
        "David_LTSC2024" = "(Computer Name contains 2024)"
    }

    # Default Content Set (id = 0) – change if needed
    $contentSetDefault = [pscustomobject]@{ id = 0 }

    Write-Host "Ensuring Computer Groups exist (create if missing)..."
    foreach ($kv in $ComputerGroups.GetEnumerator()) {
        $name       = $kv.Key
        $filterText = $kv.Value

        try {
            $existing = Get-ComputerGroup -Name $name -ErrorAction SilentlyContinue
            if ($existing) {
                Write-Host "Group '$name' already exists (Id: $($existing.id)). Skipping."
                continue
            }

            Write-Host "Creating group: '$name' with filter: $filterText"
            New-ComputerGroup `
                -Name $name `
                -Type 0 `
                -Text $filterText `
                -Content_Set $contentSetDefault `
                -Filter_Flag $true `
                -Management_Rights_Flag $true

            Write-Host "Created group: '$name'."
        }
        catch {
            Write-Error "Failed processing group '$name'. Details: $($_.Exception.Message)"
        }
    }

}
finally {
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
}
