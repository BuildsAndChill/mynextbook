# Configuration des Bases de Données

## Architecture Cloud-First

Cette application utilise une approche cloud-first avec des bases de données PostgreSQL hébergées :

- **Production (Master)** → PostgreSQL Render
- **Développement (Dev)** → PostgreSQL Neon
- **Tests** → PostgreSQL Neon (même base que dev)

## Configuration Locale

### Option 1: Script PowerShell (Recommandé)
```powershell
.\setup-dev.ps1
```

### Option 2: Manuel
```powershell
$env:DATABASE_URL="postgresql://neondb_owner:npg_Cescv3pSqhB7@ep-little-moon-afc2poep-pooler.c-2.us-west-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
```

## Configuration Render

### Production (Master)
- Utilise `render.yaml` 
- Base de données PostgreSQL Render
- Variables d'environnement automatiques

### Développement (Dev)
- Utilise `render-dev.yaml`
- Base de données PostgreSQL Neon
- Configuration manuelle des variables

## Variables d'Environnement

| Environnement | DATABASE_URL | Source |
|---------------|--------------|---------|
| Local Dev | Neon | Variable locale |
| Local Test | Neon | Variable locale |
| Render Prod | Render | Base Render |
| Render Dev | Neon | render-dev.yaml |

## Commandes Utiles

```bash
# Créer la base de données
rails db:create

# Exécuter les migrations
rails db:migrate

# Lancer le serveur
rails server

# Tests
rails test
```

## Dépannage

Si vous avez des erreurs de connexion :
1. Vérifiez que `DATABASE_URL` est définie
2. Vérifiez la connectivité internet
3. Vérifiez que Neon est accessible
4. Exécutez `.\setup-dev.ps1` pour reconfigurer
