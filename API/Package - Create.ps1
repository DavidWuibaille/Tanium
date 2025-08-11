<#
.SYNOPSIS
Create Tanium action packages from a definition array supporting three modes:
  - CommandOnly : only a command (no files)
  - Upload      : upload local files into the package, then execute from .\__Download\
  - Url         : reference a remote file by URL with SHA-256 and "check for update" TTL

The script:
1) Initializes a Tanium session from config.json (same folder as the script),
2) Iterates over $packages and creates each package accordingly,
3) Optionally uploads payloads (Upload mode), or references URL files (Url mode),
4) Cleans up the temporary CLIXML.

NOTES
- Keep config.json out of version control.
- When executing an uploaded file, always reference it via .\__Download\<file> in -Command.
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

# =========================
# Block 3 - Global settings
# =========================
$commandTimeout  = 600     # seconds for New-TaniumPackage -Command_Timeout (default is 60)
$packageTTL      = 3600    # seconds for New-TaniumPackage -Expire_Seconds (default is 660)

# Helper: optional SHA-256 calculator for a remote URL (only used if you don't supply it)
function Get-RemoteFileSha256 {
    param([Parameter(Mandatory)][string]$Url)
    $tmp = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
    try {
        Invoke-WebRequest -Uri $Url -OutFile $tmp
        (Get-FileHash -Algorithm SHA256 -Path $tmp).Hash.ToLowerInvariant()
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

# =========================
# Block 4 - Packages to create (3 cases)
# =========================
$packages = @(
    # 1) Command only (no files)
    @{
        Name         = 'Case1 - Command only'
        Command      = 'cmd /c ipconfig /all > %TEMP%\net.txt'
        Mode         = 'CommandOnly'
        ContentSetID = 0
    },

    # 2) Upload local files (put files in UploadFolder; reference via .\__Download\ in Command)
    @{
        Name         = 'Case2 - Upload a file'
        Command      = 'cmd /c cscript.exe .\__Download\cleanup.vbs'
        Mode         = 'Upload'
        UploadFolder = 'C:\temp\pkg-cleanup'   # must contain cleanup.vbs (and any other needed files)
        ContentSetID = 2
    },

    # 3) URL file with "check for update" TTL (+ required SHA-256)
    @{
        Name         = 'Case3 - URL file with update check'
        Command      = 'cmd /c cscript.exe .\__Download\remove-sample-files.vbs'
        Mode         = 'Url'
        UrlFile      = @{
            Url                   = 'https://example.com/remove-sample-files.vbs'
            Name                  = 'remove-sample-files.vbs'
            Sha256                = ''          # if empty, the script will compute it
            CheckForUpdateSeconds = 86400       # e.g. 1 day; 0 = Never
        }
        ContentSetID = 2
    }
)

# =========================
# Block 5 - Creation loop
# =========================
foreach ($pkg in $packages) {
    Write-Host "`n=== Package: $($pkg.Name) ==="

    try {
        switch ($pkg.Mode) {

            'CommandOnly' {
                $newPkg = New-TaniumPackage `
                    -Name            $pkg.Name `
                    -Command         $pkg.Command `
                    -Expire_Seconds  $packageTTL `
                    -Command_Timeout $commandTimeout `
                    -ContentSetID    $pkg.ContentSetID

                Write-Host "Created (ID=$($newPkg.id))"
            }

            'Upload' {
                if (-not (Test-Path $pkg.UploadFolder)) {
                    throw "Upload folder not found: $($pkg.UploadFolder)"
                }

                $newPkg = New-TaniumPackage `
                    -Name            $pkg.Name `
                    -Command         $pkg.Command `
                    -Expire_Seconds  $packageTTL `
                    -Command_Timeout $commandTimeout `
                    -ContentSetID    $pkg.ContentSetID

                Write-Host "Created (ID=$($newPkg.id)); uploading payload..."
                Update-ActionPackageFile -PackageID $newPkg.id -UploadFolder $pkg.UploadFolder
                Write-Host "Payload uploaded."
            }

            'Url' {
                # Build Files[] entry expected by the API
                $sha = $pkg.UrlFile.Sha256
                if ([string]::IsNullOrWhiteSpace($sha)) {
                    Write-Host "Computing SHA-256 for URL: $($pkg.UrlFile.Url)"
                    $sha = Get-RemoteFileSha256 -Url $pkg.UrlFile.Url
                }

                $fileObj = [pscustomobject]@{
                    name                     = $pkg.UrlFile.Name
                    url                      = $pkg.UrlFile.Url
                    hash                     = $sha
                    # The property below controls "Check for update" TTL in seconds.
                    # If your Tanium uses a different name (e.g. cache_ttl_seconds/refresh_seconds), adjust here:
                    check_for_update_seconds = $pkg.UrlFile.CheckForUpdateSeconds
                }

                $newPkg = New-TaniumPackage `
                    -Name            $pkg.Name `
                    -Command         $pkg.Command `
                    -Expire_Seconds  $packageTTL `
                    -Command_Timeout $commandTimeout `
                    -ContentSetID    $pkg.ContentSetID `
                    -Files           @($fileObj)

                Write-Host "Created (ID=$($newPkg.id)) with remote file URL."
            }

            default {
                throw "Unknown Mode for package '$($pkg.Name)'. Use 'CommandOnly' | 'Upload' | 'Url'."
            }
        }
    }
    catch {
        Write-Error "Failed to process package '$($pkg.Name)': $($_.Exception.Message)"
    }
}

# =========================
# Block 6 - Cleanup
# =========================
try {
    if (Test-Path $TempXml) {
        Remove-Item $TempXml -Force -ErrorAction SilentlyContinue
        Write-Host "Temporary CLIXML removed: $TempXml"
    }
} catch {
    Write-Warning "Could not remove temporary CLIXML ($TempXml): $($_.Exception.Message)"
}
