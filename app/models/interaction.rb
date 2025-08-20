class Interaction < ApplicationRecord
  # Relations
  belongs_to :user_session
  
  # Validations
  validates :action_type, presence: true
  validates :timestamp, presence: true
  
  # Scopes
  scope :recent, -> { order(timestamp: :desc) }
  scope :by_type, ->(type) { where(action_type: type) }
  scope :by_context, ->(context) { where(context: context) }
  
  # Callbacks
  before_validation :ensure_timestamp
  
  # Méthodes de classe
  
  # Types d'actions prédéfinis
  ACTION_TYPES = {
    # Recommandations
    'recommendation_created' => 'Création de recommandation',
    'recommendation_refined' => 'Refinement de recommandation',
    'recommendation_viewed' => 'Visualisation de recommandation',
    
    # Email et engagement
    'email_captured' => 'Email capturé',
    'email_clicked' => 'Email cliqué',
    'email_opened' => 'Email ouvert',
    
    # Navigation
    'page_viewed' => 'Page consultée',
    'button_clicked' => 'Bouton cliqué',
    'link_clicked' => 'Lien cliqué',
    
    # Feedback
    'book_liked' => 'Livre aimé',
    'book_disliked' => 'Livre détesté',
    'feedback_provided' => 'Feedback fourni',
    
    # Authentification
    'signup_attempted' => 'Tentative d\'inscription',
    'signup_completed' => 'Inscription complétée',
    'login_attempted' => 'Tentative de connexion',
    'login_completed' => 'Connexion réussie',
    
    # Autres
    'session_started' => 'Session démarrée',
    'session_ended' => 'Session terminée',
    'error_occurred' => 'Erreur survenue'
  }.freeze
  
  # Méthodes d'instance
  
  # Récupérer le nom lisible de l'action
  def action_name
    ACTION_TYPES[action_type] || action_type.humanize
  end
  
  # Vérifier si c'est une action de recommandation
  def recommendation_action?
    action_type.start_with?('recommendation_')
  end
  
  # Vérifier si c'est une action d'engagement
  def engagement_action?
    action_type.start_with?('email_') || action_type.start_with?('book_')
  end
  
  # Récupérer les données d'action formatées
  def formatted_action_data
    return {} unless action_data.present?
    
    case action_type
    when 'recommendation_created', 'recommendation_refined'
      {
        context: action_data['context'],
        tone_chips: action_data['tone_chips'],
        books_count: action_data['books_count'] || 0
      }
    when 'email_captured'
      {
        email: action_data['email'],
        source: action_data['source']
      }
    when 'book_liked', 'book_disliked'
      {
        book_title: action_data['book_title'],
        book_author: action_data['book_author'],
        reason: action_data['reason']
      }
    else
      action_data
    end
  end
  
  # Récupérer les métadonnées formatées
  def formatted_metadata
    return {} unless metadata.present?
    
    {
      user_agent: metadata['user_agent'],
      ip_address: metadata['ip_address'],
      referrer: metadata['referrer'],
      utm_source: metadata['utm_source'],
      utm_medium: metadata['utm_medium'],
      utm_campaign: metadata['utm_campaign']
    }.compact
  end
  
  # Formater la date pour l'affichage
  def formatted_timestamp
    timestamp.strftime("%d/%m/%Y à %H:%M")
  end
  
  # Récupérer le temps écoulé depuis l'interaction
  def time_ago
    time_ago_in_words(timestamp)
  end
  
  private
  
  def ensure_timestamp
    self.timestamp ||= Time.current
  end
end
