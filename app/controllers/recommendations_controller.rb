class RecommendationsController < ApplicationController
  before_action :authenticate_user!
  
  def new
  end

  def create
    # Build the prompt for AI
    context = params[:context]
    include_goodreads = params[:include_goodreads] == '1'
    
    # Create user prompt
    @user_prompt = build_user_prompt(context, include_goodreads)
    
    # Get AI recommendation
    begin
      recommender = BookRecommender.new
      @ai_raw = recommender.get_recommendation(@user_prompt)
      @ai_error = nil
    rescue => e
      @ai_raw = nil
      @ai_error = e.message
    end
    
    render :create
  end

  private

  def build_user_prompt(context, include_goodreads)
    prompt = "I'm looking for book recommendations. "
    prompt += "Context: #{context} "
    
    if include_goodreads
      # Get user's reading history for context
      readings = Reading.all.limit(10)
      if readings.any?
        prompt += "Based on my reading history: "
        readings.each do |reading|
          prompt += "#{reading.title} by #{reading.author} (#{reading.my_rating || 'unrated'}/5), "
        end
      end
    end
    
    prompt += "Please suggest 3-5 books with brief explanations of why they would be good for me."
    prompt
  end
end
