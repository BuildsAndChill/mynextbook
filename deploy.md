# Guide de Déploiement

## Déploiement Automatique

### Branche Master → Production (Render)
- Utilise `render.yaml`
- Base de données PostgreSQL Render
- Déploiement automatique sur push

### Branche Dev → Développement (Render)
- Utilise `render-dev.yaml`
- Base de données PostgreSQL Neon
- Déploiement automatique sur push

## Configuration des Branches

### Master (Production)
```bash
git checkout master
git push origin master
# Déploie automatiquement sur Render avec PostgreSQL Render
```

### Dev (Développement)
```bash
git checkout dev
git push origin dev
# Déploie automatiquement sur Render avec PostgreSQL Neon
```

## Variables d'Environnement

### Production (Master)
- `DATABASE_URL` → Automatiquement configuré par Render
- `RAILS_ENV` → production
- Base de données → PostgreSQL Render

### Développement (Dev)
- `DATABASE_URL` → PostgreSQL Neon (configuré dans render-dev.yaml)
- `RAILS_ENV` → development
- Base de données → PostgreSQL Neon

## Commandes de Déploiement

```bash
# Déployer en production
git checkout master
git push origin master

# Déployer en développement
git checkout dev
git push origin dev

# Vérifier le statut
git status
git branch -a
```

## Monitoring

- **Production** : https://mynextbook.onrender.com
- **Développement** : https://mynextbook-dev.onrender.com
- **Logs** : Dashboard Render → Services → Logs
