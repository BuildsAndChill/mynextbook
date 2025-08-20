# app/services/email_capture_service.rb
# Service responsable de capturer les emails des utilisateurs
# avec le contexte de leurs recommandations pour des emails pertinents
class EmailCaptureService
  def initialize
    @interaction_thresholds = {
      first_recommendation: 1,
      first_refinement: 2,
      subsequent_refinements: 3
    }
  end

  # Capture un email avec le contexte de la recommandation et envoie les recommandations
  def capture_email(email, context_data, session_id, recommendations_data = nil)
    return { success: false, error: 'Email invalide' } unless valid_email?(email)
    
    begin
      # Utiliser le modèle amélioré pour trouver ou créer le subscriber
      subscriber = Subscriber.find_or_create_by_email(email, context_data.merge(session_id: session_id))
      
      # Envoyer les recommandations par email si elles sont fournies
      if recommendations_data.present?
        send_recommendations_email(subscriber, recommendations_data, context_data[:context])
        Rails.logger.info "Email de recommandations envoyé à: #{email}"
      end
      
      Rails.logger.info "Email capturé avec succès: #{email} (interactions: #{subscriber.interaction_count})"
      { success: true, subscriber: subscriber, action: subscriber.created_at == subscriber.updated_at ? 'created' : 'updated' }
    rescue => e
      Rails.logger.error "Erreur lors de la capture d'email: #{e.message}"
      { success: false, error: 'Erreur technique' }
    end
  end

  # Détermine quand et comment afficher les CTA email
  def should_show_email_cta(session_data, interaction_count)
    case interaction_count
    when @interaction_thresholds[:first_recommendation]
      { show: true, type: 'soft', message: '📧 Envoyer ces recommandations sur ton email ?' }
    when @interaction_thresholds[:first_refinement]
      { show: true, type: 'gentle', message: '📚 Garder cette liste de livres pour plus tard ?' }
    when @interaction_thresholds[:subsequent_refinements]..Float::INFINITY
      { show: true, type: 'friendly', message: '💌 Recevoir tes résultats par email pour les consulter plus tard ?' }
    else
      { show: false, type: nil, message: nil }
    end
  end

  # Récupère les statistiques d'engagement email
  def engagement_stats
    total_subscribers = Subscriber.count
    active_subscribers = Subscriber.where('created_at > ?', 30.days.ago).count
    avg_interactions = Subscriber.average(:interaction_count)&.round(1) || 0
    
    {
      total: total_subscribers,
      active_30_days: active_subscribers,
      avg_interactions: avg_interactions
    }
  end

  private

  def valid_email?(email)
    email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
  end

  # Envoie les recommandations par email
  def send_recommendations_email(subscriber, recommendations_data, context)
    begin
      RecommendationsMailer.send_recommendations(subscriber, recommendations_data, context).deliver_now
      Rails.logger.info "Email de recommandations envoyé avec succès à #{subscriber.email}"
    rescue => e
      Rails.logger.error "Erreur lors de l'envoi de l'email à #{subscriber.email}: #{e.message}"
      # Ne pas faire échouer la capture d'email si l'envoi échoue
    end
  end

end
