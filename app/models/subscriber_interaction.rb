class SubscriberInteraction < ApplicationRecord
  belongs_to :subscriber
  
  # Validations
  validates :interaction_number, presence: true, numericality: { greater_than: 0 }
  validates :context, presence: true
  validates :ai_response, presence: true
  
  # Scopes
  scope :ordered, -> { order(interaction_number: :desc) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Callbacks
  before_validation :ensure_interaction_number
  
  # Méthodes d'instance
  
  # Récupérer les préférences de l'interaction
  def preferences
    return {} unless parsed_response.present?
    
    begin
      parsed = JSON.parse(parsed_response)
      {
        context: context,
        tone_chips: tone_chips&.split(', ')&.map(&:strip),
        liked_books: parsed.dig('picks')&.map { |pick| "#{pick['title']} by #{pick['author']}" } || [],
        interaction_number: interaction_number
      }
    rescue JSON::ParserError
      {}
    end
  end
  
  # Formater la date de création
  def formatted_date
    created_at.strftime("%d/%m/%Y à %H:%M")
  end
  
  # Récupérer le nombre de livres recommandés
  def books_count
    return 0 unless parsed_response.present?
    
    begin
      parsed = JSON.parse(parsed_response)
      parsed['picks']&.count || 0
    rescue JSON::ParserError
      0
    end
  end
  
  private
  
  def ensure_interaction_number
    if interaction_number.blank?
      # Trouver le prochain numéro d'interaction pour ce subscriber
      last_number = subscriber.subscriber_interactions.maximum(:interaction_number) || 0
      self.interaction_number = last_number + 1
    end
  end
end
