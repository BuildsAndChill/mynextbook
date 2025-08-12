# Script de test pour l'import CSV
# Usage: rails runner test_import.rb

puts "=== Test d'import CSV avec partage de livres ==="

# Vérifier qu'il y a des utilisateurs
user = User.first
if user.nil?
  puts "❌ Aucun utilisateur trouvé dans la base de données"
  exit
end

puts "✅ Utilisateur trouvé: #{user.email} (ID: #{user.id})"

# Vérifier le nombre de livres avant l'import
books_before = user.books.count
puts "📚 Nombre de livres avant l'import: #{books_before}"

# Créer un fichier CSV de test temporaire
csv_content = <<~CSV
  Book Id,Title,Author,My Rating,Average Rating,Number of Pages,Date Added,Date Read,ISBN,ISBN13,Exclusive Shelf,Bookshelves
  12345,The Great Gatsby,F. Scott Fitzgerald,4,3.92,180,2023-01-15,2023-02-20,978-0743273565,9780743273565,read,read classics
  12346,1984,George Orwell,5,4.19,328,2023-03-10,,978-0451524935,9780451524935,to-read,dystopian fiction
  12347,Pride and Prejudice,Jane Austen,4,4.28,432,2023-04-05,2023-05-15,978-0141439518,9780141439518,read,classics romance
  12348,To Kill a Mockingbird,Harper Lee,5,4.27,281,2023-06-01,2023-07-15,978-0446310789,9780446310789,read,classics
  12349,The Catcher in the Rye,J.D. Salinger,3,3.81,277,2023-08-10,,978-0316769488,9780316769488,to-read,classics
CSV

# Écrire le fichier temporaire
require 'tempfile'
temp_file = Tempfile.new(['test_import', '.csv'])
temp_file.write(csv_content)
temp_file.rewind

puts "📄 Fichier CSV de test créé: #{temp_file.path}"

# Tester l'import
begin
  puts "🔄 Début de l'import..."
  importer = GoodreadsCsvImporter.new(temp_file.path, user)
  result = importer.import
  
  puts "📊 Résultat de l'import: #{result.inspect}"
  
  if result[:success]
    puts "✅ Import réussi! #{result[:count]} livres importés"
  else
    puts "❌ Import échoué: #{result[:error]}"
  end
  
rescue => e
  puts "💥 Erreur lors de l'import: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

# Vérifier le nombre de livres après l'import
books_after = user.books.count
puts "📚 Nombre de livres après l'import: #{books_after}"

# Afficher les détails des livres importés
imported_books = user.books.where.not(goodreads_book_id: nil)
puts "📖 Livres importés:"
imported_books.each do |book|
  puts "  - #{book.title} par #{book.author} (Status: #{book.status}, Rating: #{book.rating}, Goodreads ID: #{book.goodreads_book_id})"
end

# Tester l'import d'un deuxième utilisateur avec les mêmes livres
puts "\n🔄 Test d'import pour un deuxième utilisateur..."
second_user = User.second || User.create!(email: "test2@example.com", password: "password123")
puts "✅ Deuxième utilisateur: #{second_user.email} (ID: #{second_user.email})"

books_before_user2 = second_user.books.count
puts "📚 Nombre de livres avant l'import (user2): #{books_before_user2}"

# Réinitialiser le fichier pour le deuxième utilisateur
temp_file.rewind

begin
  importer2 = GoodreadsCsvImporter.new(temp_file.path, second_user)
  result2 = importer2.import
  
  if result2[:success]
    puts "✅ Import réussi pour user2! #{result2[:count]} livres importés"
  else
    puts "❌ Import échoué pour user2: #{result2[:error]}"
  end
  
rescue => e
  puts "💥 Erreur lors de l'import pour user2: #{e.message}"
end

books_after_user2 = second_user.books.count
puts "📚 Nombre de livres après l'import (user2): #{books_after_user2}"

# Vérifier que les deux utilisateurs ont des livres séparés
puts "\n🔍 Vérification de la séparation des livres:"
puts "User1 (#{user.email}): #{user.books.count} livres"
puts "User2 (#{second_user.email}): #{second_user.books.count} livres"

# Vérifier qu'un livre spécifique existe pour les deux utilisateurs
gatsby_user1 = user.books.find_by(goodreads_book_id: 12345)
gatsby_user2 = second_user.books.find_by(goodreads_book_id: 12345)

if gatsby_user1 && gatsby_user2
  puts "✅ 'The Great Gatsby' existe pour les deux utilisateurs (IDs: #{gatsby_user1.id}, #{gatsby_user2.id})"
  puts "   User1: #{gatsby_user1.title} - Status: #{gatsby_user1.status} - Rating: #{gatsby_user1.rating}"
  puts "   User2: #{gatsby_user2.title} - Status: #{gatsby_user2.status} - Rating: #{gatsby_user2.rating}"
else
  puts "❌ Problème: 'The Great Gatsby' n'existe pas pour les deux utilisateurs"
end

# Nettoyer
temp_file.close
temp_file.unlink

puts "\n=== Test terminé ==="
