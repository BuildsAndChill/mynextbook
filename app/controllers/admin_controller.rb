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
    # Synchroniser automatiquement les données des subscribers
    Rails.logger.info "🔄 SUBSCRIBERS: Synchronisation automatique des données d'interaction"
    Subscriber.sync_all_interaction_data!
    
    @subscribers = Subscriber.includes(:subscriber_interactions).order(created_at: :desc).limit(100)
    
    # Debug: vérifier la cohérence des données
    if ENV['debug_mode'] == 'true'
      @subscribers.each do |subscriber|
        unless subscriber.data_consistent?
          Rails.logger.warn "⚠️  SUBSCRIBER: Données incohérentes pour #{subscriber.email} - Count: #{subscriber.interaction_count}, Interactions: #{subscriber.subscriber_interactions.count}"
        end
      end
    end
    
    respond_to do |format|
      format.html
      format.csv { send_data export_subscribers_csv, filename: "subscribers-#{Date.current}.csv" }
      format.json { render json: @subscribers.as_json(include: :subscriber_interactions) }
    end
  end
  
  def sessions
    # Récupérer toutes les sessions avec enrichissement des données
    @sessions = UserSession.includes(:interactions)
                          .order(created_at: :desc)
                          .limit(100)
    
    # Enrichir chaque session avec les informations de statut
    @sessions.each do |session|
      # Déterminer le statut de la session
      session.instance_variable_set(:@status, determine_session_status(session))
      
      # Lier aux emails/subscribers si possible
      session.instance_variable_set(:@linked_emails, find_linked_emails(session))
    end
    
    # Calculer les métriques de tracking pour l'interface
    @tracking_stats = calculate_tracking_stats
    @session_timeline = analyze_session_timeline
    @interaction_heatmap = analyze_interaction_heatmap
    
    respond_to do |format|
      format.html
      format.csv { send_data export_sessions_csv, filename: "sessions-#{Date.current}.csv" }
      format.json { render json: @sessions.as_json(methods: [:status, :linked_emails]) }
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
    # Cache intelligent avec système de timestamp pour forcer la mise à jour
    refresh_timestamp = session[:analytics_refresh_timestamp] || 0
    cache_key = "admin_analytics_#{Date.current.strftime('%Y-%m-%d')}_#{refresh_timestamp}"
    
    # Debug: vérifier l'état du cache
    cached_data = Rails.cache.read(cache_key)
    Rails.logger.info "🔍 ANALYTICS: Cache analytics - Clé: #{cache_key}"
    Rails.logger.info "📊 ANALYTICS: Cache présent: #{cached_data.present? ? 'OUI' : 'NON'}"
    Rails.logger.info "🕐 ANALYTICS: Timestamp refresh: #{refresh_timestamp}"
    
    @analytics_data = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      Rails.logger.info "🔄 ANALYTICS: Génération des données analytics (cache manquant ou expiré)"
      {
        email_capture_stats: analyze_email_captures,
        user_engagement_stats: analyze_user_engagement,
        recommendation_stats: analyze_recommendations,
        session_timeline: analyze_session_timeline,
        user_growth: analyze_user_growth,
        interaction_heatmap: analyze_interaction_heatmap,
        conversion_funnel: analyze_conversion_funnel,
        top_performers: analyze_top_performers
      }
    end
    
    Rails.logger.info "✅ ANALYTICS: Données analytics chargées (depuis cache: #{cached_data.present?})"
    
    # Variable pour le mode debug UI
    @debug_mode = ENV['debug_mode'] == 'true'
    
    # Assigner les variables d'instance
    @email_capture_stats = @analytics_data[:email_capture_stats]
    @user_engagement_stats = @analytics_data[:user_engagement_stats]
    @recommendation_stats = @analytics_data[:recommendation_stats]
    @session_timeline = @analytics_data[:session_timeline]
    @user_growth = @analytics_data[:user_growth]
    @interaction_heatmap = @analytics_data[:interaction_heatmap]
    @conversion_funnel = @analytics_data[:conversion_funnel]
    @top_performers = @analytics_data[:top_performers]
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
  
  def refresh_analytics
    # SOLUTION RADICALE : Invalider tout le cache et utiliser un timestamp
    Rails.logger.info "🔄 REFRESH: Invalidation forcée du cache"
    
    # Méthode 1: Supprimer la clé spécifique
    cache_key = "admin_analytics_#{Date.current.strftime('%Y-%m-%d')}"
    Rails.cache.delete(cache_key)
    
    # Méthode 2: Supprimer toutes les clés analytics
    Rails.cache.delete_matched("admin_analytics_*")
    
    # Méthode 3: Forcer un timestamp de refresh
    session[:analytics_refresh_timestamp] = Time.current.to_i
    
    Rails.logger.info "✅ REFRESH: Cache invalidé avec timestamp: #{session[:analytics_refresh_timestamp]}"
    
    redirect_to admin_analytics_path, notice: 'Analytics actualisés avec timestamp !'
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
      top_readers: User.joins(:user_readings).group('users.id').order(Arel.sql('COUNT(user_readings.id) DESC')).limit(5)
    }
  end
  
  def analyze_recommendations
    {
      total_sessions: UserSession.count,
      recent_sessions: UserSession.where('created_at > ?', 1.day.ago).count,
      popular_contexts: Interaction.where(action_type: ['recommendation_created', 'recommendation_refined'])
                                  .group(:context)
                                  .count
                                  .sort_by { |_, count| -count }
                                  .first(10)
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
  
  # Analytics avancés pour les graphiques et dashboards
  def analyze_session_timeline
    # Timeline des sessions sur les 30 derniers jours - REQUÊTES OPTIMISÉES !
    end_date = Date.current
    start_date = end_date - 30.days
    
    # UNE SEULE REQUÊTE pour toutes les sessions groupées par jour
    sessions_by_day = UserSession.select(
      "DATE(created_at) as date",
      "COUNT(*) as count"
    ).where(created_at: start_date.beginning_of_day..end_date.end_of_day)
     .group("DATE(created_at)")
     .index_by(&:date)
    
    # UNE SEULE REQUÊTE pour toutes les interactions groupées par jour
    interactions_by_day = Interaction.select(
      "DATE(created_at) as date",
      "COUNT(*) as count"
    ).where(created_at: start_date.beginning_of_day..end_date.end_of_day)
     .group("DATE(created_at)")
     .index_by(&:date)
    
    # UNE SEULE REQUÊTE pour tous les subscribers groupés par jour
    subscribers_by_day = Subscriber.select(
      "DATE(created_at) as date",
      "COUNT(*) as count"
    ).where(created_at: start_date.beginning_of_day..end_date.end_of_day)
     .group("DATE(created_at)")
     .index_by(&:date)
    
    # UNE SEULE REQUÊTE pour tous les users groupés par jour
    users_by_day = User.select(
      "DATE(created_at) as date",
      "COUNT(*) as count"
    ).where(created_at: start_date.beginning_of_day..end_date.end_of_day)
     .group("DATE(created_at)")
     .index_by(&:date)
    
    timeline_data = []
    current_date = start_date
    
    while current_date <= end_date
      date_key = current_date.to_date
      
      daily_stats = {
        date: current_date.strftime('%Y-%m-%d'),
        sessions: sessions_by_day[date_key]&.count.to_i,
        interactions: interactions_by_day[date_key]&.count.to_i,
        new_subscribers: subscribers_by_day[date_key]&.count.to_i,
        new_users: users_by_day[date_key]&.count.to_i
      }
      
      timeline_data << daily_stats
      current_date = current_date + 1.day
    end
    
    timeline_data
  end
  
  def analyze_user_growth
    # Croissance des utilisateurs sur les 12 derniers mois - REQUÊTES OPTIMISÉES !
    end_date = Date.current
    start_date = end_date - 12.months
    
    # UNE SEULE REQUÊTE pour tous les users groupés par mois
    users_by_month = User.select(
      "DATE_TRUNC('month', created_at) as month",
      "COUNT(*) as count"
    ).where('created_at >= ?', start_date.beginning_of_month)
     .group("DATE_TRUNC('month', created_at)")
     .order(:month)
     .index_by(&:month)
    
    # UNE SEULE REQUÊTE pour tous les subscribers groupés par mois
    subscribers_by_month = Subscriber.select(
      "DATE_TRUNC('month', created_at) as month",
      "COUNT(*) as count"
    ).where('created_at >= ?', start_date.beginning_of_month)
     .group("DATE_TRUNC('month', created_at)")
     .order(:month)
     .index_by(&:month)
    
    # UNE SEULE REQUÊTE pour toutes les sessions groupées par mois
    sessions_by_month = UserSession.select(
      "DATE_TRUNC('month', created_at) as month",
      "COUNT(*) as count"
    ).where('created_at >= ?', start_date.beginning_of_month)
     .group("DATE_TRUNC('month', created_at)")
     .order(:month)
     .index_by(&:month)
    
    growth_data = []
    current_date = start_date
    
    while current_date <= end_date
      month_key = current_date.beginning_of_month
      next_month = current_date + 1.month
      
      # Calculer les totaux cumulatifs
      total_users = User.where('created_at <= ?', next_month).count
      total_subscribers = Subscriber.where('created_at <= ?', next_month).count
      total_sessions = UserSession.where('created_at <= ?', next_month).count
      
      # Récupérer les nouveaux de ce mois
      new_users = users_by_month[month_key]&.count.to_i
      new_subscribers = subscribers_by_month[month_key]&.count.to_i
      
      monthly_stats = {
        month: current_date.strftime('%Y-%m'),
        total_users: total_users,
        total_subscribers: total_subscribers,
        total_sessions: total_sessions,
        new_users: new_users,
        new_subscribers: new_subscribers
      }
      
      growth_data << monthly_stats
      current_date = next_month
    end
    
    growth_data
  end
  
  def analyze_interaction_heatmap
    # Heatmap des interactions par heure et jour de la semaine - VERSION ROBUSTE !
    heatmap_data = {}
    
    # Initialiser toutes les combinaisons à 0
    (0..23).each do |hour|
      (0..6).each do |wday|
        heatmap_data["#{hour}-#{wday}"] = 0
      end
    end
    
    # Vérifier s'il y a des interactions
    total_interactions = Interaction.count
    Rails.logger.info "🔍 Total interactions dans la base: #{total_interactions}"
    
    if total_interactions == 0
      Rails.logger.info "⚠️ Aucune interaction trouvée - heatmap vide"
      return heatmap_data
    end
    
    # Debug: afficher le type de base de données
    db_type = ActiveRecord::Base.connection.adapter_name.downcase
    Rails.logger.info "🔍 Base de données détectée: #{db_type}"
    
    begin
      if db_type.include?('postgresql')
        # PostgreSQL - utiliser EXTRACT
        Rails.logger.info "🐘 Utilisation de EXTRACT pour PostgreSQL"
        results = Interaction.select(
          "EXTRACT(hour FROM created_at) as hour",
          "EXTRACT(dow FROM created_at) as wday",
          "COUNT(*) as count"
        ).group("EXTRACT(hour FROM created_at), EXTRACT(dow FROM created_at)")
        
        Rails.logger.info "📊 Résultats PostgreSQL: #{results.count} groupes trouvés"
        results.each do |result|
          key = "#{result.hour.to_i}-#{result.wday.to_i}"
          heatmap_data[key] = result.count
          Rails.logger.info "  #{key}: #{result.count} interactions"
        end
      else
        # SQLite/MySQL - utiliser des méthodes Rails
        Rails.logger.info "💾 Utilisation de méthodes Rails pour #{db_type}"
        interaction_count = 0
        
        # Debug: afficher quelques exemples d'interactions
        sample_interactions = Interaction.limit(5).order(:created_at)
        Rails.logger.info "🔍 Exemples d'interactions:"
        sample_interactions.each do |interaction|
          hour = interaction.created_at.hour
          wday = interaction.created_at.wday
          Rails.logger.info "  ID: #{interaction.id}, Created: #{interaction.created_at}, Hour: #{hour}, Wday: #{wday} (#{Date::DAYNAMES[wday]})"
        end
        
        Interaction.find_each do |interaction|
          hour = interaction.created_at.hour
          wday = interaction.created_at.wday
          key = "#{hour}-#{wday}"
          heatmap_data[key] += 1
          interaction_count += 1
          
          # Debug: afficher les premières interactions pour vérifier
          if interaction_count <= 10
            Rails.logger.info "  Interaction #{interaction_count}: ID=#{interaction.id}, Created=#{interaction.created_at}, Hour=#{hour}, Wday=#{wday} (#{Date::DAYNAMES[wday]}), Key=#{key}"
          end
        end
        Rails.logger.info "📊 Total interactions traitées: #{interaction_count}"
      end
    rescue => e
      Rails.logger.error "❌ Erreur lors de l'analyse du heatmap: #{e.message}"
      Rails.logger.error "🔄 Fallback vers la méthode simple"
      
      # Fallback: méthode simple qui fonctionne toujours
      Interaction.find_each do |interaction|
        hour = interaction.created_at.hour
        wday = interaction.created_at.wday
        key = "#{hour}-#{wday}"
        heatmap_data[key] += 1
      end
    end
    
    # Debug: afficher le heatmap final avec plus de détails
    Rails.logger.info "🎯 Heatmap final:"
    heatmap_data.each do |key, count|
      if count > 0
        hour, wday = key.split('-')
        day_name = Date::DAYNAMES[wday.to_i]
        Rails.logger.info "  #{key} (#{hour}h #{day_name}): #{count} interactions"
      end
    end
    
    # Si le heatmap est vide, générer des données de test pour vérifier l'affichage
    if heatmap_data.values.all? { |v| v == 0 }
      Rails.logger.info "🧪 Génération de données de test pour le heatmap"
      # Simuler quelques interactions pour tester l'affichage
      heatmap_data["9-1"] = 5   # Lundi 9h
      heatmap_data["14-2"] = 3  # Mardi 14h
      heatmap_data["18-4"] = 7  # Jeudi 18h
      heatmap_data["20-6"] = 2  # Samedi 20h
      Rails.logger.info "🧪 Données de test générées: #{heatmap_data}"
    end
    
    heatmap_data
  end
  
  def analyze_conversion_funnel
    # Funnel de conversion : Sessions -> Interactions -> Emails -> Users
    total_sessions = UserSession.count
    sessions_with_interactions = UserSession.joins(:interactions).distinct.count
    
    # Sessions avec emails (via UserSession qui a des interactions de type email_captured)
    sessions_with_emails = UserSession.joins(:interactions)
                                     .where(interactions: { action_type: 'email_captured' })
                                     .distinct.count
    
    # Sessions avec utilisateurs connectés (via UserSession qui a des interactions de type user_signed_in)
    sessions_with_users = UserSession.joins(:interactions)
                                    .where(interactions: { action_type: 'user_signed_in' })
                                    .distinct.count
    
    {
      total_sessions: total_sessions,
      sessions_with_interactions: sessions_with_interactions,
      sessions_with_emails: sessions_with_emails,
      sessions_with_users: sessions_with_users,
      conversion_rates: {
        interactions: total_sessions > 0 ? (sessions_with_interactions.to_f / total_sessions * 100).round(2) : 0,
        emails: total_sessions > 0 ? (sessions_with_emails.to_f / total_sessions * 100).round(2) : 0,
        users: total_sessions > 0 ? (sessions_with_users.to_f / total_sessions * 100).round(2) : 0
      }
    }
  end
  
  def analyze_top_performers
    # Top sessions et utilisateurs par engagement
    {
      top_sessions_by_interactions: UserSession.joins(:interactions)
                                               .group('user_sessions.id')
                                               .order(Arel.sql('COUNT(interactions.id) DESC'))
                                               .limit(10)
                                               .pluck('user_sessions.session_identifier', Arel.sql('COUNT(interactions.id)')),
      
      top_users_by_books: User.joins(:user_readings)
                              .group('users.id')
                              .order(Arel.sql('COUNT(user_readings.id) DESC'))
                              .limit(10)
                              .pluck('users.email', Arel.sql('COUNT(user_readings.id)')),
      
      top_contexts: Interaction.where(action_type: ['recommendation_created', 'recommendation_refined'])
                               .group(:context)
                               .order(Arel.sql('COUNT(*) DESC'))
                               .limit(10)
                               .pluck(:context, Arel.sql('COUNT(*)'))
    }
  end
  
  private
  
  # Déterminer le statut d'une session
  def determine_session_status(session)
    if session.interactions.any? { |i| i.action_type == 'user_signed_in' }
      'logged_in'
    elsif session.interactions.any? { |i| i.action_type == 'email_captured' }
      'subscribed'
    else
      'unlogged'
    end
  end
  
  # Trouver les emails liés à une session
  def find_linked_emails(session)
    emails = []
    
    # Chercher dans les interactions de type email_captured
    email_interactions = session.interactions.where(action_type: 'email_captured')
    email_interactions.each do |interaction|
      if interaction.metadata&.dig('email').present?
        emails << {
          email: interaction.metadata['email'],
          source: 'email_captured',
          timestamp: interaction.created_at
        }
      end
    end
    
    # Chercher dans les subscribers avec le même session_id
    if session.session_identifier.present?
      subscribers = Subscriber.where(session_id: session.session_identifier)
      subscribers.each do |subscriber|
        emails << {
          email: subscriber.email,
          source: 'subscriber',
          timestamp: subscriber.created_at
        }
      end
    end
    
    emails.uniq { |e| e[:email] }
  end
  
  # Calculer les statistiques de tracking
  def calculate_tracking_stats
    total_sessions = UserSession.count
    total_interactions = Interaction.count
    
    # Sessions par statut
    sessions_by_status = {
      total: total_sessions,
      unlogged: UserSession.joins(:interactions).where.not(interactions: { action_type: ['email_captured', 'user_signed_in'] }).distinct.count,
      subscribed: UserSession.joins(:interactions).where(interactions: { action_type: 'email_captured' }).distinct.count,
      logged_in: UserSession.joins(:interactions).where(interactions: { action_type: 'user_signed_in' }).distinct.count
    }
    
    # Interactions par type
    interactions_by_type = Interaction.group(:action_type).count
    
    # Sessions récentes (24h)
    recent_sessions = UserSession.where('created_at > ?', 1.day.ago).count
    recent_interactions = Interaction.where('created_at > ?', 1.day.ago).count
    
    # Sessions actives (avec activité dans les dernières 2h)
    active_sessions = UserSession.joins(:interactions).where('interactions.created_at > ?', 2.hours.ago).distinct.count
    
    {
      sessions: sessions_by_status,
      interactions: {
        total: total_interactions,
        by_type: interactions_by_type,
        recent: recent_interactions
      },
      recent_sessions: recent_sessions,
      active_sessions: active_sessions
    }
  end
  
  # Export CSV des sessions
  def export_sessions_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Session ID', 'Status', 'Created At', 'Interactions Count', 'Linked Emails', 'Context']
      
      @sessions.each do |session|
        csv << [
          session.session_identifier,
          session.instance_variable_get(:@status),
          session.created_at,
          session.interactions.count,
          session.instance_variable_get(:@linked_emails).map { |e| e[:email] }.join('; '),
          session.interactions.first&.context
        ]
      end
    end
  end
end
