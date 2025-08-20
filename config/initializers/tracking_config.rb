# config/initializers/tracking_config.rb
# Initializer pour la configuration du tracking utilisateur

Rails.application.config.after_initialize do
  # Logger la configuration du tracking au démarrage
  if defined?(TrackingConfigService)
    TrackingConfigService.log_startup_config
  else
    Rails.logger.warn "⚠️  TRACKING: TrackingConfigService non disponible"
  end
end
