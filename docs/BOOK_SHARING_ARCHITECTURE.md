# Architecture de Partage de Livres

## Vue d'ensemble

Cette architecture permet aux utilisateurs de partager des livres tout en conservant leurs lectures personnelles. Un livre peut être lu par plusieurs utilisateurs, mais chaque utilisateur a ses propres métadonnées de lecture (notes, statut, dates, etc.).

## Structure de la Base de Données

### Table `book_metadata`
Contient les informations partagées d'un livre :
- **Identifiants uniques** : `isbn13`, `isbn`, `goodreads_book_id`
- **Informations de base** : `title`, `author`, `pages`, `average_rating`
- **Index uniques** : Un livre ne peut avoir qu'un seul enregistrement par identifiant

### Table `user_readings`
Table de liaison entre utilisateurs et livres :
- **Relations** : `user_id`, `book_metadata_id`
- **Métadonnées personnelles** : `rating`, `status`, `shelves`, `date_added`, `date_read`
- **Contrainte unique** : Un utilisateur ne peut avoir qu'une lecture par livre

## Hiérarchie des Identifiants

### Priorité 1 : ISBN13 (le plus fiable)
- Format standardisé international
- Permet de récupérer des informations depuis l'API OpenLibrary
- Couvertures de livres disponibles

### Priorité 2 : ISBN
- Format plus ancien mais toujours valide
- Moins fiable que l'ISBN13

### Priorité 3 : Goodreads ID
- Identifiant spécifique à Goodreads
- Utile pour la compatibilité avec les imports existants

### Priorité 4 : Title + Author
- Fallback pour les livres sans identifiant numérique
- Moins fiable (doublons possibles)

## Avantages de cette Architecture

### 1. Partage de Métadonnées
- Les informations de base (titre, auteur, pages) sont partagées
- Évite la duplication de données
- Mise à jour centralisée des informations

### 2. Lectures Personnalisées
- Chaque utilisateur garde ses notes et statuts
- Historique de lecture individuel
- Étagères personnalisées

### 3. Identification Fiable
- Utilisation de l'ISBN comme identifiant principal
- Récupération automatique des couvertures
- Enrichissement via l'API OpenLibrary

### 4. Scalabilité
- Support de nombreux utilisateurs
- Performance optimisée avec des index appropriés
- Migration facile des données existantes

## Utilisation

### Import CSV
```ruby
# Le service d'importation utilise automatiquement l'identifiant le plus fiable
importer = GoodreadsCsvImporter.new(csv_file, current_user)
result = importer.call
```

### Recherche de Livres
```ruby
# Trouver un livre par n'importe quel identifiant
book = BookMetadata.find_by_any_identifier(
  isbn13: "9780747532699",
  title: "Harry Potter and the Philosopher's Stone",
  author: "J.K. Rowling"
)
```

### Enrichissement des Métadonnées
```ruby
# Enrichir automatiquement avec l'API OpenLibrary
enriched_book = BookMetadataService.enrich_book_metadata(book_metadata)
```

## Migration des Données

### Étape 1 : Création des Nouvelles Tables
```bash
bin/rails db:migrate
```

### Étape 2 : Enrichissement des Métadonnées
```bash
bin/rails books:enrich_metadata
```

### Étape 3 : Vérification des Statistiques
```bash
bin/rails books:stats
```

## API et Services

### BookMetadataService
- Récupération d'informations depuis OpenLibrary
- Recherche de livres
- Gestion des couvertures

### Modèles
- `BookMetadata` : Métadonnées partagées
- `UserReading` : Lectures utilisateur
- `User` : Utilisateurs avec leurs lectures

## Gestion des Erreurs

### Identifiants Manquants
- Logs détaillés des erreurs d'importation
- Fallback sur title + author si nécessaire
- Validation des données avant sauvegarde

### API Externe
- Gestion des timeouts
- Retry automatique en cas d'échec
- Cache des résultats pour éviter les appels répétés

## Sécurité

### Isolation des Données
- Chaque utilisateur ne voit que ses propres lectures
- Les métadonnées partagées sont en lecture seule
- Validation des permissions au niveau de l'application

### Validation des Entrées
- Nettoyage des ISBN (suppression des tirets)
- Validation des formats de dates
- Protection contre l'injection SQL

## Performance

### Index Optimisés
- Index unique sur les identifiants
- Index composite sur user_id + book_metadata_id
- Index sur les statuts pour les requêtes fréquentes

### Requêtes Efficaces
- Utilisation de `joins` pour éviter les N+1 queries
- Pagination des résultats
- Cache des métadonnées enrichies

## Maintenance

### Tâches Rake
- Enrichissement automatique des métadonnées
- Statistiques sur la qualité des identifiants
- Recherche et test des APIs

### Monitoring
- Logs détaillés des opérations
- Métriques de performance
- Alertes en cas d'erreur

## Évolutions Futures

### 1. Cache Redis
- Mise en cache des métadonnées enrichies
- Réduction des appels API
- Amélioration des performances

### 2. Synchronisation
- Sync bidirectionnelle avec Goodreads
- Mise à jour automatique des statuts
- Gestion des conflits

### 3. Recommandations
- Utilisation des métadonnées enrichies
- Analyse des préférences utilisateur
- Suggestions personnalisées
