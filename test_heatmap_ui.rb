#!/usr/bin/env ruby

# Test de l'affichage de la heatmap
require_relative 'config/environment'

puts "🧪 Test de l'affichage de la heatmap..."

# Simuler un contrôleur admin
controller = AdminController.new

# Appeler la méthode heatmap
heatmap_data = controller.send(:analyze_interaction_heatmap)

puts "✅ Données de la heatmap récupérées"
puts "📊 Total cellules: #{heatmap_data.keys.count}"

# Vérifier les données non-nulles
non_zero_cells = heatmap_data.select { |_, v| v > 0 }
puts "🔥 Cellules avec interactions: #{non_zero_cells.count}"

if non_zero_cells.any?
  puts "\n📈 Interactions par heure/jour:"
  non_zero_cells.each do |key, count|
    hour, wday = key.split('-')
    day_name = Date::DAYNAMES[wday.to_i]
    puts "  #{hour}h #{day_name}: #{count} interactions"
  end
else
  puts "⚠️ Aucune interaction trouvée - données de test générées"
end

# Vérifier la structure complète
puts "\n🔍 Structure de la grille:"
puts "  - Heures: 0-23 (24 lignes)"
puts "  - Jours: 0-6 (7 colonnes)"
puts "  - Total attendu: 168 cellules"

# Vérifier que toutes les cellules sont présentes
expected_keys = []
(0..23).each do |hour|
  (0..6).each do |wday|
    expected_keys << "#{hour}-#{wday}"
  end
end

missing_keys = expected_keys - heatmap_data.keys
if missing_keys.any?
  puts "❌ Clés manquantes: #{missing_keys.first(5)}..."
else
  puts "✅ Toutes les clés sont présentes"
end

# Vérifier les données brutes des interactions
puts "\n🔍 Vérification des données brutes:"
total_interactions = Interaction.count
puts "Total interactions dans la base: #{total_interactions}"

if total_interactions > 0
  puts "\n📊 Dernières interactions:"
  Interaction.order(:created_at).limit(10).each do |interaction|
    hour = interaction.created_at.hour
    wday = interaction.created_at.wday
    day_name = Date::DAYNAMES[wday]
    puts "  ID: #{interaction.id}, Created: #{interaction.created_at}, Hour: #{hour}, Day: #{day_name} (wday: #{wday})"
  end
  
  puts "\n🔍 Vérification des heures:"
  hours_count = Interaction.group("EXTRACT(hour FROM created_at)").count
  hours_count.sort.each do |hour, count|
    puts "  #{hour}h: #{count} interactions"
  end
  
  puts "\n🔍 Vérification des jours:"
  days_count = Interaction.group("EXTRACT(dow FROM created_at)").count
  days_count.sort.each do |wday, count|
    day_name = Date::DAYNAMES[wday]
    puts "  #{day_name} (wday: #{wday}): #{count} interactions"
  end
end

puts "\n🎯 Test terminé !"
