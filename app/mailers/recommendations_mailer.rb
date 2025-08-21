# app/mailers/recommendations_mailer.rb
# Mailer responsable de l'envoi des recommandations de livres par email
class RecommendationsMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_SENDER', 'recommendations@mynextbook.com')

  # Envoie les recommandations personnalisées à un utilisateur
  def send_recommendations(subscriber, recommendations_data, context = nil)
    @subscriber = subscriber
    @recommendations = recommendations_data
    @context = context
    
    # Gérer les clés string ET symbols pour la compatibilité
    @books = @recommendations&.dig(:picks) || @recommendations&.dig('picks') || []
    @explanation = @recommendations&.dig(:explanation) || @recommendations&.dig('explanation') || "Voici tes recommandations personnalisées !"
    
    # Métadonnées pour l'email
    @sent_at = Time.current
    @unsubscribe_token = generate_unsubscribe_token(@subscriber)
    
    Rails.logger.info "Envoi des recommandations par email à #{@subscriber.email} (#{@books.count} livres)"
    
    # Debug des paramètres avant envoi
    Rails.logger.info "🔍 DEBUG RecommendationsMailer - Paramètres:"
    Rails.logger.info "  - to: #{@subscriber.email}"
    Rails.logger.info "  - subject: #{build_email_subject(@context, @books.count)}"
    Rails.logger.info "  - from: #{ENV.fetch('MAILER_SENDER', 'recommendations@mynextbook.com')}"
    Rails.logger.info "  - delivery_method: #{ActionMailer::Base.delivery_method}"
    Rails.logger.info "  - resend_settings: #{ActionMailer::Base.resend_settings.inspect}"
    Rails.logger.info "  - ENV['RESEND_DOMAIN']: #{ENV['RESEND_DOMAIN'].inspect}"
    
    mail(
      to: @subscriber.email,
      subject: build_email_subject(@context, @books.count)
    )
  end

  private

  # Génère un sujet personnalisé selon le contexte
  def build_email_subject(context, books_count)
    if context.present? && context.length > 10
      "📚 Tes #{books_count} recommandations pour \"#{context.truncate(30)}\""
    else
      "📚 Tes #{books_count} recommandations de livres personnalisées"
    end
  end

  # Génère un token sécurisé pour le désabonnement
  def generate_unsubscribe_token(subscriber)
    # Simple token basé sur l'ID et l'email (peut être amélioré avec JWT)
    Digest::SHA256.hexdigest("#{subscriber.id}-#{subscriber.email}-#{Rails.application.secret_key_base}")[0..16]
  end
end
