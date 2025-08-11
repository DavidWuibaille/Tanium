# Définir l'URL du fichier brut sur GitHub
$url = "https://nas.wuibaille.fr/WS/provision/Customer-PE.ps1"

# Définir le chemin local pour sauvegarder le fichier à la racine de X:
$localPath = "X:\Customer-PE-ext.ps1"

# Télécharger le fichier
Write-Host "Téléchargement du fichier depuis $url..."
Invoke-WebRequest -Uri $url -OutFile $localPath -UseBasicParsing
Write-Host "Fichier téléchargé et sauvegardé sous : $localPath"

# Vérifier si le fichier a été correctement téléchargé
if (-Not (Test-Path $localPath)) {
    Write-Host "Erreur : Le fichier n'a pas pu être téléchargé." -ForegroundColor Red
    exit 1
}

# Exécuter le script téléchargé
Write-Host "Exécution du script : $localPath..."
Try {
    & $localPath
    Write-Host "Le script a été exécuté avec succès." -ForegroundColor Green
} Catch {
    Write-Host "Erreur pendant l'exécution du script : $($_.Exception.Message)" -ForegroundColor Red
}

