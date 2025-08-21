# Migration de Mailgun vers Resend

## Vue d'ensemble

Ce document décrit la migration de Mailgun vers Resend comme fournisseur d'emails principal pour l'application MyNextBook.

## Pourquoi Resend ?

- **Performance** : API moderne et rapide
- **Coût** : Tarification plus avantageuse pour les volumes moyens
- **Simplicité** : Configuration plus simple que Mailgun
- **Fiabilité** : Service stable et bien supporté

## Changements effectués

### 1. Dependencies
- ✅ Ajout de la gem `resend ~> 0.7`
- ❌ Commenté `mailgun-ruby ~> 1.2` (gardé en fallback)

### 2. Configuration
- ✅ Nouvel initializer `config/initializers/resend.rb`
- ✅ Mise à jour `config/environments/development.rb`
- ✅ Mise à jour `config/environments/production.rb`
- ✅ Mise à jour `.env.example`

### 3. Priorité des services

#### Développement local
1. **Gmail SMTP** (priorité haute - économise les appels API)
2. **Resend** (optionnel pour tester)
3. **File storage** (fallback final)

#### Production
1. **Resend** (priorité haute)
2. **File storage** (fallback final)

## Configuration requise

### Variables d'environnement
```bash
# Configuration Gmail pour le développement local (priorité haute)
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password

# Configuration Resend pour la production (obligatoire)
RESEND_API_KEY=your-resend-api-key-here
RESEND_DOMAIN=mynextbook.com

# Configuration de l'expéditeur par défaut
MAILER_SENDER=noreply@mynextbook.com
```

## Logique de priorité

### Pourquoi Gmail en priorité en développement ?
- **Économie** : Évite de consommer les appels API Resend pendant le développement
- **Fiabilité** : Gmail fonctionne bien en local (pas de restrictions de ports cloud)
- **Test** : Permet de tester les emails sans coût
- **Flexibilité** : Possibilité de basculer sur Resend si nécessaire

### Pourquoi Resend en production ?
- **Performance** : API optimisée pour la production
- **Scalabilité** : Gère mieux les volumes élevés
- **Monitoring** : Outils de suivi et analytics avancés
- **Fiabilité** : Service dédié aux emails transactionnels

## Test de la configuration

### Script de test
```bash
ruby script/test_resend.rb
```

### Vérifications manuelles
1. Vérifier que `SMTP_USERNAME` et `SMTP_PASSWORD` sont définies pour le dev
2. Vérifier que `RESEND_API_KEY` est définie pour la production
3. Vérifier que la gem Resend est installée
4. Vérifier qu'ActionMailer utilise la bonne méthode selon l'environnement

## Migration en production

### 1. Préparation
- [ ] Obtenir une clé API Resend
- [ ] Configurer le domaine dans Resend
- [ ] Tester en environnement de développement avec Gmail
- [ ] Tester avec Resend en développement (optionnel)

### 2. Déploiement
- [ ] Ajouter `RESEND_API_KEY` dans les variables d'environnement Render
- [ ] Déployer la nouvelle version
- [ ] Vérifier les logs pour confirmer l'utilisation de Resend

### 3. Validation
- [ ] Envoyer un email de test
- [ ] Vérifier la délivrabilité
- [ ] Surveiller les métriques Resend

## Rollback

Si des problèmes surviennent, il est possible de revenir à Mailgun en :
1. Supprimant `RESEND_API_KEY` des variables d'environnement
2. L'application utilisera automatiquement File storage comme fallback

## Avantages de cette approche

- **Migration progressive** : Pas de rupture de service
- **Économie en développement** : Gmail évite de consommer l'API Resend
- **Configuration flexible** : Facile de changer de fournisseur
- **Tests automatisés** : Script de validation inclus
- **Séparation des environnements** : Logique différente dev/prod

## Support

Pour toute question sur la configuration Resend :
- [Documentation officielle Resend](https://resend.com/docs)
- [Gem Ruby Resend](https://github.com/resendlabs/resend-ruby)
- [Support Resend](https://resend.com/support)
