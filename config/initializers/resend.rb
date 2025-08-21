# Resend configuration for ActionMailer
require 'resend'

# Configure Resend API key globally
if ENV['RESEND_API_KEY'].present?
  Resend.api_key = ENV['RESEND_API_KEY']
  Rails.logger.info "✅ Clé API Resend configurée globalement"
else
  Rails.logger.warn "⚠️ RESEND_API_KEY non définie"
end

# Custom delivery method for Resend
class ResendDeliveryMethod
  def initialize(settings)
    Rails.logger.info "🔧 ResendDeliveryMethod initialisé avec settings: #{settings.inspect}"
    
    # Récupérer les settings depuis la configuration ActionMailer si pas dans settings
    @api_key = settings[:api_key] || ActionMailer::Base.resend_settings[:api_key]
    @domain = settings[:domain] || ActionMailer::Base.resend_settings[:domain]
    
    # Fallback vers les variables d'environnement si toujours pas défini
    @api_key ||= ENV['RESEND_API_KEY']
    @domain ||= ENV['RESEND_DOMAIN']
    
    Rails.logger.info "🔧 ResendDeliveryMethod - @api_key: #{@api_key ? '✅ Définie' : '❌ Non définie'}"
    Rails.logger.info "🔧 ResendDeliveryMethod - @domain: #{@domain.inspect}"
    Rails.logger.info "🔧 ActionMailer::Base.resend_settings: #{ActionMailer::Base.resend_settings.inspect}"
  end

  def deliver!(mail)
    # Debug complet des paramètres
    Rails.logger.info "🔍 ResendDeliveryMethod - Domain: #{@domain.inspect}"
    Rails.logger.info "🔍 ResendDeliveryMethod - API Key: #{@api_key ? '✅ Définie' : '❌ Non définie'}"
    Rails.logger.info "🔍 ResendDeliveryMethod - Settings reçus: #{@api_key.inspect}, #{@domain.inspect}"
    
    # Vérifier que le domaine est défini
    if @domain.blank?
      Rails.logger.error "❌ Domaine Resend non défini dans les settings"
      Rails.logger.error "🔍 Debug complet des settings:"
      Rails.logger.error "  - @api_key: #{@api_key.inspect}"
      Rails.logger.error "  - @domain: #{@domain.inspect}"
      Rails.logger.error "  - ActionMailer::Base.resend_settings: #{ActionMailer::Base.resend_settings.inspect}"
      Rails.logger.error "  - ENV['RESEND_DOMAIN']: #{ENV['RESEND_DOMAIN'].inspect}"
      Rails.logger.error "  - ENV['RESEND_API_KEY']: #{ENV['RESEND_API_KEY'] ? '✅ Définie' : '❌ Non définie'}"
      raise "Domaine Resend non configuré - Vérifiez les logs pour le debug complet"
    end
    
    # Prepare message parameters
    message_params = {
      from: "noreply@#{@domain}",
      to: mail.to,
      subject: mail.subject,
      html: mail.html_part&.body&.to_s || mail.body.to_s,
      text: mail.text_part&.body&.to_s || mail.body.to_s
    }
    
    # Add CC if present
    message_params[:cc] = mail.cc if mail.cc.present?
    
    # Add BCC if present
    message_params[:bcc] = mail.bcc if mail.bcc.present?
    
    # Add reply_to if present
    message_params[:reply_to] = mail.reply_to.first if mail.reply_to.present?
    
    # Send message via Resend
    begin
      Rails.logger.info "🚀 Tentative d'envoi via Resend avec params: #{message_params.inspect}"
      result = Resend::Emails.send(message_params)
      Rails.logger.info "✅ Email envoyé via Resend: #{result['id']}"
      result
    rescue => e
      Rails.logger.error "❌ Erreur Resend: #{e.message}"
      Rails.logger.error "❌ Détails de l'erreur: #{e.class} - #{e.backtrace.first(3).join("\n")}"
      raise e
    end
  end
end

# Register the custom delivery method
Rails.logger.info "🔧 Enregistrement de la méthode de livraison Resend..."
ActionMailer::Base.add_delivery_method :resend, ResendDeliveryMethod
Rails.logger.info "✅ Méthode de livraison Resend enregistrée avec succès"
Rails.logger.info "🔧 Méthodes disponibles: #{ActionMailer::Base.delivery_methods.inspect}"
