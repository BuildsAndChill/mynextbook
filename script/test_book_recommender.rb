# script/test_book_recommender.rb
# Usage :
#   AI_DISABLED=1 rails runner script/test_book_recommender.rb   # utilise la réponse mock
#   rails runner script/test_book_recommender.rb                  # appelle l'API (clé requise)

require_relative "../config/environment"

# (1) Données de test (si ta DB est vide)
if Book.count.zero?
  Book.create!(title: "Sapiens", author: "Yuval Noah Harari", status: :read)
  Book.create!(title: "Thinking, Fast and Slow", author: "Daniel Kahneman", status: :read)
  Book.create!(title: "Dune", author: "Frank Herbert", status: :to_read)
end

# (2) Construire un prompt de test
user_context = "Je veux un livre intelligent mais divertissant, mélange de science/psycho et un roman si possible."
read_books   = Book.read.pluck(:title, :author).map { |t, a| "#{t} – #{a}" }.join("\n").presence || "(aucun)"
to_read_books = Book.to_read.pluck(:title, :author).map { |t, a| "#{t} – #{a}" }.join("\n").presence || "(aucun)"

user_prompt = <<~PROMPT
  Contexte utilisateur :
  #{user_context}

  Livres déjà lus :
  #{read_books}

  Livres à lire :
  #{to_read_books}
PROMPT

# (3) Appeler le service
result = BookRecommender.new(user_prompt: user_prompt).call

# (4) Afficher le résultat
puts "=== PROMPT ENVOYÉ ==="
puts user_prompt
puts
if result[:error].present?
  puts "=== ERREUR IA ==="
  puts result[:error]
else
  puts "=== RECOMMANDATIONS PARSÉES ==="
  result[:items].each_with_index do |r, i|
    puts "#{i+1}. #{r[:title_author]}"
    puts "   #{r[:justification]}"
    puts "   Tags: #{r[:tags].join(' ')}"
  end
  puts
  puts "=== RÉPONSE BRUTE (DEBUG) ==="
  puts result[:raw]
end
