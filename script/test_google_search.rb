#!/usr/bin/env ruby

# Test script for Google Custom Search Service
# Usage: rails runner script/test_google_search.rb

require_relative '../config/environment'

puts "=== Test du service Google Custom Search ==="
puts

# Vérifier les variables d'environnement
api_key = ENV['GOOGLE_CUSTOM_SEARCH_API_KEY']
search_engine_id = ENV['GOOGLE_CUSTOM_SEARCH_ENGINE_ID']

puts "Configuration:"
puts "API Key: #{api_key ? '✅ Configurée' : '❌ Manquante'}"
puts "Search Engine ID: #{search_engine_id ? '✅ Configuré' : '❌ Manquant'}"
puts

unless api_key && search_engine_id
  puts "❌ Variables d'environnement manquantes!"
  puts "Veuillez configurer:"
  puts "  - GOOGLE_CUSTOM_SEARCH_API_KEY"
  puts "  - GOOGLE_CUSTOM_SEARCH_ENGINE_ID"
  puts
  puts "Voir GOOGLE_CUSTOM_SEARCH_SETUP.md pour la configuration"
  exit 1
end

# Test avec différents types de requêtes
test_queries = [
  "Harry Potter and the Philosopher's Stone",
  "1984 George Orwell",
  "The Great Gatsby",
  "To Kill a Mockingbird",
  "Pride and Prejudice"
]

puts "Tests de recherche:"
puts "=================="

test_queries.each_with_index do |query, index|
  puts "\n#{index + 1}. Recherche: '#{query}'"
  puts "-" * 50
  
  start_time = Time.now
  result = GoogleCustomSearchService.get_first_search_result(query)
  end_time = Time.now
  
  response_time = ((end_time - start_time) * 1000).round(2)
  
  if result.start_with?('https://www.google.com/search')
    puts "❌ Fallback utilisé (pas de résultat API)"
    puts "   Lien de fallback: #{result}"
  else
    puts "✅ Résultat API trouvé!"
    puts "   Lien direct: #{result}"
  end
  
  puts "   Temps de réponse: #{response_time}ms"
end

puts
puts "=== Test terminé ==="
puts
puts "Notes:"
puts "- Si vous voyez des liens de fallback, vérifiez votre configuration API"
puts "- L'API Google Custom Search a une limite de 100 requêtes gratuites par jour"
puts "- Vérifiez les logs Rails pour plus de détails sur les erreurs"
