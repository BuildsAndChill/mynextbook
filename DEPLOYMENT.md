# Architecture de Déploiement

## 🏗️ **Configuration actuelle :**

### **Service de Production (master)**
- **Nom** : `mynextbook-prod`
- **Base de données** : Render PostgreSQL
- **URL** : `https://mynextbook-prod.onrender.com`
- **Configuration** : `render-prod.yaml`

### **Service de Développement (dev)**
- **Nom** : `mynextbook` (service existant)
- **Base de données** : Neon PostgreSQL
- **URL** : `https://mynextbook.onrender.com`
- **Configuration** : `render-dev-neon.yaml`

## 🗄️ **Bases de données :**

### **Production (Render)**
- **Service** : `mynextbook-prod-db`
- **Nom** : `mynextbook_production`
- **Environnement** : Production uniquement

### **Développement (Neon)**
- **Configuration** : Via variable d'environnement `DATABASE_URL`
- **Environnement** : Développement uniquement
- **Sécurité** : Credentials dans les variables d'environnement Render

## 🚀 **Déploiement :**

### **1. Service de Production (master)**
```bash
# Sur Render Dashboard
# New + → Blueprint
# Coller le contenu de render-prod.yaml
```

### **2. Service de Développement (dev)**
```bash
# Sur Render Dashboard
# Modifier le service existant "mynextbook"
# Configurer manuellement les variables d'environnement :
# - DATABASE_URL : Votre URL Neon
# - RAILS_MASTER_KEY : Votre clé Rails
```

## 🔧 **Variables d'environnement :**

### **Production**
- `RAILS_MASTER_KEY` : Clé Rails de production
- `DATABASE_URL` : Automatique (Render)
- `RAILS_ENV` : production

### **Développement**
- `RAILS_MASTER_KEY` : Clé Rails de développement
- `DATABASE_URL` : URL Neon (à configurer manuellement)
- `RAILS_ENV` : development

## 🔒 **Sécurité :**
- ✅ **Aucun credential exposé** dans le code
- ✅ **Variables d'environnement** pour les secrets
- ✅ **Bases séparées** pour dev et prod
- ✅ **Pas de conflits** entre environnements

## 📋 **Workflow Git :**

1. **Développement** → Branche `dev` → Déploie sur service dev (Neon)
2. **Tests** → Validation sur environnement dev
3. **Production** → Merge `dev` → `master` → Déploie sur service prod (Render)
4. **Séparation complète** : Bases isolées, pas de conflits
