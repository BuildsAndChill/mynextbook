class Subscriber < ApplicationRecord
  # Validations
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :interaction_count, numericality: { greater_than: 0 }
  
  # Scopes
  scope :active, -> { where('created_at > ?', 30.days.ago) }
  scope :by_interaction_count, ->(count) { where('interaction_count >= ?', count) }
  
  # Callbacks
  before_save :normalize_email
  before_validation :ensure_interaction_count
  
  # Méthodes de classe
  
  # Trouve ou crée un subscriber par email
  def self.find_or_create_by_email(email, context_data = {})
    subscriber = find_by(email: email.downcase)
    
    if subscriber
      # Mettre à jour les données de contexte
      subscriber.update_context(context_data)
      subscriber
    else
      # Créer un nouveau subscriber
      create!(
        email: email.downcase,
        context: context_data[:context],
        tone_chips: context_data[:tone_chips].is_a?(Array) ? context_data[:tone_chips].join(', ') : context_data[:tone_chips],
        ai_response: context_data[:ai_response],
        parsed_response: context_data[:parsed_response]&.to_json,
        interaction_count: context_data[:interaction_count] || 1,
        session_id: context_data[:session_id]
      )
    end
  end
  
  # Statistiques d'engagement
  def self.engagement_stats
    {
      total: count,
      active_30_days: active.count,
      avg_interactions: average(:interaction_count)&.round(1) || 0,
      top_contexts: group(:context).order(Arel.sql('count(*) DESC')).limit(5).count
    }
  end
  
  # Méthodes d'instance
  
  # Mettre à jour le contexte et incrémenter le compteur
  def update_context(context_data)
    update!(
      context: context_data[:context],
      tone_chips: context_data[:tone_chips].is_a?(Array) ? context_data[:tone_chips].join(', ') : context_data[:tone_chips],
      ai_response: context_data[:ai_response],
      parsed_response: context_data[:parsed_response]&.to_json,
      interaction_count: interaction_count + 1,
      session_id: context_data[:session_id]
    )
  end
  
  # Récupérer les préférences de l'utilisateur
  def preferences
    return {} unless parsed_response.present?
    
    begin
      parsed = JSON.parse(parsed_response)
      {
        context: context,
        tone_chips: tone_chips&.split(', ')&.map(&:strip),
        liked_books: parsed.dig('picks')&.map { |pick| "#{pick['title']} by #{pick['author']}" } || [],
        interaction_count: interaction_count
      }
    rescue JSON::ParserError
      {}
    end
  end
  
  # Vérifier si le subscriber est actif
  def active?
    created_at > 30.days.ago
  end
  
  # Niveau d'engagement basé sur le nombre d'interactions
  def engagement_level
    case interaction_count
    when 1..2
      'new'
    when 3..5
      'engaged'
    when 6..10
      'very_engaged'
    else
      'super_engaged'
    end
  end
  
  private
  
  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
  
  def ensure_interaction_count
    self.interaction_count = 1 if interaction_count.blank? || interaction_count.to_i < 1
  end
end
