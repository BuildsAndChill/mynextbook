# app/controllers/subscribers_controller.rb
# Contrôleur pour capturer les emails des utilisateurs
# sans bloquer leur expérience de recommandations
class SubscribersController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]
  
  def create
    email = params[:email]&.strip
    session_id = params[:session_id] || session.id.to_s
    
    # Récupérer le contexte de la session actuelle
    context_data = extract_context_from_session(session_id)
    
    # Capturer l'email avec le service
    result = EmailCaptureService.new.capture_email(email, context_data, session_id)
    
    if result[:success]
      # Marquer l'email comme capturé dans cette session
      session[:email_captured] = true
      
      # Log email capture for analytics
      Rails.logger.info "EMAIL_CAPTURED: email: #{result[:subscriber].email} | context: #{result[:subscriber].context} | tone_chips: #{result[:subscriber].tone_chips} | interaction_count: #{result[:subscriber].interaction_count} | session_id: #{session_id}"
      
      # Succès - retourner une réponse positive
      render json: {
        success: true,
        message: 'Parfait ! Tu recevras tes prochaines découvertes par email.',
        subscriber: {
          email: result[:subscriber].email,
          interaction_count: result[:subscriber].interaction_count
        }
      }
    else
      # Erreur - retourner le message d'erreur
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  private

  def extract_context_from_session(session_id)
    # Essayer de récupérer les données de la session actuelle
    context_data = {}
    
    # Vérifier les sessions de recommandations
    if session[:recommendation_session_id]
      stored_data = TemporaryRecommendationStorage.retrieve(session[:recommendation_session_id])
      if stored_data
        context_data[:context] = stored_data[:context]
        context_data[:tone_chips] = stored_data[:tone_chips]
        context_data[:ai_response] = stored_data[:ai_response]
        context_data[:parsed_response] = stored_data[:parsed_response]
      end
    end
    
    # Vérifier les sessions de refinement
    if session[:refined_session_id]
      stored_data = TemporaryRecommendationStorage.retrieve(session[:refined_session_id])
      if stored_data
        context_data[:context] ||= stored_data[:context]
        context_data[:tone_chips] ||= stored_data[:tone_chips]
        context_data[:ai_response] ||= stored_data[:ai_response]
        context_data[:parsed_response] ||= stored_data[:parsed_response]
      end
    end
    
    # Compter les interactions de la session
    context_data[:interaction_count] = count_session_interactions(session_id)
    
    context_data
  end

  def count_session_interactions(session_id)
    # Compter les interactions de cette session
    user_actions = session[:user_actions] || []
    session_actions = user_actions.select { |action| action[:session_id] == session_id }
    
    # Compter les recommandations et refinements
    recommendations = session_actions.count { |action| action[:action] == 'recommendation_created' }
    refinements = session_actions.count { |action| action[:action] == 'recommendation_refined' }
    
    recommendations + refinements
  end
end
