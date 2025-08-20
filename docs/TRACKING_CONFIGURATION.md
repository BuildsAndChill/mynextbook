# 🎯 Configuration du Tracking Utilisateur - MVP

## 📋 **Vue d'ensemble**

Ce document explique comment configurer le système de tracking utilisateur pour optimiser les performances de l'application tout en gardant les données essentielles.

## ⚙️ **Configuration via Variables d'Environnement**

### **1. Niveau de Tracking (TRACKING_LEVEL)**

```bash
# Dans votre fichier .env
TRACKING_LEVEL=standard
```

**Options disponibles :**

- **`no`** : Pas de tracking (désactive complètement)
- **`minimal`** : Seulement les actions critiques (recommandations, emails)
- **`standard`** : Actions critiques + page views (⭐ **NIVEAU PAR DÉFAUT PRODUCTION**)
- **`full`** : Tout est tracké (pour développement/analyse)

### **2. Fréquence de Sauvegarde (TRACKING_SAVE_MODE)**

```bash
TRACKING_SAVE_MODE=batch
```

**Options disponibles :**

- **`immediate`** : Sauvegarde immédiate (plus précis mais plus lent)
- **`batch`** : Sauvegarde par lot (⭐ **NIVEAU PAR DÉFAUT PRODUCTION**)
- **`async`** : Sauvegarde asynchrone (le plus rapide)

### **3. Paramètres de Performance**

```bash
# Taille des lots pour le mode batch (défaut: 50)
TRACKING_BATCH_SIZE=50

# Délai max avant sauvegarde en secondes (défaut: 300 = 5 min)
TRACKING_MAX_DELAY=300
```

## 🎛️ **Finetuning du Tracking**

### **4. Contrôles Granulaires**

```bash
# Activer le tracking des pages vues
TRACK_PAGE_VIEWS=true

# Activer le tracking des clics sur boutons
TRACK_BUTTON_CLICKS=false

# Activer le tracking des métadonnées (IP, User-Agent)
TRACK_METADATA=true
```

**⚠️ Important :** Ces paramètres peuvent surcharger le niveau principal. Par exemple, même en mode `minimal`, si `TRACK_PAGE_VIEWS=true`, les pages vues seront trackées.

### **5. Gestion des Sessions**

```bash
# Limite interactions par session (0 = illimité, défaut: 100)
TRACKING_SESSION_LIMIT=100

# Nettoyage auto des anciennes sessions en jours (0 = pas de nettoyage, défaut: 30)
TRACKING_CLEANUP_DAYS=30
```

### **6. Debug**

```bash
# Mode debug (défaut: false en production)
TRACKING_DEBUG=false
```

## 🚀 **Configurations Recommandées**

### **Production (Performance Optimale)**
```bash
TRACKING_LEVEL=standard
TRACKING_SAVE_MODE=batch
TRACKING_BATCH_SIZE=100
TRACKING_MAX_DELAY=300
TRACK_PAGE_VIEWS=true
TRACK_BUTTON_CLICKS=false
TRACK_METADATA=true
TRACKING_DEBUG=false
```

### **Développement (Analyse Complète)**
```bash
TRACKING_LEVEL=full
TRACKING_SAVE_MODE=immediate
TRACKING_DEBUG=true
```

### **Test (Minimal)**
```bash
TRACKING_LEVEL=minimal
TRACKING_SAVE_MODE=batch
TRACKING_DEBUG=false
```

### **Désactivation Complète**
```bash
TRACKING_LEVEL=no
```

## 📊 **Impact sur les Performances**

### **Mode `minimal`**
- ✅ **Très rapide** : Seulement 3 types d'actions
- ✅ **Données essentielles** : Recommandations et emails
- ❌ **Pas de contexte** : Pas de parcours utilisateur

### **Mode `standard` (Recommandé)**
- ✅ **Équilibré** : Actions critiques + page views
- ✅ **Performance acceptable** : Sauvegarde par lot
- ✅ **Contexte complet** : Parcours utilisateur visible

### **Mode `full`**
- ⚠️ **Peut ralentir** : Toutes les actions trackées
- ✅ **Données complètes** : Analyse approfondie possible
- ❌ **Base de données** : Croissance rapide

## 🔧 **Implémentation Technique**

### **Vérification de Configuration**
```ruby
# Dans vos contrôleurs
if TrackingConfigService.should_track_action?('page_viewed')
  track_user_interaction('page_viewed', request.path)
end
```

### **Log de Configuration**
```ruby
# Afficher la configuration actuelle
TrackingConfigService.log_config
```

### **Nettoyage Automatique**
```ruby
# Nettoyer les anciennes sessions
TrackingBatchService.instance.cleanup_old_sessions
```

## 📝 **Exemples d'Usage**

### **1. Désactiver le Tracking Temporairement**
```bash
# Dans .env
TRACKING_LEVEL=no
```

### **2. Mode Minimal pour Tests**
```bash
TRACKING_LEVEL=minimal
TRACKING_SAVE_MODE=immediate
TRACKING_DEBUG=true
```

### **3. Performance Maximale**
```bash
TRACKING_LEVEL=standard
TRACKING_SAVE_MODE=async
TRACKING_BATCH_SIZE=200
TRACKING_MAX_DELAY=600
```

### **4. Analyse Complète**
```bash
TRACKING_LEVEL=full
TRACKING_SAVE_MODE=immediate
TRACKING_DEBUG=true
TRACK_BUTTON_CLICKS=true
```

## ⚠️ **Notes Importantes**

1. **Valeurs par défaut** : Si une variable n'est pas définie, le système utilise les valeurs de production
2. **Fallback intelligent** : Si un niveau est invalide, le système bascule automatiquement sur `standard`
3. **Performance** : Le mode `batch` est recommandé en production pour éviter de ralentir l'application
4. **Métadonnées** : Toujours activées par défaut pour la sécurité et l'audit
5. **Nettoyage** : Automatique par défaut pour éviter l'accumulation de données

## 🎯 **Recommandation MVP**

Pour un MVP en production, utilisez :
```bash
TRACKING_LEVEL=standard
TRACKING_SAVE_MODE=batch
TRACKING_DEBUG=false
```

Cela vous donne un tracking équilibré avec de bonnes performances et des données suffisantes pour comprendre le comportement utilisateur.
