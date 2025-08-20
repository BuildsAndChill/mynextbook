# app/mailers/recommendations_mailer.rb
# Mailer responsable de l'envoi des recommandations de livres par email
class RecommendationsMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_SENDER', 'recommendations@mynextbook.com')

  # Envoie les recommandations personnalisées à un utilisateur
  def send_recommendations(subscriber, recommendations_data, context = nil)
    @subscriber = subscriber
    @recommendations = recommendations_data
    @context = context
    @books = @recommendations&.dig(:picks) || []
    @explanation = @recommendations&.dig(:explanation) || "Voici tes recommandations personnalisées !"
    
    # Métadonnées pour l'email
    @sent_at = Time.current
    @unsubscribe_token = generate_unsubscribe_token(@subscriber)
    
    Rails.logger.info "Envoi des recommandations par email à #{@subscriber.email} (#{@books.count} livres)"
    
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
