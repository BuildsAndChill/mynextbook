class RecommendationsController < ApplicationController
  before_action :authenticate_user!
  
  def new
    # Show the unified recommendation screen
  end

  def create
    # Build the prompt for AI with better structure
    context = params[:context]
    tone_chips = params[:tone_chips] || []
    include_history = params[:include_history] == '1'
    
    Rails.logger.info "Recommendations#create called with: context=#{context.inspect}, tone_chips=#{tone_chips.inspect}, include_history=#{include_history.inspect}"
    Rails.logger.info "Context present? #{context.present?}"
    Rails.logger.info "Context length: #{context&.length || 0}"
    
    # Create structured user prompt
    @user_prompt = build_structured_prompt(context, tone_chips, include_history)
    Rails.logger.info "Generated prompt: #{@user_prompt}"
    Rails.logger.info "Prompt length: #{@user_prompt.length}"
    
    # Check environment variables
    Rails.logger.info "OPENAI_API_KEY present? #{ENV['OPENAI_API_KEY'].present?}"
    Rails.logger.info "OPENAI_API_KEY length: #{ENV['OPENAI_API_KEY']&.length || 0}"
    
    # Get AI recommendation
    begin
      Rails.logger.info "Initializing BookRecommender..."
      recommender = BookRecommender.new
      Rails.logger.info "BookRecommender initialized successfully"
      Rails.logger.info "Calling get_recommendation with prompt..."
      @ai_response = recommender.get_recommendation(@user_prompt)
      Rails.logger.info "AI response received successfully"
      Rails.logger.info "AI response length: #{@ai_response&.length || 0}"
      Rails.logger.info "AI response preview: #{@ai_response&.first(200)}..."
      @ai_error = nil
      
      # Parse AI response into structured format (if possible)
      @parsed_response = parse_ai_response(@ai_response)
      Rails.logger.info "Parsed response: #{@parsed_response}"
      
    rescue => e
      Rails.logger.error "Error in recommendations#create: #{e.message}"
      Rails.logger.error "Error class: #{e.class}"
      Rails.logger.error e.backtrace.join("\n")
      @ai_response = nil
      @ai_error = e.message
      @parsed_response = nil
    end
    
    # Render the same page with results (unified experience)
    render :new
  end

  def feedback
    # Handle user feedback on recommendations
    book_id = params[:book_id]
    feedback_type = params[:feedback_type] # like, dislike, save
    refinement = params[:refinement]
    
    # Store feedback for future improvements
    # TODO: Implement feedback storage
    
    # If refinement provided, get new recommendations
    if refinement.present?
      # Trigger refinement flow
      redirect_to new_recommendation_path(refinement: refinement)
    else
      redirect_to new_recommendation_path, notice: "Feedback recorded! We'll use this to improve future recommendations."
    end
  end

  private

  def build_structured_prompt(context, tone_chips, include_history)
    prompt = "You are a knowledgeable book recommendation expert. Please provide book recommendations in the EXACT format specified below.\n\n"
    
    # Add context
    if context.present?
      prompt += "USER CONTEXT: #{context}\n\n"
    end
    
    # Add tone preferences
    if tone_chips.any?
      prompt += "TONE PREFERENCES: #{tone_chips.join(', ')}\n\n"
    end
    
    # Add reading history if requested
    if include_history
      readings = current_user.readings.limit(15)
      if readings.any?
        prompt += "READING HISTORY (last 15 books):\n"
        readings.each do |reading|
          rating = reading.my_rating || 'unrated'
          prompt += "- #{reading.title} by #{reading.author} (#{rating}/5 stars)\n"
        end
        prompt += "\n"
      end
    end
    
    # Structured output request with strict formatting
    prompt += "RESPONSE FORMAT - Please follow EXACTLY:\n\n"
    prompt += "BRIEF:\n"
    prompt += "What you tend to like:\n"
    prompt += "- [First preference point]\n"
    prompt += "- [Second preference point]\n"
    prompt += "- [Third preference point]\n\n"
    
    prompt += "What to explore next:\n"
    prompt += "- [First exploration suggestion]\n"
    prompt += "- [Second exploration suggestion]\n"
    prompt += "- [Third exploration suggestion]\n\n"
    
    prompt += "Pitfalls to avoid:\n"
    prompt += "- [First pitfall to avoid]\n"
    prompt += "- [Second pitfall to avoid]\n\n"
    
    prompt += "TOP PICKS:\n"
    prompt += "1. [EXACT BOOK TITLE] by [EXACT AUTHOR NAME]\n"
    prompt += "Pitch: [2-line explanation of why this book fits]\n"
    prompt += "Why: [Specific reason tied to reading history or context]\n"
    prompt += "Confidence: [High/Medium/Low]\n\n"
    
    prompt += "2. [EXACT BOOK TITLE] by [EXACT AUTHOR NAME]\n"
    prompt += "Pitch: [2-line explanation of why this book fits]\n"
    prompt += "Why: [Specific reason tied to reading history or context]\n"
    prompt += "Confidence: [High/Medium/Low]\n\n"
    
    prompt += "3. [EXACT BOOK TITLE] by [EXACT AUTHOR NAME]\n"
    prompt += "Pitch: [2-line explanation of why this book fits]\n"
    prompt += "Why: [Specific reason tied to reading history or context]\n"
    prompt += "Confidence: [High/Medium/Low]\n\n"
    
    prompt += "IMPORTANT: Follow this exact format. Use real book titles and authors. Make confidence assessments based on how well the book matches the user's stated preferences and reading history."
    
    prompt
  end

  def parse_ai_response(response)
    # Try to parse the AI response into structured format
    parsed = {
      brief: {},
      picks: []
    }
    
    # Split into sections
    if response.include?("BRIEF:")
      brief_section = response.split("TOP PICKS:").first
      picks_section = response.split("TOP PICKS:").last
      
      # Parse brief sections with better extraction
      parsed[:brief][:likes] = extract_bullet_points(brief_section, "What you tend to like:")
      parsed[:brief][:explore] = extract_bullet_points(brief_section, "What to explore next:")
      parsed[:brief][:avoid] = extract_bullet_points(brief_section, "Pitfalls to avoid:")
      
      # Parse picks with enhanced extraction
      parsed[:picks] = extract_book_picks_enhanced(picks_section)
    end
    
    parsed
  end

  def extract_bullet_points(text, section_name)
    # Extract bullet points from a section
    section_start = text.index(section_name)
    return [] unless section_start
    
    section_text = text[section_start..-1]
    next_section = section_text.index(/What to explore next:|Pitfalls to avoid:|TOP PICKS:/)
    section_text = next_section ? section_text[0...next_section] : section_text
    
    # Find bullet points with better regex
    bullets = section_text.scan(/- (.+?)(?=\n-|\n\n|$)/m).flatten
    bullets.map(&:strip).reject(&:blank?).first(5) # Limit to 5 points
  end

  def extract_book_picks_enhanced(text)
    # Enhanced extraction of book picks
    picks = []
    
    # Find numbered book entries with better pattern matching
    book_entries = text.scan(/(\d+)\.\s*(.+?)\s*by\s*(.+?)(?=\n\d+\.|$)/m)
    
    book_entries.each do |match|
      number, title, author = match
      
      # Extract additional information if available
      pitch = extract_field(text, number, "Pitch:")
      why = extract_field(text, number, "Why:")
      confidence = extract_field(text, number, "Confidence:")
      
      picks << {
        number: number.to_i,
        title: title.strip,
        author: author.strip,
        pitch: pitch.presence || "AI-generated pitch",
        why: why.presence || "Based on your preferences",
        confidence: confidence.presence || "Medium"
      }
    end
    
    picks.first(3) # Ensure we only get 3 picks
  end

  def extract_field(text, book_number, field_name)
    # Extract specific field for a book
    pattern = /#{book_number}\.\s*.+?by\s*.+?\n#{field_name}\s*(.+?)(?=\n\w+:|$)/m
    match = text.match(pattern)
    match ? match[1].strip : nil
  end
end
