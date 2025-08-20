class UserSession < ApplicationRecord
  # Relations
  has_many :interactions, dependent: :destroy
  
  # Validations
  validates :session_identifier, presence: true, uniqueness: true
  validates :last_activity, presence: true
  
  # Callbacks
  before_validation :ensure_session_identifier, :ensure_last_activity
  
  # Scopes
  scope :active, -> { where('last_activity > ?', 30.days.ago) }
  scope :recent, -> { order(last_activity: :desc) }
  
  # Méthodes de classe
  
  # Trouve ou crée une session utilisateur
  def self.find_or_create_session(identifier, request = nil)
    session = find_by(session_identifier: identifier)
    
    if session
      # Mettre à jour l'activité
      session.update!(last_activity: Time.current)
      session
    else
      # Créer une nouvelle session
      create!(
        session_identifier: identifier,
        device_info: extract_device_info(request),
        user_agent: request&.user_agent,
        ip_address: request&.remote_ip,
        last_activity: Time.current
      )
    end
  end
  
  # Génère un identifiant unique de session
  def self.generate_session_identifier
    SecureRandom.uuid
  end
  
  # Méthodes d'instance
  
  # Track une nouvelle interaction
  def track_interaction(action_type, context = nil, action_data = {}, metadata = {})
    interaction = interactions.create!(
      action_type: action_type,
      context: context,
      action_data: action_data,
      metadata: metadata,
      timestamp: Time.current
    )
    
    # Mettre à jour la dernière activité
    update!(last_activity: Time.current)
    
    # Retourner l'interaction créée
    interaction
  end
  
  # Récupérer les interactions par type
  def interactions_by_type(action_type)
    interactions.where(action_type: action_type).order(timestamp: :desc)
  end
  
  # Compter les interactions par type
  def interaction_count_by_type(action_type)
    interactions.where(action_type: action_type).count
  end
  
  # Récupérer le contexte de la dernière interaction
  def last_context
    interactions.order(timestamp: :desc).first&.context
  end
  
  # Vérifier si la session est active
  def active?
    last_activity > 30.days.ago
  end
  
  # Récupérer les statistiques de la session
  def session_stats
    {
      total_interactions: interactions.count,
      first_interaction: interactions.order(timestamp: :asc).first&.timestamp,
      last_interaction: interactions.order(timestamp: :desc).first&.timestamp,
      contexts_used: interactions.distinct.pluck(:context).compact,
      action_types: interactions.group(:action_type).count
    }
  end
  
  private
  
  def ensure_session_identifier
    self.session_identifier ||= self.class.generate_session_identifier
  end
  
  def ensure_last_activity
    self.last_activity ||= Time.current
  end
  
  def self.extract_device_info(request)
    return nil unless request
    
    {
      browser: request.user_agent&.match(/Chrome|Firefox|Safari|Edge/),
      platform: request.user_agent&.match(/Windows|Mac|Linux|Android|iOS/),
      mobile: request.user_agent&.match(/Mobile|Android|iPhone|iPad/)
    }.compact
  end
end
