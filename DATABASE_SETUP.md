# Configuration des Bases de Données - Stratégie Fichiers Séparés

## Architecture Cloud-First avec Fichiers Séparés

Cette application utilise une approche cloud-first avec des **fichiers de configuration séparés** pour éviter la synchronisation des bases de données entre branches :

- **Master** → `database.master.yml` → PostgreSQL Render (production)
- **Dev** → `database.dev.yml` → PostgreSQL Neon (développement)
- **Tests** → PostgreSQL Neon (même base que dev)

## 🎯 **Avantages de cette Stratégie**

- ✅ **Pas de synchronisation** des configs de DB entre branches
- ✅ **Sécurité absolue** : Master ne peut jamais utiliser Neon
- ✅ **Configuration explicite** : Chaque branche a son propre fichier
- ✅ **Facilité de maintenance** : Configuration claire et séparée

## 📁 **Fichiers de Configuration**

### `config/database.yml` (Principal)
- Configuration par défaut
- **Sera écrasé** par les fichiers spécifiques selon la branche

### `config/database.master.yml` (Master uniquement)
- **Production** : PostgreSQL Render
- **URL fixe** : Render production
- **Environnement** : Production

### `config/database.dev.yml` (Dev uniquement)
- **Development** : PostgreSQL Neon
- **Test** : PostgreSQL Neon
- **Production** : PostgreSQL Neon (pour Render dev)

## 🔄 **Comment Switcher de Configuration**

### Option 1: Script PowerShell (Windows)
```powershell
# Switcher automatiquement selon la branche actuelle
.\bin\switch-database.ps1

# Switcher manuellement
.\bin\switch-database.ps1 master
.\bin\switch-database.ps1 dev
```

### Option 2: Script Bash (Linux/Mac)
```bash
# Switcher automatiquement selon la branche actuelle
./bin/switch-database

# Switcher manuellement
./bin/switch-database master
./bin/switch-database dev
```

### Option 3: Manuel
```bash
# Pour master (Render)
cp config/database.master.yml config/database.yml

# Pour dev (Neon)
cp config/database.dev.yml config/database.yml
```

## 🚀 **Workflow Recommandé**

### 1. **Développement Local**
```bash
git checkout dev
.\bin\switch-database.ps1 dev
rails server
```

### 2. **Déploiement Master**
```bash
git checkout master
.\bin\switch-database.ps1 master
git add config/database.yml
git commit -m "feat: configuration production Render"
git push origin master
```

### 3. **Déploiement Dev**
```bash
git checkout dev
.\bin\switch-database.ps1 dev
git add config/database.yml
git commit -m "feat: configuration development Neon"
git push origin dev
```

## 📋 **Configuration Render**

### Production (Master)
- Utilise `render.yaml`
- **Base de données** : PostgreSQL Render (automatique)
- **Configuration** : `database.master.yml`

### Développement (Dev)
- Utilise `render-dev.yaml`
- **Base de données** : PostgreSQL Neon
- **Configuration** : `database.dev.yml`

## ⚠️ **Points d'Attention**

1. **Toujours switcher** la configuration avant de committer
2. **Vérifier** que le bon fichier est copié
3. **Ne jamais committer** `database.yml` sans avoir switcher
4. **Utiliser les scripts** pour éviter les erreurs

## 🔧 **Dépannage**

Si vous avez des erreurs de connexion :
1. Vérifiez que vous avez bien switcher la configuration
2. Exécutez `.\bin\switch-database.ps1` pour reconfigurer
3. Vérifiez que `config/database.yml` contient la bonne configuration
4. Redémarrez le serveur Rails
