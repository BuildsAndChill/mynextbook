# app/services/tracking_batch_service.rb
# Service de tracking par lot pour optimiser les performances
class TrackingBatchService
  include Singleton

  def initialize
    @pending_interactions = []
    @last_save_time = Time.current
    @mutex = Mutex.new
  end

  # Ajouter une interaction au lot en attente
  def add_interaction(session_identifier, action_type, context = nil, action_data = {}, metadata = {})
    return unless TrackingConfigService.enabled?
    return unless TrackingConfigService.should_track_action?(action_type)

    interaction_data = {
      session_identifier: session_identifier,
      action_type: action_type,
      context: context,
      action_data: action_data,
      metadata: metadata,
      timestamp: Time.current
    }

    @mutex.synchronize do
      @pending_interactions << interaction_data
      
      # Vérifier si on doit sauvegarder
      if should_save_now?
        save_batch
      end
    end
  end

  # Sauvegarder immédiatement le lot en attente
  def save_batch
    @mutex.synchronize do
      return if @pending_interactions.empty?

      interactions_to_save = @pending_interactions.dup
      @pending_interactions.clear
      @last_save_time = Time.current

      # Sauvegarder en arrière-plan pour ne pas bloquer
      Thread.new do
        save_interactions_batch(interactions_to_save)
      end
    end
  end

  # Forcer la sauvegarde de tous les lots en attente
  def force_save
    save_batch
  end

  # Nettoyer les anciennes sessions selon la configuration
  def cleanup_old_sessions
    return unless TrackingConfigService.cleanup_days > 0

    cutoff_date = TrackingConfigService.cleanup_days.days.ago
    
    # Supprimer les sessions inactives
    UserSession.where('last_activity < ?', cutoff_date).find_in_batches(batch_size: 100) do |batch|
      batch.each(&:destroy)
    end

    Rails.logger.info "TRACKING: Cleaned up old sessions older than #{TrackingConfigService.cleanup_days} days"
  end

  private

  # Vérifier si on doit sauvegarder maintenant
  def should_save_now?
    config = TrackingConfigService.batch_config
    
    return false unless config[:enabled]
    
    # Sauvegarder si le lot est plein ou si le délai maximum est dépassé
    @pending_interactions.size >= config[:size] ||
    (Time.current - @last_save_time) >= config[:max_delay]
  end

  # Sauvegarder un lot d'interactions
  def save_interactions_batch(interactions_data)
    return if interactions_data.empty?

    begin
      # Grouper par session pour optimiser les requêtes
      sessions_map = {}
      
      interactions_data.each do |data|
        session_id = data[:session_identifier]
        sessions_map[session_id] ||= []
        sessions_map[session_id] << data
      end

      # Traiter chaque session
      sessions_map.each do |session_identifier, interactions|
        user_session = UserSession.find_or_create_session(session_identifier, nil)
        
        # Créer toutes les interactions pour cette session
        interactions.each do |data|
          user_session.interactions.create!(
            action_type: data[:action_type],
            context: data[:context],
            action_data: data[:action_data],
            metadata: data[:metadata],
            timestamp: data[:timestamp]
          )
        end
        
        # Mettre à jour la dernière activité
        user_session.update!(last_activity: Time.current)
      end

      Rails.logger.info "TRACKING: Saved batch of #{interactions_data.size} interactions" if TrackingConfigService.debug?
      
    rescue => e
      Rails.logger.error "TRACKING: Error saving batch: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # En cas d'erreur, remettre les interactions dans le lot
      @mutex.synchronize do
        @pending_interactions.unshift(*interactions_data)
      end
    end
  end
end
