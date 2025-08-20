namespace :subscribers do
  desc "Migrate existing subscriber data to SubscriberInteraction model"
  task migrate_to_interactions: :environment do
    puts "Starting migration of subscriber data to interactions..."
    
    Subscriber.find_each do |subscriber|
      # Créer une interaction pour les données existantes
      if subscriber.context.present? || subscriber.ai_response.present?
        interaction = subscriber.subscriber_interactions.create!(
          context: subscriber.context || 'unknown',
          tone_chips: subscriber.tone_chips,
          ai_response: subscriber.ai_response,
          parsed_response: subscriber.parsed_response,
          session_id: subscriber.session_id,
          interaction_number: 1
        )
        
        puts "✅ Created interaction #{interaction.id} for subscriber #{subscriber.email}"
      else
        puts "⚠️  Skipping subscriber #{subscriber.email} - no interaction data"
      end
    end
    
    puts "Migration completed!"
    puts "Total subscribers: #{Subscriber.count}"
    puts "Total interactions created: #{SubscriberInteraction.count}"
  end
  
  desc "Clean up old subscriber fields after migration"
  task cleanup_old_fields: :environment do
    puts "Cleaning up old subscriber fields..."
    
    # Note: En production, on ferait une migration pour supprimer ces colonnes
    # Pour l'instant, on les laisse pour éviter de casser l'existant
    
    puts "Cleanup completed! (Fields kept for backward compatibility)"
  end
end
