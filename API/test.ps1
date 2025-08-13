<#
But : lire les infos endpoints à partir du cache (TDS) via GraphQL (Tanium Gateway)
#>

# --- Pré-requis : même init que ton script ---
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
Import-Module Redden-TanREST -Force

# Charger config.json + Initialiser la session (identique à ton script)
$configPath = Join-Path $PSScriptRoot 'config.json'
if (-not (Test-Path $configPath)) { throw "Configuration file not found: $configPath" }
$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

$TaniumUrl      = if ($config.TaniumUrl)      { $config.TaniumUrl }      else { $env:TANIUM_URL }
$TaniumApiToken = if ($config.TaniumApiToken) { $config.TaniumApiToken } else { $env:TANIUM_TOKEN }
if ($TaniumUrl -match '^https?://') { $TaniumUrl = $TaniumUrl -replace '^https?://','' -replace '/+$','' }

$TempXml = Join-Path $env:TEMP 'tanium-session-tmp.apicred'
@{
  baseURI = $TaniumUrl
  token   = ($TaniumApiToken | ConvertTo-SecureString -AsPlainText -Force)
} | Export-Clixml -Path $TempXml

Initialize-TaniumSession -PathToXML $TempXml
# (Le point d’accès GraphQL est /plugin/products/gateway/graphql côté Tanium; même auth que REST. :contentReference[oaicite:1]{index=1})

# --- Requête GraphQL (TDS/cached) ---
# NB : ici on filtre sur l’OS qui "contient Windows".
# Si le champ diffère dans ton schéma (ex: operatingSystemName), adapte 'path' et/ou les champs retournés.
$query = @'
query ($first:Int, $after:Cursor, $os:String!) {
  endpoints(
    first: $first
    after: $after
    # Filtre simple : champ "operatingSystem" qui contient la valeur $os
    filter: { path: "operatingSystem", value: $os, op: CONTAINS }
  ) {
    totalRecords
    edges {
      node {
        id
        name
        ipAddress
        serialNumber
        operatingSystem
        eidLastSeen
      }
    }
    pageInfo { hasNextPage endCursor }
  }
}
'@

# Variables initiales (page de 500 éléments)
$variables = @{
  first = 500
  after = $null
  os    = 'Windows'
}

# --- Exécution + pagination ---
$all = New-Object System.Collections.Generic.List[object]

do {
  # Invoke-TaniumGateway exécute la requête/variables avec ta session Redden-TanREST. :contentReference[oaicite:2]{index=2}
  $out = Invoke-TaniumGateway -Query $query -Variables $variables

  $page = $out.data.endpoints
  foreach ($edge in $page.edges) {
    $n = $edge.node
    $all.Add([pscustomobject]@{
      Id        = $n.id
      Name      = $n.name
      IP        = $n.ipAddress
      Serial    = $n.serialNumber
      OS        = $n.operatingSystem
      LastSeen  = $n.eidLastSeen
    })
  }

  $variables.after = $page.pageInfo.endCursor
} while ($page.pageInfo.hasNextPage)

# Affichage (Grid)
$all | Out-GridView -Title 'Windows endpoints (TDS cached via GraphQL)'

# --- Nettoyage ---
Remove-Item $TempXml -Force -ErrorAction SilentlyContinue
