# ---- [Bloc 1] Import du module ----
$ModuleName = "Redden-TanREST"
Import-Module $ModuleName -Force

# ---- [Bloc 2] Configuration des variables principales ----
$TaniumUrl = "lab-fr-metsys-api.cloud.tanium.com"
$TaniumApiToken = "token-a887d4e4d45b452188f797e09fe17449476ebed24"

# Import du module
Import-Module Redden-TanREST -Force

$TempXml = "$env:TEMP\tanium-session-tmp.apicred"

# Créer l'objet à exporter (même format que New-TaniumSessionXML)
$ExportObject = @{
    baseURI = $TaniumUrl
    token   = $TaniumApiToken | ConvertTo-SecureString -AsPlainText -Force
}

# Exporter l'objet en CLIXML
$ExportObject | Export-Clixml -Path $TempXml

# Initialiser la session avec le XML
Initialize-TaniumSession -PathToXML $TempXml


Get-InteractQuestionResult -CanonicalText "Get Computer Name from all machines with Computer Name starts with srvadmin"
# Afficher la réponse
$result

<#
New-ComputerGroup `
    -Name "SRVADMIN_Computers" `
    -Text "(Computer Name starts with srvadmin)" `
    -Type 0
#>
Remove-Item $TempXml -Force


#Get-ContentSet

$newPackage = New-TaniumPackage `
    -Name "MyNewPackage3" `
    -Command "cmd /c cscript.exe remove-sample-files.vbs" `
    -ContentSetID 2

# Récupère l’ID du package nouvellement créé
$newPackage.id

Update-ActionPackageFile -PackageID 68379 -UploadFolder "C:\temp"
