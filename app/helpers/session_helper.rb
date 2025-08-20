# app/helpers/session_helper.rb
# Helper pour gérer les sessions utilisateur
module SessionHelper
  # Génère ou récupère l'identifiant de session
  def get_or_create_session_id
    session[:user_session_id] ||= generate_session_id
  end
  
  # Génère un nouvel identifiant de session
  def generate_session_id
    SecureRandom.uuid
  end
  
  # Vérifie si l'utilisateur a une session active
  def has_active_session?
    session[:user_session_id].present?
  end
  
  # Récupère l'identifiant de session actuel
  def current_session_id
    session[:user_session_id]
  end
  
  # Initialise une nouvelle session
  def initialize_user_session
    session[:user_session_id] = generate_session_id
    session[:session_started_at] = Time.current
    
    # Track le début de session
    if defined?(UserTrackingService)
      tracking_service = UserTrackingService.new(request)
      tracking_service.track_interaction(
        session[:user_session_id],
        'session_started',
        nil,
        { session_id: session[:user_session_id] }
      )
    end
    
    session[:user_session_id]
  end
  
  # Track une interaction utilisateur
  def track_user_interaction(action_type, context = nil, action_data = {}, metadata = {})
    return unless has_active_session?
    
    if defined?(UserTrackingService)
      tracking_service = UserTrackingService.new(request)
      tracking_service.track_interaction(
        current_session_id,
        action_type,
        context,
        action_data,
        metadata
      )
    end
  end
  
  # Track une page consultée
  def track_page_view(page_path = request.path, page_title = nil)
    track_user_interaction(
      'page_viewed',
      nil,
      {
        page_path: page_path,
        page_title: page_title
      }
    )
  end
  
  # Track un clic sur un bouton
  def track_button_click(button_text, button_context = nil)
    track_user_interaction(
      'button_clicked',
      button_context,
      {
        button_text: button_text,
        button_context: button_context
      }
    )
  end
  
  # Récupère les statistiques de la session actuelle
  def current_session_stats
    return {} unless has_active_session?
    
    if defined?(UserTrackingService)
      tracking_service = UserTrackingService.new(request)
      tracking_service.session_stats(current_session_id)
    else
      {}
    end
  end
  
  # Récupère l'historique des interactions de la session actuelle
  def current_session_interactions(limit = 10)
    return [] unless has_active_session?
    
    if defined?(UserTrackingService)
      tracking_service = UserTrackingService.new(request)
      tracking_service.session_interactions(current_session_id, limit)
    else
      []
    end
  end
  
  # Vérifie si l'utilisateur a des interactions
  def has_interactions?
    stats = current_session_stats
    stats[:total_interactions].to_i > 0
  end
  
  # Récupère le nombre total d'interactions
  def total_interactions_count
    stats = current_session_stats
    stats[:total_interactions].to_i
  end
  
  # Récupère le contexte de la dernière interaction
  def last_interaction_context
    interactions = current_session_interactions(1)
    interactions.first&.context
  end
  
  # Récupère le score d'engagement de la session
  def session_engagement_score
    return 0 unless has_active_session?
    
    if defined?(UserTrackingService)
      tracking_service = UserTrackingService.new(request)
      analysis = tracking_service.analyze_session_funnel(current_session_id)
      analysis[:engagement_score] || 0
    else
      0
    end
  end
end
