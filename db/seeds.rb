# Supprime toutes les données existantes pour éviter les doublons
UserReading.delete_all
BookMetadata.delete_all
User.delete_all

# Créer un utilisateur de test
user = User.create!(
  email: 'test@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

puts "✅ Utilisateur de test créé: #{user.email}"

# Liste simulée comme si elle venait de Goodreads
books_data = [
  # Déjà lus
  { title: "Sapiens", author: "Yuval Noah Harari", rating: 5, status: "read", isbn13: "9780062316097" },
  { title: "Deep Work", author: "Cal Newport", rating: 5, status: "read", isbn13: "9781455586691" },
  { title: "1984", author: "George Orwell", rating: 5, status: "read", isbn13: "9780451524935" },

  # En cours de lecture
  { title: "Thinking, Fast and Slow", author: "Daniel Kahneman", rating: 4, status: "reading", isbn13: "9780374533557" },
  { title: "Clean Code", author: "Robert C. Martin", rating: 4, status: "reading", isbn13: "9780132350884" },

  # À lire
  { title: "Homo Deus", author: "Yuval Noah Harari", status: "to_read", isbn13: "9780062464316" },
  { title: "Atomic Habits", author: "James Clear", status: "to_read", isbn13: "9780735211292" },
  { title: "Educated", author: "Tara Westover", status: "to_read", isbn13: "9780399590504" },
  { title: "The Lean Startup", author: "Eric Ries", status: "to_read", isbn13: "9780307887894" }
]

# Créer les métadonnées des livres et les lectures utilisateur
books_data.each do |book_data|
  # Créer ou récupérer les métadonnées du livre
  book_metadata = BookMetadata.find_or_create_by!(
    title: book_data[:title],
    author: book_data[:author]
  ) do |bm|
    bm.isbn13 = book_data[:isbn13]
    bm.average_rating = 4.5 # Note moyenne simulée
    bm.pages = rand(200..600) # Nombre de pages simulé
  end

  # Créer la lecture utilisateur
  UserReading.create!(
    user: user,
    book_metadata: book_metadata,
    rating: book_data[:rating],
    status: book_data[:status],
    date_added: Date.current - rand(1..365),
    date_read: book_data[:status] == "read" ? Date.current - rand(1..30) : nil
  )
end

puts "✅ #{BookMetadata.count} métadonnées de livres créées"
puts "✅ #{UserReading.count} lectures utilisateur créées"
puts "✅ Base de données initialisée avec succès!"
