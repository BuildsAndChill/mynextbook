# Script de configuration pour l'environnement de développement
# Exécutez ce script pour configurer les variables d'environnement

Write-Host "Configuration de l'environnement de développement..." -ForegroundColor Green

# Configuration de la base de données Neon pour le développement
$env:DATABASE_URL = "postgresql://neondb_owner:npg_Cescv3pSqhB7@ep-little-moon-afc2poep-pooler.c-2.us-west-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require"

Write-Host "DATABASE_URL configurée pour Neon" -ForegroundColor Yellow
Write-Host "Vous pouvez maintenant exécuter: rails server" -ForegroundColor Green

# Optionnel: Créer le fichier .env si il n'existe pas
if (!(Test-Path ".env")) {
    @"
# Configuration des bases de données cloud
# Development et Test - Neon
DATABASE_URL=postgresql://neondb_owner:npg_Cescv3pSqhB7@ep-little-moon-afc2poep-pooler.c-2.us-west-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require

# Production - Render (configuré via les variables d'environnement de Render)
# DATABASE_URL est automatiquement configuré par Render
"@ | Out-File -FilePath ".env" -Encoding UTF8
    Write-Host "Fichier .env créé" -ForegroundColor Yellow
}
