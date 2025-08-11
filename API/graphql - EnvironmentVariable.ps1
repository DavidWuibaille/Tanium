<#
.SYNOPSIS
Read URL/token from config.json, authenticate to Tanium Gateway (GraphQL),
then query "System Environment Variables" and print selected variables.
#>

# =========================
# Block 1 - Load config & build auth
# =========================
$ErrorActionPreference = 'Stop'

# config.json is next to this script
$configPath = Join-Path $PSScriptRoot 'config.json'
if (-not (Test-Path $configPath)) { throw "Configuration file not found: $configPath" }

Write-Host "Reading configuration from: $configPath"
$config        = Get-Content -Path $configPath -Raw | ConvertFrom-Json
$TaniumUrl     = $config.TaniumUrl
$TaniumToken   = $config.TaniumApiToken

if ([string]::IsNullOrWhiteSpace($TaniumUrl) -or [string]::IsNullOrWhiteSpace($TaniumToken)) {
    throw "Both TaniumUrl and TaniumApiToken must be provided (config.json or environment variables)."
}

# Normalize host (no scheme/trailing slash)
if ($TaniumUrl -match '^https?://') { $TaniumUrl = $TaniumUrl -replace '^https?://','' -replace '/+$','' }

# Gateway GraphQL endpoint
$uri = "https://$TaniumUrl/plugin/products/gateway/graphql"

# HTTP headers with session token
$headers = @{
    "Content-Type" = "application/json"
    "session"      = $TaniumToken
}

# =========================
# Block 2 - Quick auth check (GraphQL ping)
# =========================
try {
    $pingBody = @{ query = 'query { __typename }' } | ConvertTo-Json
    $pingResp = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $pingBody
    if ($pingResp.errors) {
        $msg = ($pingResp.errors | ForEach-Object { $_.message }) -join '; '
        throw "GraphQL ping returned errors: $msg"
    }
    Write-Host "Authentication OK (Gateway reachable)."
}
catch {
    throw "Authentication or connectivity failed: $($_.Exception.Message)"
}

# =========================
# Block 3 - Actual query
# =========================
# GraphQL variables
$variables = @{
    count  = 1     # adjust as needed
    time   = 10
    maxAge = 600
}

# GraphQL query (columns/values only — no 'rows')
$query = @'
query getEndpoints($count: Int, $time: Int, $maxAge: Int) {
  endpoints(source: { ts: { expectedCount: $count, stableWaitTime: $time, maxAge: $maxAge }}) {
    edges {
      node {
        computerID
        name
        serialNumber
        ipAddress
        sensorReadings(sensors: [{ name: "System Environment Variables" }]) {
          columns {
            name
            values
            sensor { name }
          }
        }
      }
    }
  }
}
'@

# Build request body
$body = @{ query = $query; variables = $variables } | ConvertTo-Json -Depth 20

# Call Gateway
$response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
if ($response.errors) {
    $msg = ($response.errors | ForEach-Object { $_.message }) -join '; '
    throw "GraphQL returned errors: $msg"
}

# =========================
# Block 4 - Parse & print
# =========================
$endpoints = $response.data.endpoints.edges | ForEach-Object { $_.node }

# Env vars to keep (case-sensitive per your example)
$varsToKeep = @("PROCESSOR_LEVEL", "windir", "PROCESSOR_REVISION")

foreach ($endpoint in $endpoints) {
    Write-Host "`n$($endpoint.name) [$($endpoint.ipAddress)] $($endpoint.serialNumber) :"
    foreach ($reading in $endpoint.sensorReadings) {
        foreach ($col in $reading.columns) {
            foreach ($env in ($col.values | Where-Object { $_ })) {
                if ($env -match "^(.*?)=(.*)$") {
                    $name  = $matches[1]
                    $value = $matches[2]
                    if ($varsToKeep -contains $name) {
                        Write-Host "  $name = $value"
                    }
                }
            }
        }
    }
}
