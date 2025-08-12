# Architecture de Partage de Livres - Guide d'Utilisation

## 🚀 Installation et Configuration

### 1. Exécuter la Migration
```bash
# Créer les nouvelles tables et migrer les données existantes
bin/rails db:migrate
```

### 2. Vérifier la Migration
```bash
# Vérifier que les tables ont été créées correctement
bin/rails db:schema:dump
```

## 📚 Nouveaux Modèles

### BookMetadata
Gère les informations partagées des livres :
```ruby
# Créer un nouveau livre
book = BookMetadata.create!(
  title: "Harry Potter and the Philosopher's Stone",
  author: "J.K. Rowling",
  isbn13: "9780747532699",
  pages: 223
)

# Trouver un livre par identifiant
book = BookMetadata.find_by_any_identifier(
  isbn13: "9780747532699"
)

# Récupérer l'URL de couverture
cover_url = book.cover_url
# => "https://covers.openlibrary.org/b/isbn/9780747532699-L.jpg"
```

### UserReading
Gère les lectures spécifiques à chaque utilisateur :
```ruby
# Créer une nouvelle lecture pour un utilisateur
reading = UserReading.create!(
  user: current_user,
  book_metadata: book,
  status: 'to_read',
  rating: 5,
  date_added: Date.current
)

# Récupérer toutes les lectures d'un utilisateur
user_readings = current_user.user_readings.includes(:book_metadata)

# Filtrer par statut
to_read_books = current_user.user_readings.to_read
```

## 🔄 Import CSV

### Utilisation Basique
```ruby
# Dans un contrôleur
def import
  if params[:csv_file].present?
    importer = GoodreadsCsvImporter.new(params[:csv_file].tempfile, current_user)
    result = importer.call
    
    if result.errors.any?
      flash[:error] = "Erreurs lors de l'import : #{result.errors.join(', ')}"
    else
      flash[:success] = "Import réussi : #{result.created} créés, #{result.updated} mis à jour"
    end
  end
  
  redirect_to books_path
end
```

### Logs d'Import
L'importateur génère des logs détaillés :
```
Starting CSV import for user: 1
Processing row 2: Harry Potter and the Philosopher's Stone by J.K. Rowling
Created new reading for user: Harry Potter and the Philosopher's Stone (ID: 1)
Processing row 3: The Lord of the Rings by J.R.R. Tolkien
Created new reading for user: The Lord of the Rings (ID: 2)
CSV import completed: 2 created, 0 updated, 0 skipped, 0 errors
```

## 🌐 API OpenLibrary

### Enrichissement Automatique
```ruby
# Enrichir les métadonnées d'un livre
enriched_book = BookMetadataService.enrich_book_metadata(book_metadata)

# Récupérer les informations complètes
book_info = BookMetadataService.fetch_book_info("9780747532699")
# => {
#      title: "Harry Potter and the Philosopher's Stone",
#      author: "J.K. Rowling",
#      pages: 223,
#      cover_url: "https://covers.openlibrary.org/b/id/8406780-L.jpg",
#      publisher: "Bloomsbury",
#      publish_date: "1997",
#      subjects: ["Fantasy fiction", "Wizards", "Magic"]
#    }
```

### Recherche de Livres
```ruby
# Rechercher des livres par titre/auteur
results = BookMetadataService.search_books("Harry Potter", 5)

# Récupérer les couvertures disponibles
cover_urls = BookMetadataService.get_cover_urls("9780747532699")
# => [
#      "https://covers.openlibrary.org/b/isbn/9780747532699-S.jpg",
#      "https://covers.openlibrary.org/b/isbn/9780747532699-M.jpg",
#      "https://covers.openlibrary.org/b/isbn/9780747532699-L.jpg"
#    ]
```

## 🛠️ Tâches Rake

### Enrichissement des Métadonnées
```bash
# Enrichir automatiquement tous les livres avec ISBN
bin/rails books:enrich_metadata

# Afficher les statistiques des identifiants
bin/rails books:stats

# Rechercher un livre
bin/rails books:search['Harry Potter']

# Obtenir les URLs de couverture
bin/rails books:covers[9780747532699]
```

### Exemple de Sortie
```
Starting book metadata enrichment...
Found 150 books with ISBN identifiers
Processing: Harry Potter and the Philosopher's Stone by J.K. Rowling
  ✓ Enriched with pages, publisher
Processing: The Lord of the Rings by J.R.R. Tolkien
  ✓ Enriched with pages, subjects
Enrichment completed!
Books enriched: 142
Errors: 8
```

## 🔍 Requêtes et Scopes

### Scopes Utiles
```ruby
# Livres avec ISBN fiable
reliable_books = BookMetadata.with_isbn13.or(BookMetadata.with_isbn)

# Livres importés depuis Goodreads
imported_books = UserReading.imported

# Livres ajoutés manuellement
manual_books = UserReading.manual

# Filtrer par statut
to_read_books = current_user.user_readings.to_read
reading_books = current_user.user_readings.reading
read_books = current_user.user_readings.read
```

### Requêtes Complexes
```ruby
# Livres lus par plusieurs utilisateurs
popular_books = BookMetadata.joins(:user_readings)
                           .where(user_readings: { status: 'read' })
                           .group('book_metadata.id')
                           .having('COUNT(user_readings.id) > 1')

# Statistiques de lecture par utilisateur
reading_stats = UserReading.reading_list_summary(current_user)
# => {
#      to_read: 15,
#      reading: 3,
#      read: 42,
#      imported: 35,
#      manual: 25,
#      total: 60
#    }
```

## 🎯 Cas d'Usage

### 1. Import d'un Livre Déjà Existant
```ruby
# L'utilisateur A importe "Harry Potter"
user_a_reading = UserReading.create!(
  user: user_a,
  book_metadata: harry_potter_book,
  status: 'read',
  rating: 5
)

# L'utilisateur B importe le même livre
user_b_reading = UserReading.create!(
  user: user_b,
  book_metadata: harry_potter_book, # Même BookMetadata
  status: 'to_read',
  rating: nil
)

# Résultat : Un seul BookMetadata, deux UserReading
```

### 2. Mise à Jour des Métadonnées
```ruby
# Enrichir automatiquement les informations
BookMetadataService.enrich_book_metadata(book_metadata)

# Les deux utilisateurs voient les nouvelles informations
user_a_reading.book_metadata.pages # => 223 (mis à jour)
user_b_reading.book_metadata.pages # => 223 (mis à jour)

# Mais leurs lectures restent personnelles
user_a_reading.rating # => 5
user_b_reading.rating # => nil
```

### 3. Recherche et Découverte
```ruby
# Un utilisateur peut voir quels autres utilisateurs ont lu un livre
book_readers = book_metadata.users.distinct

# Recommandations basées sur les lectures communes
common_readers = current_user.user_readings.read
                           .joins(:book_metadata)
                           .joins("JOIN user_readings ur2 ON ur2.book_metadata_id = book_metadata.id")
                           .where.not(ur2: { user: current_user })
```

## 🚨 Gestion des Erreurs

### Erreurs d'Import
```ruby
# Le service capture et log toutes les erreurs
begin
  result = importer.call
  if result.errors.any?
    # Traiter les erreurs
    result.errors.each do |error|
      Rails.logger.error "Import error: #{error}"
    end
  end
rescue => e
  Rails.logger.error "Fatal import error: #{e.message}"
end
```

### Erreurs d'API
```ruby
# Gestion gracieuse des échecs d'API
book_info = BookMetadataService.fetch_book_info(isbn)
if book_info.nil?
  # Fallback sur les données locales
  Rails.logger.warn "API failed for ISBN #{isbn}, using local data"
end
```

## 📊 Monitoring et Maintenance

### Logs Recommandés
```ruby
# Dans config/application.rb
config.log_level = :info

# Logs spécifiques aux livres
Rails.logger.info "Book metadata enriched: #{book.title}"
Rails.logger.warn "Duplicate book detected: #{isbn}"
Rails.logger.error "API failure for book: #{book.id}"
```

### Métriques à Surveiller
- Nombre de livres avec ISBN fiable
- Taux de succès des appels API
- Performance des requêtes de lecture
- Taille de la base de données

## 🔮 Évolutions Futures

### 1. Cache Redis
```ruby
# Mise en cache des métadonnées enrichies
Rails.cache.fetch("book_metadata_#{book.id}", expires_in: 1.day) do
  BookMetadataService.enrich_book_metadata(book)
end
```

### 2. Synchronisation Goodreads
```ruby
# Sync bidirectionnelle
class GoodreadsSyncService
  def sync_user_books(user)
    # Récupérer les livres depuis Goodreads
    # Mettre à jour les statuts locaux
    # Gérer les conflits
  end
end
```

### 3. Recommandations IA
```ruby
# Utiliser les métadonnées enrichies pour de meilleures recommandations
class AIRecommendationService
  def recommend_books(user)
    # Analyser les préférences
    # Utiliser les sujets et genres
    # Recommandations personnalisées
  end
end
```

## 📞 Support

Pour toute question ou problème :
1. Vérifier les logs Rails
2. Exécuter `bin/rails books:stats` pour diagnostiquer
3. Consulter la documentation de l'API OpenLibrary
4. Vérifier la migration des données existantes
