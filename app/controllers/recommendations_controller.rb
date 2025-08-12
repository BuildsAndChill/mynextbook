class RecommendationsController < ApplicationController
  def new
    # Form simple
  end

  def create
    user_context      = params[:context].to_s
    include_readings  = params[:include_goodreads] == "1"

    result = BookRecommender.new(
      context: user_context,
      include_readings: include_readings
    ).call


    @ai_raw          = result[:raw]
    @recommendations = result[:items]
    @ai_error        = result[:error]
    @user_prompt     = result[:prompt_debug]  # 🔥 prompt final envoyé
    @context         = user_context           # pour “sticky” sur le form si besoin
    @include_readings= include_readings

    render :create, status: :ok
  end

  def feedback
    flash[:notice] = params[:liked] == "true" ? "Bonne lecture !" : "On cherchera un autre livre."
    redirect_to new_recommendation_path
  end
end
