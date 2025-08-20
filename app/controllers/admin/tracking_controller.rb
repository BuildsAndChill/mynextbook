# app/controllers/admin/tracking_controller.rb
# Contrôleur admin pour visualiser le tracking des sessions utilisateur
class Admin::TrackingController < AdminController
  def index
    @user_sessions = UserSession.includes(:interactions)
                               .order(last_activity: :desc)
                               .limit(100)
    
    respond_to do |format|
      format.html
      format.json { render json: @user_sessions.as_json(include: :interactions) }
      format.csv { send_data export_tracking_csv, filename: "user-tracking-#{Date.current}.csv" }
    end
  end
  
  def show
    @user_session = UserSession.includes(:interactions).find(params[:id])
    @interactions = @user_session.interactions.order(timestamp: :desc)
    @session_stats = @user_session.session_stats
    
    respond_to do |format|
      format.html
      format.json { render json: @user_session.as_json(include: :interactions) }
    end
  end
  
  def analytics
    @total_sessions = UserSession.count
    @active_sessions = UserSession.active.count
    @total_interactions = Interaction.count
    
    # Statistiques par type d'action
    @action_stats = Interaction.group(:action_type).count
    
    # Sessions avec le plus d'interactions
    @top_sessions = UserSession.joins(:interactions)
                               .group('user_sessions.id')
                               .order('COUNT(interactions.id) DESC')
                               .limit(10)
    
    # Interactions récentes
    @recent_interactions = Interaction.includes(:user_session)
                                     .order(timestamp: :desc)
                                     .limit(20)
    
    respond_to do |format|
      format.html
      format.json { render json: analytics_data }
    end
  end
  
  private
  
  def export_tracking_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << [
        'Session ID',
        'Device Info',
        'IP Address',
        'Total Interactions',
        'First Interaction',
        'Last Activity',
        'Engagement Score'
      ]
      
      @user_sessions.each do |session|
        csv << [
          session.session_identifier,
          session.device_info&.values&.join(', '),
          session.ip_address,
          session.interactions.count,
          session.interactions.order(:timestamp).first&.timestamp,
          session.last_activity,
          calculate_engagement_score(session.interactions)
        ]
      end
    end
  end
  
  def analytics_data
    {
      total_sessions: @total_sessions,
      active_sessions: @active_sessions,
      total_interactions: @total_interactions,
      action_stats: @action_stats,
      top_sessions: @top_sessions.map { |s| {
        id: s.id,
        session_identifier: s.session_identifier,
        total_interactions: s.interactions.count,
        last_activity: s.last_activity
      }},
      recent_interactions: @recent_interactions.map { |i| {
        id: i.id,
        action_type: i.action_type,
        context: i.context,
        timestamp: i.timestamp,
        session_id: i.user_session.session_identifier
      }}
    }
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
