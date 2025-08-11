# Variables du domaine
$domainName = "monlab.lan"
$domainUser = "monlab\david"
$domainPassword = ConvertTo-SecureString "Password1" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($domainUser, $domainPassword)

Write-Host "Starting domain join process for $domainName"

try {
    # Intégrer l'ordinateur au domaine
    Add-Computer -DomainName $domainName -Credential $credential -Force

    Write-Host "Successfully joined the domain $domainName. Rebooting system..."
    
    # Redémarrer l'ordinateur après l'intégration
    # Restart-Computer -Force
} catch {
    # Gérer les erreurs
    Write-Error "Failed to join the domain: $($_.Exception.Message)"
}
