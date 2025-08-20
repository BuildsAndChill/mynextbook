# Sécurité Admin - MVP

## Vue d'ensemble

La fonctionnalité admin est maintenant sécurisée avec une approche simple mais efficace pour un MVP :

- **Accès masqué** : Le lien admin n'est plus visible dans l'interface principale
- **Accès par URL directe** : Seulement accessible via `/admin/*`
- **Authentification par mot de passe exclusif** : Protection par mot de passe stocké dans les variables d'environnement
- **Indépendant de Devise** : L'admin fonctionne sans connexion utilisateur
- **Session persistante** : Une fois authentifié, l'accès reste ouvert pour la session

## Configuration

### 1. Définir le mot de passe admin

Ajouter dans votre fichier `.env` :

```bash
ADMIN_PASSWORD=votre_mot_de_passe_secret_ici
```

**⚠️ Important** : 
- Utilisez un mot de passe fort
- Ne commitez jamais le fichier `.env` sur GitHub
- Le fichier `.env.example` contient un template

### 2. Redémarrer l'application

Après avoir modifié le `.env`, redémarrez votre serveur Rails.

## Utilisation

### Accès à l'administration

1. **Allez directement** sur une URL admin (ex: `/admin/dashboard`)
2. **Entrez le mot de passe** admin quand demandé
3. **Accédez** à toutes les fonctionnalités admin

**Note** : Aucune connexion utilisateur n'est requise pour l'admin

### URLs disponibles

- `/admin/dashboard` - Tableau de bord principal
- `/admin/logs` - Consultation des logs
- `/admin/subscribers` - Gestion des abonnés
- `/admin/users` - Gestion des utilisateurs
- `/admin/analytics` - Statistiques et analyses
- `/admin/export_data` - Export des données

## Sécurité implémentée

### ✅ Protection active

- [x] Lien admin masqué de l'interface principale
- [x] Vérification de connexion utilisateur
- [x] Authentification par mot de passe
- [x] Session persistante après authentification
- [x] Protection de toutes les routes admin

### 🔒 Niveau de sécurité

**Niveau MVP** : Protection contre les curieux et fouineurs
- **Mot de passe en dur** dans les variables d'environnement
- **Session persistante** pour éviter la répétition
- **Accès par URL directe** uniquement

**Pour la production** : Considérer
- Système de rôles utilisateur
- Authentification à deux facteurs
- Logs d'accès admin
- Expiration de session

## Dépannage

### Problème : "Accès non autorisé"
- Vérifiez que `ADMIN_PASSWORD` est défini dans `.env`
- Vérifiez que le serveur a été redémarré après modification du `.env`

### Problème : Mot de passe refusé
- Vérifiez l'orthographe du mot de passe
- Vérifiez que le fichier `.env` est bien chargé
- Redémarrez le serveur après modification du `.env`

### Problème : Page blanche sur /admin/*
- Vérifiez que le contrôleur `AdminController` fonctionne
- Vérifiez les logs Rails pour les erreurs

## Évolution future

Quand le projet évoluera au-delà du MVP :

1. **Système de rôles** : Ajouter un champ `admin` au modèle User
2. **Permissions granulaires** : Différents niveaux d'accès admin
3. **Audit trail** : Logger tous les accès et actions admin
4. **Authentification robuste** : 2FA, expiration de session, etc.

## Support

Pour toute question sur la sécurité admin, consulter :
- Les logs Rails (`log/development.log`)
- Le contrôleur `app/controllers/admin_controller.rb`
- La vue de mot de passe `app/views/admin/password_prompt.html.erb`
