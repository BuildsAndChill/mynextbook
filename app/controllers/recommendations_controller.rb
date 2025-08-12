class RecommendationsController < ApplicationController
  def new
    # Affiche simplement le formulaire de saisie du contexte
  end

  def create
    user_context = params[:context].to_s

    result = BookRecommender.new(context: user_context).call

    @ai_raw        = result[:raw]
    @recommendations = result[:items]
    @ai_error      = result[:error]
    @user_prompt   = result[:prompt_debug] # 🔥 Le vrai prompt envoyé à l’IA

    render :create, status: :ok
    end

  def feedback
    flash[:notice] = params[:liked] == "true" ? "Bonne lecture !" : "On cherchera un autre livre."
    redirect_to new_recommendation_path
  end
end
