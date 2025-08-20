class AdminController < ApplicationController
  layout 'admin'
  before_action :ensure_admin
  
  # include Kaminari::ActionViewExtension  # Commenté car cause une erreur
  
  def dashboard
    # Gérer à la fois GET et POST pour l'authentification
    if request.post?
      # Si c'est un POST (soumission du formulaire), vérifier le mot de passe
      if params[:admin_password] == ENV['ADMIN_PASSWORD']
        session[:admin_authenticated] = true
        redirect_to admin_dashboard_path
        return
      else
        # Mot de passe incorrect, rester sur la page de mot de passe
        flash.now[:alert] = "Mot de passe incorrect"
        render 'admin/password_prompt', layout: 'application'
        return
      end
    end
    
    # GET normal - afficher le dashboard
    @stats = {
      total_sessions: UserSession.count,
      active_sessions: UserSession.active.count,
      total_interactions: Interaction.count,
      total_subscribers: Subscriber.count,
      total_users: User.count,
      total_books: BookMetadata.count,
      total_readings: UserReading.count,
      recent_sessions: UserSession.where('created_at > ?', 1.day.ago).count,
      recent_subscribers: Subscriber.where('created_at > ?', 1.day.ago).count,
      recent_users: User.where('created_at > ?', 1.day.ago).count,
      recent_interactions: Interaction.where('created_at > ?', 1.day.ago).count
    }
    
    @recent_sessions = UserSession.includes(:interactions).order(created_at: :desc).limit(10)
    @recent_subscribers = Subscriber.order(created_at: :desc).limit(10)
    @recent_users = User.order(created_at: :desc).limit(10)
    @recent_interactions = Interaction.includes(:user_session).order(created_at: :desc).limit(15)
  end
  
  def logs
    @log_files = {
      'application' => 'log/development.log',
      'production' => 'log/production.log',
      'test' => 'log/test.log'
    }
    
    @selected_log = params[:log] || 'application'
    @log_content = read_log_file(@selected_log)
  end
  
  def subscribers
    @subscribers = Subscriber.includes(:subscriber_interactions).order(created_at: :desc).limit(100)
    
    respond_to do |format|
      format.html
      format.csv { send_data export_subscribers_csv, filename: "subscribers-#{Date.current}.csv" }
      format.json { render json: @subscribers.as_json(include: :subscriber_interactions) }
    end
  end
  
  def users
    @users = User.includes(:user_readings, :user_book_feedbacks)
                 .order(created_at: :desc)
                 .limit(100)
    
    respond_to do |format|
      format.html
      format.csv { send_data export_users_csv, filename: "users-#{Date.current}.csv" }
      format.json { render json: @users }
    end
  end
  
  def analytics
    @email_capture_stats = analyze_email_captures
    @user_engagement_stats = analyze_user_engagement
    @recommendation_stats = analyze_recommendations
  end
  
  def export_data
    @export_stats = {
      subscribers_count: Subscriber.count,
      users_count: User.count,
      books_count: BookMetadata.count,
      estimated_size: "#{Subscriber.count + User.count + BookMetadata.count} entrées"
    }
    
    @export_history = [] # À implémenter plus tard avec un modèle ExportHistory
    
    respond_to do |format|
      format.html
      format.csv { send_data export_all_csv(params[:type]), filename: "export-#{params[:type]}-#{Date.current}.csv" }
      format.json { render json: export_all_json(params[:type]) }
    end
  end
  
  def logout
    # Déconnexion admin - effacer la session
    session[:admin_authenticated] = nil
    redirect_to admin_dashboard_path, notice: 'Déconnexion admin effectuée'
  end
  
  private
  
  def ensure_admin
    # MVP: Vérification par mot de passe exclusif
    # L'admin est complètement indépendant de Devise
    
    Rails.logger.info "=== DEBUG: ensure_admin appelé ==="
    Rails.logger.info "Params: #{params.inspect}"
    Rails.logger.info "Session: #{session.inspect}"
    Rails.logger.info "ENV['ADMIN_PASSWORD']: #{ENV['ADMIN_PASSWORD']}"
    
    # Vérifier le mot de passe admin depuis les variables d'environnement
    admin_password = params[:admin_password] || session[:admin_authenticated]
    
    Rails.logger.info "admin_password: #{admin_password}"
    
    if admin_password == ENV['ADMIN_PASSWORD'] && ENV['ADMIN_PASSWORD'] && !ENV['ADMIN_PASSWORD'].empty?
      Rails.logger.info "✅ Mot de passe correct - Accès autorisé"
      session[:admin_authenticated] = true
    elsif session[:admin_authenticated] != true
      Rails.logger.info "🔒 Demande de mot de passe - Authentification requise"
      # Si pas authentifié, demander le mot de passe
      render 'admin/password_prompt', layout: 'application'
      return
    else
      Rails.logger.info "✅ Session déjà authentifiée - Accès autorisé"
    end
  end
  
  def read_log_file(log_name)
    log_path = @log_files[log_name]
    return "Log non trouvé" unless log_path && File.exist?(log_path)
    
    # Lire les 1000 dernières lignes du log
    lines = File.readlines(log_path)
    lines.last(1000).join
  rescue => e
    "Erreur lors de la lecture du log: #{e.message}"
  end
  
  def analyze_email_captures
    {
      total: Subscriber.count,
      today: Subscriber.where('created_at > ?', Date.current.beginning_of_day).count,
      this_week: Subscriber.where('created_at > ?', 1.week.ago).count,
      this_month: Subscriber.where('created_at > ?', 1.month.ago).count,
      by_context: Subscriber.group(:context).count,
      engagement_levels: Subscriber.group(:interaction_count).count
    }
  end
  
  def analyze_user_engagement
    {
      total_users: User.count,
      active_users: User.joins(:user_readings).distinct.count,
      users_with_books: User.joins(:user_readings).distinct.count,
      average_books_per_user: User.joins(:user_readings).count.to_f / User.count,
      top_readers: User.joins(:user_readings).group('users.id').order('COUNT(user_readings.id) DESC').limit(5)
    }
  end
  
  def analyze_recommendations
    {
      total_sessions: TemporaryRecommendationStorage.count,
      recent_sessions: TemporaryRecommendationStorage.where('created_at > ?', 1.day.ago).count,
      popular_contexts: TemporaryRecommendationStorage.group(:context).count
    }
  end
  
  def export_subscribers_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Email', 'Context', 'Tone Chips', 'Interaction Count', 'Created At', 'Updated At']
      
      Subscriber.find_each do |subscriber|
        csv << [
          subscriber.email,
          subscriber.context,
          subscriber.tone_chips&.join(', '),
          subscriber.interaction_count,
          subscriber.created_at,
          subscriber.updated_at
        ]
      end
    end
  end
  
  def export_users_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Email', 'Created At', 'Books Count', 'Last Activity']
      
      User.includes(:user_readings).find_each do |user|
        csv << [
          user.email,
          user.created_at,
          user.user_readings.count,
          user.user_readings.maximum(:updated_at)
        ]
      end
    end
  end
  
  def export_all_csv(type)
    require 'csv'
    
    case type
    when 'subscribers'
      export_subscribers_csv
    when 'users'
      export_users_csv
    when 'books'
      export_books_csv
    when 'analytics'
      export_analytics_csv
    when 'all'
      export_all_data_csv
    else
      export_subscribers_csv
    end
  end
  
  def export_all_json(type)
    case type
    when 'subscribers'
      Subscriber.all.as_json(include: :user_readings)
    when 'users'
      User.all.as_json(include: [:user_readings, :user_book_feedbacks])
    when 'books'
      BookMetadata.all.as_json
    when 'analytics'
      {
        email_captures: analyze_email_captures,
        user_engagement: analyze_user_engagement,
        recommendations: analyze_recommendations
      }
    when 'all'
      {
        subscribers: Subscriber.all.as_json,
                 users: User.all.as_json(include: [:user_readings, :user_book_feedbacks]),
        books: BookMetadata.all.as_json,
        analytics: {
          email_captures: analyze_email_captures,
          user_engagement: analyze_user_engagement,
          recommendations: analyze_recommendations
        }
      }
    else
      Subscriber.all.as_json
    end
  end
  
  def export_books_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Title', 'Author', 'ISBN', 'Published Year', 'Genre', 'Pages', 'Created At']
      
      BookMetadata.find_each do |book|
        csv << [
          book.title,
          book.author,
          book.isbn,
          book.published_year,
          book.genre,
          book.pages,
          book.created_at
        ]
      end
    end
  end
  
  def export_analytics_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Metric', 'Value', 'Details']
      
      # Email captures
      email_stats = analyze_email_captures
      csv << ['Total Subscribers', email_stats[:total], '']
      csv << ['Today', email_stats[:today], '']
      csv << ['This Week', email_stats[:this_week], '']
      
      # User engagement
      user_stats = analyze_user_engagement
      csv << ['Total Users', user_stats[:total_users], '']
      csv << ['Active Users', user_stats[:active_users], '']
      csv << ['Average Books per User', user_stats[:average_books_per_user], '']
      
      # Contexts
      email_stats[:by_context].each do |context, count|
        csv << ['Context', count, context]
      end
    end
  end
  
  def export_all_data_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Data Type', 'Record ID', 'Details']
      
      # Subscribers
      Subscriber.find_each do |subscriber|
        csv << ['Subscriber', subscriber.id, "#{subscriber.email} - #{subscriber.context}"]
      end
      
      # Users
      User.find_each do |user|
        csv << ['User', user.id, "#{user.email} - #{user.user_readings.count} books"]
      end
      
      # Books
      BookMetadata.find_each do |book|
        csv << ['Book', book.id, "#{book.title} by #{book.author}"]
      end
    end
  end
end
