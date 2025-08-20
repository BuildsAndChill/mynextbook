# app/services/user_tracking_service.rb
# Service centralisé pour tracker toutes les interactions utilisateur
class UserTrackingService
  def initialize(request = nil)
    @request = request
  end
  
  # Track une interaction pour une session donnée
  def track_interaction(session_identifier, action_type, context = nil, action_data = {}, metadata = {})
    # Trouver ou créer la session
    user_session = UserSession.find_or_create_session(session_identifier, @request)
    
    # Ajouter les métadonnées de la requête
    enhanced_metadata = metadata.merge(
      user_agent: @request&.user_agent,
      ip_address: @request&.remote_ip,
      referrer: @request&.referer,
      utm_params: extract_utm_params(@request)
    )
    
    # Track l'interaction
    interaction = user_session.track_interaction(
      action_type,
      context,
      action_data,
      enhanced_metadata
    )
    
    Rails.logger.info "INTERACTION_TRACKED: session: #{session_identifier} | action: #{action_type} | context: #{context}"
    
    { interaction: interaction, user_session: user_session }
  end
  
  # Track une recommandation créée
  def track_recommendation_created(session_identifier, context, tone_chips = [], books_count = 0)
    result = track_interaction(
      session_identifier,
      'recommendation_created',
      context,
      {
        context: context,
        tone_chips: tone_chips,
        books_count: books_count
      }
    )
    result[:interaction]
  end
  
  # Track un refinement de recommandation
  def track_recommendation_refined(session_identifier, context, refinement_text, books_count = 0)
    result = track_interaction(
      session_identifier,
      'recommendation_refined',
      context,
      {
        context: context,
        refinement_text: refinement_text,
        books_count: books_count
      }
    )
    result[:interaction]
  end
  
  # Track la capture d'un email
  def track_email_captured(session_identifier, email, source = 'recommendation')
    result = track_interaction(
      session_identifier,
      'email_captured',
      nil,
      {
        email: email,
        source: source
      }
    )
    result[:interaction]
  end
  
  # Track un feedback sur un livre
  def track_book_feedback(session_identifier, book_title, book_author, feedback_type, reason = nil)
    result = track_interaction(
      session_identifier,
      "book_#{feedback_type}",
      nil,
      {
        book_title: book_title,
        book_author: book_author,
        reason: reason
      }
    )
    result[:interaction]
  end
  
  # Track une page consultée
  def track_page_view(session_identifier, page_path, page_title = nil)
    result = track_interaction(
      session_identifier,
      'page_viewed',
      nil,
      {
        page_path: page_path,
        page_title: page_title
      }
    )
    result[:interaction]
  end
  
  # Track un clic sur un bouton
  def track_button_click(session_identifier, button_text, button_context = nil)
    result = track_interaction(
      session_identifier,
      'button_clicked',
      button_context,
      {
        button_text: button_text,
        button_context: button_context
      }
    )
    result[:interaction]
  end
  
  # Récupérer les statistiques d'une session
  def session_stats(session_identifier)
    user_session = UserSession.find_by(session_identifier: session_identifier)
    return {} unless user_session
    
    user_session.session_stats
  end
  
  # Récupérer l'historique des interactions d'une session
  def session_interactions(session_identifier, limit = 50)
    user_session = UserSession.find_by(session_identifier: session_identifier)
    return [] unless user_session
    
    user_session.interactions.recent.limit(limit)
  end
  
  # Analyser le funnel d'une session
  def analyze_session_funnel(session_identifier)
    user_session = UserSession.find_by(session_identifier: session_identifier)
    return {} unless user_session
    
    interactions = user_session.interactions.order(:timestamp)
    
    {
      session_start: interactions.first&.timestamp,
      session_end: interactions.last&.timestamp,
      total_interactions: interactions.count,
      funnel: build_funnel(interactions),
      engagement_score: calculate_engagement_score(interactions)
    }
  end
  
  private
  
  def extract_utm_params(request)
    return {} unless request
    
    {
      utm_source: request.params['utm_source'],
      utm_medium: request.params['utm_medium'],
      utm_campaign: request.params['utm_campaign'],
      utm_term: request.params['utm_term'],
      utm_content: request.params['utm_content']
    }.compact
  end
  
  def build_funnel(interactions)
    funnel = []
    
    interactions.each do |interaction|
      case interaction.action_type
      when 'recommendation_created'
        funnel << { step: 'recommendation_created', timestamp: interaction.timestamp, context: interaction.context }
      when 'recommendation_refined'
        funnel << { step: 'recommendation_refined', timestamp: interaction.timestamp, context: interaction.context }
      when 'email_captured'
        funnel << { step: 'email_captured', timestamp: interaction.timestamp, email: interaction.action_data['email'] }
      when 'book_liked', 'book_disliked'
        funnel << { step: interaction.action_type, timestamp: interaction.timestamp, book: interaction.action_data['book_title'] }
      end
    end
    
    funnel
  end
  
  def calculate_engagement_score(interactions)
    score = 0
    
    interactions.each do |interaction|
      case interaction.action_type
      when 'recommendation_created'
        score += 10
      when 'recommendation_refined'
        score += 15
      when 'email_captured'
        score += 20
      when 'book_liked', 'book_disliked'
        score += 5
      when 'button_clicked'
        score += 2
      end
    end
    
    score
  end
end
