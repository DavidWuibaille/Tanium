<#
.SYNOPSIS
Create a Tanium Deploy software package using the Deploy module cmdlets.
Strategy: clone an existing package to get the exact schema, then modify a few fields.

REQUIRES: Redden-TanREST (for the Deploy cmdlets your screenshot shows)
#>

# =============== Block 0 - Parameters to edit ===============
# New package name and install command
$NewPackageName      = 'Demo - My Package (API)'
$InstallCommandLine  = 'cmd /c echo Hello from Deploy > %TEMP%\hello.txt'

# Choose ONE mode: 'CommandOnly' | 'LocalFile' | 'RemoteURL'
$Mode                = 'CommandOnly'

# If Mode = LocalFile
$LocalFilePath       = 'C:\Temp\payload.msi'

# If Mode = RemoteURL
$RemoteFileUrl       = 'https://example.com/payload.msi'

# An existing simple package to use as a schema template (must exist in your Deploy)
$TemplatePackageName = 'Notepad++ (Gallery)'   # <-- mets ici un paquet simple qui existe chez toi

# Optional: content set ID (leave as-is to keep the template's)
$OverrideContentSetId = $null   # ex: 0  (ou $null pour garder l’ID du template)

# =============== Block 1 - Import & Session ===============
$ErrorActionPreference = 'Stop'
Import-Module Redden-TanREST -Force

# Load config.json next to this script
$configPath = Join-Path $PSScriptRoot 'config.json'
if (-not (Test-Path $configPath)) { throw "Configuration file not found: $configPath" }

$config        = Get-Content -Path $configPath -Raw | ConvertFrom-Json
$TaniumUrl     = $config.TaniumUrl
$TaniumToken   = $config.TaniumApiToken
if ([string]::IsNullOrWhiteSpace($TaniumUrl) -or [string]::IsNullOrWhiteSpace($TaniumToken)) {
    throw "Both TaniumUrl and TaniumApiToken must be provided in config.json."
}
if ($TaniumUrl -match '^https?://') { $TaniumUrl = $TaniumUrl -replace '^https?://','' -replace '/+$','' }

# Create a short-lived CLIXML for Initialize-TaniumSession (same pattern as your other scripts)
$TempXml = Join-Path $env:TEMP 'tanium-session-tmp.apicred'
$ExportObject = @{
  baseURI = $TaniumUrl
  token   = ($TaniumToken | ConvertTo-SecureString -AsPlainText -Force)
}
$ExportObject | Export-Clixml -Path $TempXml
Initialize-TaniumSession -PathToXML $TempXml
Write-Host "Tanium session initialized."

# =============== Block 2 - Helpers ===============
function DeepClone($obj) {
  # round-trip through JSON for a deep copy
  return ($obj | ConvertTo-Json -Depth 100 | ConvertFrom-Json)
}

function Remove-ReadOnlyProps {
  param([Parameter(Mandatory)]$o)
  # remove common read-only or server-managed fields wherever they appear
  $remove = @('id','createdAt','createdBy','updatedAt','updatedBy','lastModified','created','modified','revision','status')
  if ($o -is [System.Collections.IDictionary]) {
    foreach ($k in @($o.Keys)) {
      if ($remove -contains [string]$k) { $o.Remove($k) | Out-Null; continue }
      $o[$k] = Remove-ReadOnlyProps $o[$k]
    }
    return $o
  } elseif ($o -is [System.Collections.IEnumerable] -and -not ($o -is [string])) {
    $new = @()
    foreach ($item in $o) { $new += ,(Remove-ReadOnlyProps $item) }
    return $new
  } else {
    return $o
  }
}

function Replace-AllTempFileIds {
  param(
    [Parameter(Mandatory)]$o,
    [Parameter(Mandatory)][string]$NewTempFileId
  )
  # replace any property named 'tempFileId' or 'fileId' with the new tempfile id (common API shapes)
  $matchKeys = @('tempFileId','fileId')
  if ($o -is [System.Collections.IDictionary]) {
    foreach ($k in @($o.Keys)) {
      if ($matchKeys -contains [string]$k) {
        $o[$k] = $NewTempFileId
      } else {
        $o[$k] = Replace-AllTempFileIds -o $o[$k] -NewTempFileId $NewTempFileId
      }
    }
    return $o
  } elseif ($o -is [System.Collections.IEnumerable] -and -not ($o -is [string])) {
    $new = @()
    foreach ($item in $o) { $new += ,(Replace-AllTempFileIds -o $item -NewTempFileId $NewTempFileId) }
    return $new
  } else {
    return $o
  }
}

function Update-InstallCommand {
  param(
    [Parameter(Mandatory)]$o,
    [Parameter(Mandatory)][string]$CommandLine
  )
  # best-effort: update common command fields if found
  $cmdKeys = @('command','commandLine','installCommand','install_command','command_line')
  if ($o -is [System.Collections.IDictionary]) {
    foreach ($k in @($o.Keys)) {
      if ($cmdKeys -contains [string]$k -and ($o[$k] -is [string])) {
        $o[$k] = $CommandLine
      } else {
        $o[$k] = Update-InstallCommand -o $o[$k] -CommandLine $CommandLine
      }
    }
    return $o
  } elseif ($o -is [System.Collections.IEnumerable] -and -not ($o -is [string])) {
    $new = @()
    foreach ($item in $o) { $new += ,(Update-InstallCommand -o $item -CommandLine $CommandLine) }
    return $new
  } else {
    return $o
  }
}

# =============== Block 3 - Fetch template & prepare body ===============
Write-Host "Fetching template package: $TemplatePackageName"
$template = Get-DeploySoftwarePackage -Name $TemplatePackageName -IncludeHidden
if (-not $template) { throw "Template package '$TemplatePackageName' not found." }
# If multiple, take the first
if ($template -is [System.Array]) { $template = $template[0] }

# Deep clone and strip read-only fields
$bodyObj = DeepClone $template
$bodyObj = Remove-ReadOnlyProps $bodyObj

# Apply basic changes
$bodyObj.name = $NewPackageName
if ($OverrideContentSetId -ne $null) {
  if ($bodyObj.contentSet -and $bodyObj.contentSet.id -ne $null) {
    $bodyObj.contentSet.id = [int]$OverrideContentSetId
  }
}

# Update command line everywhere it appears (best-effort)
$bodyObj = Update-InstallCommand -o $bodyObj -CommandLine $InstallCommandLine

# =============== Block 4 - Attach file if requested ===============
$tempFile = $null
switch ($Mode) {
  'LocalFile' {
    Write-Host "Uploading local file: $LocalFilePath"
    if (-not (Test-Path $LocalFilePath)) { throw "Local file not found: $LocalFilePath" }
    $tempFile = New-DeployTempFile -FilePath $LocalFilePath
    if (-not $tempFile) { throw "Failed to upload local file." }
    $bodyObj = Replace-AllTempFileIds -o $bodyObj -NewTempFileId ([string]$tempFile.id)
  }
  'RemoteURL' {
    Write-Host "Registering remote file URL: $RemoteFileUrl"
    $tempFile = New-DeployTempFile -RemoteURL $RemoteFileUrl
    if (-not $tempFile) { throw "Failed to register remote URL." }
    $bodyObj = Replace-AllTempFileIds -o $bodyObj -NewTempFileId ([string]$tempFile.id)
  }
  'CommandOnly' {
    Write-Host "No file attachment (command-only mode)."
  }
  default { throw "Unknown Mode '$Mode' (use CommandOnly | LocalFile | RemoteURL)" }
}

# =============== Block 5 - Create software package ===============
# Convert to JSON for -Body
$bodyJson = $bodyObj | ConvertTo-Json -Depth 100
Write-Host "Creating Deploy software package: $NewPackageName"
$newPkg = New-DeploySoftwarePackage -Body ($bodyJson | ConvertFrom-Json)
# Certains modules attendent un objet PS, d’autres une chaîne JSON ; si erreur, essaie directement -Body $bodyJson

if (-not $newPkg) {
  Write-Warning "New-DeploySoftwarePackage returned no object. Verify in console if the package exists."
} else {
  Write-Host "Created: ID=$($newPkg.id)  Name=$($newPkg.name)"
}

# Optional: verify by name
$check = Get-DeploySoftwarePackage -Name $NewPackageName -IncludeHidden
if ($check) {
  Write-Host "Verified package exists. Done."
} else {
  Write-Warning "Package not found via Get-DeploySoftwarePackage; please check the console or API logs."
}

# Cleanup temp clixml (optional)
Remove-Item -Path $TempXml -Force -ErrorAction SilentlyContinue
