# Workflow Dev → Test → Prod avec Render + GitHub Actions CI

## 🏗️ Architecture des Branches

```
feature/* → dev → main
   ↓         ↓      ↓
  PR      Staging  Prod
```

- **`main`** = Production (déploiement auto via Render)
- **`dev`** = Intégration/Staging (déploiement auto via Render)
- **`feature/*`** = Micro-features → PR vers `dev`

## 🚀 Déploiement Render

### Infrastructure as Code
Le fichier `render.yaml` configure automatiquement :
- **Service Web** : Ruby on Rails + Puma
- **Base de données** : PostgreSQL (plan free)
- **Migrations** : Exécution automatique après déploiement
- **Variables d'environnement** : Configuration centralisée

### Configuration
- **Plan** : Free tier
- **Région** : Frankfurt
- **Auto-deploy** : Activé sur push vers `main` et `dev`

## 🔧 Variables d'Environnement

### À configurer dans Render (Service → Environment) :

| Variable | Valeur | Description |
|----------|---------|-------------|
| `RAILS_MASTER_KEY` | Contenu de `config/master.key` | Clé de chiffrement Rails |
| `OPENAI_API_KEY` | Votre clé API OpenAI | Pour l'IA en production |
| `AI_DISABLED` | `0` (optionnel) | Désactiver l'IA si nécessaire |
| `DATABASE_URL` | Auto-injecté | Connexion DB via `fromDatabase` |

## 🧪 CI/CD avec GitHub Actions

### Workflow
- **Déclenchement** : Push sur `dev`, `main`, `feature/**` + PRs
- **Tests** : Minitest + PostgreSQL
- **Environnement** : Ubuntu + Ruby 3.2
- **Sécurité** : `AI_DISABLED=1` en CI (pas d'appels IA)

### Tests Locaux
```bash
# Lancer les tests localement
bin/rails test

# Vérifier la santé de l'app
curl http://localhost:3000/health
```

## ✅ Critères "Done"

- [ ] **Healthcheck OK** : `/health` retourne `200 OK`
- [ ] **CI OK** : GitHub Actions passent sur `dev` et `main`
- [ ] **Staging OK** : Déploiement `dev` → Render fonctionne
- [ ] **Prod OK** : Déploiement `main` → Render fonctionne

## 📋 Checklist Render

### 1. Configuration Initiale
- [ ] Connecter le repo GitHub → Render
- [ ] Créer le service Web depuis `render.yaml`
- [ ] Vérifier la création automatique de la DB

### 2. Variables d'Environnement
- [ ] Ajouter `RAILS_MASTER_KEY` (contenu de `config/master.key`)
- [ ] Ajouter `OPENAI_API_KEY`
- [ ] Vérifier `AI_DISABLED=0` (optionnel)
- [ ] Vérifier `DATABASE_URL` injecté automatiquement

### 3. Déploiement
- [ ] Vérifier `postDeployCommand: rails db:migrate`
- [ ] Tester le déploiement initial
- [ ] Vérifier l'auto-deploy sur push

### 4. Staging (Optionnel)
- [ ] Cloner le service pour créer un staging
- [ ] Brancher sur `dev` (plan free + DB free)
- [ ] Tester le workflow feature → dev → staging

## 🔄 Workflow de Développement

1. **Feature** : `git checkout -b feature/nouvelle-fonctionnalite`
2. **Développement** : Code + tests + commit
3. **PR vers dev** : `git push origin feature/nouvelle-fonctionnalite`
4. **Staging** : Auto-déploiement sur `dev`
5. **PR vers main** : `dev` → `main` après validation
6. **Production** : Auto-déploiement sur `main`

## 🚨 Garde-fous

- **Feature flag IA** : `AI_DISABLED=1` désactive complètement l'IA
- **Tests obligatoires** : CI doit passer avant merge
- **Staging obligatoire** : Test sur `dev` avant `main`
- **Rollback** : Render permet de revenir à la version précédente
