# app/services/tracking_config_service.rb
# Service de configuration pour le tracking utilisateur
class TrackingConfigService
  class << self
    # Niveau de tracking (MVP - valeurs par défaut de production)
    def level
      level_value = ENV.fetch('TRACKING_LEVEL', 'standard').downcase.to_sym
      
      # Validation du niveau
      case level_value
      when :no, :minimal, :standard, :full
        level_value
      else
        Rails.logger.warn "TRACKING: Niveau invalide '#{level_value}', utilisation du niveau 'standard' par défaut"
        :standard
      end
    end

    # Vérifier si le tracking est activé
    def enabled?
      level != :no
    end

    # Mode de sauvegarde
    def save_mode
      ENV.fetch('TRACKING_SAVE_MODE', 'batch').downcase.to_sym
    end

    # Taille des lots pour le mode batch
    def batch_size
      ENV.fetch('TRACKING_BATCH_SIZE', '50').to_i
    end

    # Délai maximum avant sauvegarde (en secondes)
    def max_delay
      ENV.fetch('TRACKING_MAX_DELAY', '300').to_i
    end

    # Activer le tracking des pages vues
    def track_page_views?
      enabled? && ENV.fetch('TRACK_PAGE_VIEWS', 'true').downcase == 'true'
    end

    # Activer le tracking des clics sur boutons
    def track_button_clicks?
      enabled? && ENV.fetch('TRACK_BUTTON_CLICKS', 'false').downcase == 'true'
    end

    # Activer le tracking des métadonnées
    def track_metadata?
      enabled? && ENV.fetch('TRACK_METADATA', 'true').downcase == 'true'
    end

    # Limite du nombre d'interactions par session
    def session_limit
      ENV.fetch('TRACKING_SESSION_LIMIT', '100').to_i
    end

    # Nettoyage automatique des anciennes sessions (en jours)
    def cleanup_days
      ENV.fetch('TRACKING_CLEANUP_DAYS', '30').to_i
    end

    # Mode debug du tracking
    def debug?
      ENV.fetch('TRACKING_DEBUG', 'false').downcase == 'true'
    end

    # Vérifier si une action doit être trackée selon le niveau
    def should_track_action?(action_type)
      return false unless enabled?
      
      case level
      when :no
        false
      when :minimal
        # Seulement les actions critiques pour le business
        %w[recommendation_created recommendation_refined email_captured].include?(action_type)
      when :standard
        # Actions critiques + page views (niveau par défaut de production)
        %w[recommendation_created recommendation_refined email_captured page_viewed].include?(action_type)
      when :full
        # Tout est tracké (pour le développement/analyse)
        true
      else
        # Fallback sur standard si niveau invalide
        %w[recommendation_created recommendation_refined email_captured page_viewed].include?(action_type)
      end
    end

    # Vérifier si une action doit être sauvegardée immédiatement
    def should_save_immediately?(action_type)
      return true if save_mode == :immediate
      
      # Actions critiques toujours sauvegardées immédiatement
      %w[email_captured recommendation_created].include?(action_type)
    end

    # Configuration pour le mode batch
    def batch_config
      {
        enabled: save_mode == :batch,
        size: batch_size,
        max_delay: max_delay
      }
    end

    # Configuration pour le mode async
    def async_config
      {
        enabled: save_mode == :async,
        queue_name: 'tracking_interactions'
      }
    end

    # Log de configuration (pour debug)
    def log_config
      return unless debug?
      
      Rails.logger.info "=== TRACKING CONFIG (MVP) ==="
      Rails.logger.info "Level: #{level} (#{enabled? ? 'ENABLED' : 'DISABLED'})"
      Rails.logger.info "Save Mode: #{save_mode}"
      Rails.logger.info "Page Views: #{track_page_views?} (#{level == :standard ? 'DEFAULT' : 'OVERRIDE'})"
      Rails.logger.info "Button Clicks: #{track_button_clicks?} (#{level == :standard ? 'DEFAULT' : 'OVERRIDE'})"
      Rails.logger.info "Metadata: #{track_metadata?} (#{level == :standard ? 'DEFAULT' : 'OVERRIDE'})"
      Rails.logger.info "Session Limit: #{session_limit}"
      Rails.logger.info "Cleanup Days: #{cleanup_days}"
      Rails.logger.info "============================="
    end

    # Afficher la configuration actuelle (toujours visible)
    def current_config
      {
        level: level,
        enabled: enabled?,
        save_mode: save_mode,
        batch_size: batch_size,
        max_delay: max_delay,
        track_page_views: track_page_views?,
        track_button_clicks: track_button_clicks?,
        track_metadata: track_metadata?,
        session_limit: session_limit,
        cleanup_days: cleanup_days,
        debug: debug?,
        source: config_source
      }
    end

    # Identifier la source de la configuration
    def config_source
      if ENV['TRACKING_LEVEL']
        'environment_variable'
      else
        'default_production'
      end
    end

    # Log de démarrage (toujours visible en production)
    def log_startup_config
      Rails.logger.info "🚀 TRACKING: Configuration initialisée"
      Rails.logger.info "   Level: #{level} (#{enabled? ? 'ACTIVÉ' : 'DÉSACTIVÉ'})"
      Rails.logger.info "   Save Mode: #{save_mode}"
      Rails.logger.info "   Source: #{config_source}"
      
      if config_source == 'default_production'
        Rails.logger.info "   ℹ️  Utilisation des valeurs par défaut de production"
        Rails.logger.info "   ℹ️  Pour personnaliser, définissez TRACKING_LEVEL dans .env"
      end
      
      Rails.logger.info "   📊 Page Views: #{track_page_views?}"
      Rails.logger.info "   📊 Button Clicks: #{track_button_clicks?}"
      Rails.logger.info "   📊 Metadata: #{track_metadata?}"
    end
  end
end
