# Supprime tous les livres existants pour éviter les doublons
Book.delete_all

# Liste simulée comme si elle venait de Goodreads (titre, auteur, note éventuelle, statut)
books = [
  # Déjà lus
  { title: "Sapiens", author: "Yuval Noah Harari", rating: 5, status: "read" },
  { title: "Deep Work", author: "Cal Newport", rating: 5, status: "read" },
  { title: "1984", author: "George Orwell", rating: 5, status: "read" },

  # En cours de lecture
  { title: "Thinking, Fast and Slow", author: "Daniel Kahneman", rating: 4, status: "reading" },
  { title: "Clean Code", author: "Robert C. Martin", rating: 4, status: "reading" },

  # À lire
  { title: "Homo Deus", author: "Yuval Noah Harari", status: "to_read" },
  { title: "Atomic Habits", author: "James Clear", status: "to_read" },
  { title: "Educated", author: "Tara Westover", status: "to_read" },
  { title: "The Lean Startup", author: "Eric Ries", status: "to_read" }
]

# Insertion en base
Book.create!(books)

puts "✅ #{Book.count} livres ajoutés (simulation import Goodreads)"
