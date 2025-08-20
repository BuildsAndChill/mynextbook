# 🚀 Architecture de Tracking Utilisateur - My Next Book

## 📋 **Vue d'ensemble**

Ce document décrit la nouvelle architecture de tracking utilisateur qui remplace l'ancien système basé sur `session[:user_actions]`. Le nouveau système est conçu pour être **robuste**, **scalable** et **flexible**, permettant de tracker tous les utilisateurs qu'ils soient anonymes, subscribers ou utilisateurs authentifiés.

## 🏗️ **Architecture des Modèles**

### **1. UserSession (Base)**
```ruby
class UserSession < ApplicationRecord
  has_many :interactions, dependent: :destroy
  
  # Identifiant unique de session (cookie/machine)
  validates :session_identifier, presence: true, uniqueness: true
  
  # Métadonnées de la session
  validates :last_activity, presence: true
  
  # Méthodes principales
  def self.find_or_create_session(identifier, request = nil)
  def track_interaction(action_type, context, action_data, metadata)
  def session_stats
end
```

**Responsabilités :**
- ✅ Créer/maintenir des sessions anonymes
- ✅ Tracker l'activité utilisateur
- ✅ Gérer les métadonnées (IP, User-Agent, Device)
- ✅ Fournir des statistiques de session

### **2. Interaction (Tracking)**
```ruby
class Interaction < ApplicationRecord
  belongs_to :user_session
  
  # Types d'actions prédéfinis
  ACTION_TYPES = {
    'recommendation_created' => 'Création de recommandation',
    'recommendation_refined' => 'Refinement de recommandation',
    'email_captured' => 'Email capturé',
    'page_viewed' => 'Page consultée',
    'button_clicked' => 'Bouton cliqué',
    # ... et plus
  }
  
  # Méthodes principales
  def action_name
  def formatted_action_data
  def formatted_metadata
end
```

**Responsabilités :**
- ✅ Enregistrer chaque action utilisateur
- ✅ Structurer les données d'action
- ✅ Fournir des métadonnées enrichies
- ✅ Formater les données pour l'affichage

### **3. Subscriber (Hérite de UserSession)**
```ruby
class Subscriber < ApplicationRecord
  # Hérite de UserSession + ajoute l'email
  # Garde l'historique des interactions
end
```

### **4. User (Devise + Hérite de Subscriber)**
```ruby
class User < ApplicationRecord
  # Hérite de Subscriber + ajoute l'authentification
  # Garde tout l'historique des interactions
end
```

## 🔧 **Services et Helpers**

### **UserTrackingService**
```ruby
class UserTrackingService
  def track_interaction(session_identifier, action_type, context, action_data, metadata)
  def track_recommendation_created(session_identifier, context, tone_chips, books_count)
  def track_recommendation_refined(session_identifier, context, refinement_text, books_count)
  def track_email_captured(session_identifier, email, source)
  def session_stats(session_identifier)
  def analyze_session_funnel(session_identifier)
end
```

**Responsabilités :**
- ✅ API centralisée pour le tracking
- ✅ Méthodes spécialisées par type d'action
- ✅ Analyse des sessions et funnels
- ✅ Gestion des métadonnées enrichies

### **SessionHelper**
```ruby
module SessionHelper
  def get_or_create_session_id
  def track_user_interaction(action_type, context, action_data, metadata)
  def track_page_view(page_path, page_title)
  def track_button_click(button_text, button_context)
  def current_session_stats
  def total_interactions_count
end
```

**Responsabilités :**
- ✅ Gestion des sessions dans les vues
- ✅ Méthodes de tracking simplifiées
- ✅ Accès aux statistiques de session
- ✅ Intégration avec ApplicationController

## 🚀 **Utilisation dans les Contrôleurs**

### **ApplicationController**
```ruby
class ApplicationController < ActionController::Base
  include SessionHelper
  before_action :ensure_user_session
  
  private
  
  def ensure_user_session
    get_or_create_session_id unless has_active_session?
    track_page_view
  end
end
```

**Automatique :**
- ✅ Initialisation de session à chaque requête
- ✅ Tracking automatique des pages consultées
- ✅ Gestion transparente des sessions

### **RecommendationsController**
```ruby
# Ancien système
track_user_action('recommendation_created', { context: context })

# Nouveau système
track_user_interaction('recommendation_created', context, {
  tone_chips: tone_chips,
  include_history: include_history,
  books_count: @parsed_response&.dig(:picks)&.count || 0
})
```

**Avantages :**
- ✅ Données structurées et typées
- ✅ Métadonnées automatiques (IP, User-Agent)
- ✅ Contexte préservé
- ✅ Comptage précis des interactions

### **SubscribersController**
```ruby
# Track email capture
track_user_interaction('email_captured', nil, {
  email: email,
  source: 'recommendation'
})

# Utilise la session courante
context_data = extract_context_from_session
result = EmailCaptureService.new.capture_email(email, context_data, current_session_id)
```

## 📊 **Interface Admin**

### **Admin::TrackingController**
```ruby
class Admin::TrackingController < AdminController
  def index
    @user_sessions = UserSession.includes(:interactions)
                               .order(last_activity: :desc)
                               .limit(100)
  end
  
  def analytics
    @total_sessions = UserSession.count
    @active_sessions = UserSession.active.count
    @total_interactions = Interaction.count
    @action_stats = Interaction.group(:action_type).count
  end
end
```

**Fonctionnalités :**
- ✅ Vue arborescente des sessions
- ✅ Détail des interactions par session
- ✅ Statistiques globales
- ✅ Export CSV/JSON
- ✅ Analyse des funnels

## 🔄 **Migration depuis l'Ancien Système**

### **Avant (session[:user_actions])**
```ruby
# Stockage en session (limité, pas persistant)
session[:user_actions] ||= []
session[:user_actions] << {
  action: 'recommendation_created',
  context: context,
  timestamp: Time.current
}

# Comptage manuel
total = session[:user_actions].count { |a| ['recommendation_created', 'recommendation_refined'].include?(a[:action]) }
```

### **Après (UserSession + Interaction)**
```ruby
# Stockage persistant en base
track_user_interaction('recommendation_created', context, {
  tone_chips: tone_chips,
  books_count: books_count
})

# Comptage automatique
total = total_interactions_count
```

## 📈 **Avantages du Nouveau Système**

### **1. Robustesse**
- ✅ **Persistance** : Données sauvegardées en base
- ✅ **Intégrité** : Relations et validations
- ✅ **Récupération** : Pas de perte de données

### **2. Scalabilité**
- ✅ **Performance** : Index sur les colonnes clés
- ✅ **Requêtes** : Scopes et associations optimisés
- ✅ **Export** : CSV/JSON pour l'analyse

### **3. Flexibilité**
- ✅ **Types d'actions** : Extensibles et configurables
- ✅ **Métadonnées** : Enrichies automatiquement
- ✅ **Contexte** : Préservé et structuré

### **4. Analytics**
- ✅ **Funnels** : Analyse des parcours utilisateur
- ✅ **Engagement** : Score calculé automatiquement
- ✅ **Segmentation** : Par type d'action, contexte, etc.

## 🧪 **Tests et Validation**

### **1. Test des Sessions**
```ruby
# Dans la console Rails
session = UserSession.find_or_create_session("test-123")
session.track_interaction('page_viewed', '/home', { referrer: 'google' })
session.session_stats
```

### **2. Test du Tracking**
```ruby
# Dans un contrôleur
track_user_interaction('button_clicked', 'homepage', {
  button_text: 'Get Started',
  button_context: 'hero_section'
})
```

### **3. Vérification Admin**
- Aller sur `/admin/tracking`
- Vérifier que les sessions sont créées
- Vérifier que les interactions sont trackées
- Exporter les données pour validation

## 🔮 **Évolutions Futures**

### **1. Intégration Subscriber**
- Migration des données existantes
- Association des sessions avec les emails
- Historique complet des interactions

### **2. Intégration User**
- Liaison des sessions avec les comptes
- Fusion des données anonymes et authentifiées
- Profils utilisateur enrichis

### **3. Analytics Avancés**
- Tableaux de bord personnalisés
- Segmentation des utilisateurs
- Prédiction de comportement
- A/B testing des fonctionnalités

## 📝 **Notes d'Implémentation**

### **1. Sécurité**
- Les sessions sont isolées par identifiant unique
- Pas d'accès aux données d'autres utilisateurs
- Métadonnées IP pour audit et sécurité

### **2. Performance**
- Index sur `session_identifier`, `action_type`, `timestamp`
- Limitation des requêtes (100 sessions max par défaut)
- Pagination pour les gros volumes

### **3. Maintenance**
- Nettoyage automatique des sessions inactives (>30 jours)
- Logs détaillés pour debugging
- Export des données pour sauvegarde

---

**🎯 Objectif :** Avoir un système de tracking robuste qui permet de comprendre le comportement de tous les utilisateurs, de l'anonyme au connecté, pour optimiser l'expérience et l'engagement.
