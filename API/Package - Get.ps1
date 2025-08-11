<#
.SYNOPSIS
Initialize Tanium session from config.json, then list Tanium Packages
(using Get-TaniumPackage in several modes) and show them in Out-GridView.
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
    if (-not (Test-Path $configPath)) { throw "Configuration file not found: $configPath" }

    Write-Host "Reading configuration from: $configPath"
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

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

    # Temporary CLIXML for Initialize-TaniumSession
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
# Block 3 - Pick your query mode
# =========================
# Choose ONE mode: 'All' | 'ByName' | 'ByID' | 'NameRegex' | 'ByParam'
$QueryMode     = 'All'
$IncludeHidden = $false

# Fill only the variables needed by the chosen mode:
$ByName_Name      = 'My Awesome Package'
$ByID_Id          = 123
$NameRegex_Pattern= '.*Awesome.*'
$ByParam_Field    = 'command'          # e.g. 'command'
$ByParam_Operator = 'RegexMatch'       # e.g. 'Equal' | 'RegexMatch'
$ByParam_Value    = '.*cleanup\.vbs'   # regex string if using RegexMatch
$ByParam_Type     = 'String'           # 'String' | 'Version' | 'Numeric' | 'IPAddress' | 'Date' | 'DataSize' | 'NumericInteger'

# =========================
# Block 4 - Retrieve packages
# =========================
try {
    switch ($QueryMode) {
        'All' {
            Write-Host "Retrieving ALL packages..."
            $packages = Get-TaniumPackage -All -IncludeHidden:$IncludeHidden
        }
        'ByName' {
            Write-Host "Retrieving package by name: $ByName_Name"
            $packages = Get-TaniumPackage -Name $ByName_Name -IncludeHidden:$IncludeHidden
        }
        'ByID' {
            Write-Host "Retrieving package by ID: $ByID_Id"
            $packages = Get-TaniumPackage -ID $ByID_Id -IncludeHidden:$IncludeHidden
        }
        'NameRegex' {
            Write-Host "Retrieving packages by NameRegex: $NameRegex_Pattern"
            $packages = Get-TaniumPackage -NameRegex $NameRegex_Pattern -IncludeHidden:$IncludeHidden
        }
        'ByParam' {
            Write-Host "Retrieving packages by field filter: $ByParam_Field $ByParam_Operator $ByParam_Value ($ByParam_Type)"
            $packages = Get-TaniumPackage -Field $ByParam_Field -Operator $ByParam_Operator -Value $ByParam_Value -Type $ByParam_Type -IncludeHidden:$IncludeHidden
        }
        default {
            throw "Unknown QueryMode '$QueryMode'. Use: All | ByName | ByID | NameRegex | ByParam."
        }
    }

    if (-not $packages) {
        Write-Warning "No packages found."
    }

    # Try to present common fields; unknown props will appear blank (that's fine)
    $view = $packages | Select-Object `
        @{n='id';e={$_.id}},
        @{n='name';e={$_.name}},
        @{n='display_name';e={$_.display_name}},
        @{n='command';e={$_.command}},
        @{n='expire_seconds';e={$_.expire_seconds}},
        @{n='command_timeout';e={$_.command_timeout}},
        @{n='content_set_id';e={$_.content_set.id}},
        @{n='hidden';e={$_.hidden}}

    if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
        $view | Out-GridView -Title "Tanium Packages ($QueryMode)"
    } else {
        Write-Warning "Out-GridView not available; showing a console table instead."
        $view | Format-Table -Auto
    }
}
catch {
    Write-Error "Failed to retrieve/display packages. Details: $($_.Exception.Message)"
}

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
