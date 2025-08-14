class RecommendationsController < ApplicationController
  # Remove authentication requirement - allow unlogged users to get basic recommendations
  
  def index
    # Device detection and smart routing
    user_agent = request.user_agent.downcase
    is_mobile = user_agent.include?('mobile') || user_agent.include?('android') || user_agent.include?('iphone') || user_agent.include?('ipad')
    
    # Check if it's a mobile device
    if is_mobile
      Rails.logger.info "Mobile device detected, redirecting to chat interface"
      redirect_to chat_recommendations_path
    else
      Rails.logger.info "Desktop/Tablet detected, redirecting to normal form"
      # Redirect desktop/tablet users to the normal form
      redirect_to new_recommendation_path
    end
  end
  
  def new
    # Show the unified recommendation screen
    # Check if user just signed up and has stored results
    if user_signed_in? && session[:recommendation_session_id]
      # Retrieve AI data from file storage
      stored_data = TemporaryRecommendationStorage.retrieve(session[:recommendation_session_id])
      
      if stored_data
        @ai_response = stored_data[:ai_response]
        @parsed_response = stored_data[:parsed_response]
        @user_prompt = stored_data[:user_prompt]
        @show_welcome_message = true
        
        # Clean up the file after retrieving
        TemporaryRecommendationStorage.delete(session[:recommendation_session_id])
        session.delete(:recommendation_session_id)
        
        Rails.logger.info "AI recommendation data retrieved from file storage"
      end
    end
    
    # Check for refined results from refine action
    Rails.logger.info "Checking for refined results: params[:refined] = #{params[:refined].inspect}"
    Rails.logger.info "Session refined_session_id: #{session[:refined_session_id].inspect}"
    
    if params[:refined] == 'true'
      # For all users, retrieve refined results from file storage
      if session[:refined_session_id]
        Rails.logger.info "Attempting to retrieve data for session ID: #{session[:refined_session_id]}"
        stored_data = TemporaryRecommendationStorage.retrieve(session[:refined_session_id])
        
        if stored_data
          @ai_response = stored_data[:ai_response]
          @parsed_response = stored_data[:parsed_response]
          @user_prompt = stored_data[:user_prompt]
          
          Rails.logger.info "Data retrieved successfully: ai_response=#{@ai_response.present?}, parsed_response=#{@parsed_response.present?}, user_prompt=#{@user_prompt.present?}"
          
          # Clean up file but KEEP session ID for view to use
          TemporaryRecommendationStorage.delete(session[:refined_session_id])
          # DO NOT delete session[:refined_session_id] here - view needs it!
          
          Rails.logger.info "Refined AI recommendation data retrieved from file storage"
        else
          Rails.logger.warn "No refined results found in file storage despite session ID"
        end
      else
        Rails.logger.warn "No refined session ID found despite refined=true parameter"
      end
    else
      Rails.logger.info "No refined parameter or session ID found"
    end
    
    # Check for signup prompt from other pages
    @signup_prompt = params[:signup_prompt]
    
    # Initialize conversation context if not present
    session[:conversation_history] ||= []
    session[:current_context] ||= nil
    session[:current_suggestions] ||= []
  end

  def create
    # Build the prompt for AI with better structure
    context = params[:context]
    tone_chips = params[:tone_chips] || []
    include_history = params[:include_history] == '1'
    refinement = params[:refinement]
    
    # Clear previous session feedback for new recommendation context
    session.delete(:current_feedback) if context.present? && context != session[:last_context]
    session[:last_context] = context
    
    Rails.logger.info "Recommendations#create called with: context=#{context.inspect}, tone_chips=#{tone_chips.inspect}, include_history=#{include_history.inspect}, refinement=#{refinement.inspect}"
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
      
      # Store results for unlogged users using file-based storage instead of session
      if !user_signed_in?
        # Store AI data in temporary files using the service
        session_id = TemporaryRecommendationStorage.store(
          @ai_response,
          @parsed_response,
          @user_prompt,
          context,
          tone_chips
        )
        
        # Store only the session ID in the session cookie (very small)
        session[:recommendation_session_id] = session_id
        
        Rails.logger.info "AI data stored using file storage. Session ID: #{session_id}"
      end
      
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
    book_title = params[:book_title]
    book_author = params[:book_author]
    feedback_type = params[:feedback_type] # like, dislike, save, more_info
    refinement = params[:refinement]
    
    # Store feedback in session for current recommendation context (no database for refinements)
    session[:current_feedback] ||= []
    session[:current_feedback] << {
      type: feedback_type,
      book_title: book_title,
      book_author: book_author,
      timestamp: Time.current
    }
    
    if user_signed_in? && book_title.present? && book_author.present?
      # Store feedback for future improvements (only for user preferences, not refinements)
      feedback = current_user.user_book_feedbacks.create!(
        book_title: book_title,
        book_author: book_author,
        feedback_type: feedback_type,
        recommendation_context: params[:context] || "General recommendation"
      )
      
      # Handle specific feedback types
      case feedback_type
      when 'save'
        # Save book to user's reading list
        UserReading.save_from_recommendation(current_user, book_title, book_author)
        flash[:notice] = "Book saved to your reading list!"
      when 'like'
        flash[:notice] = "Thanks! We'll recommend more like this."
      when 'dislike'
        flash[:notice] = "Got it! We'll avoid similar books."
      when 'more_info'
        flash[:notice] = "Book details expanded!"
      end
      
      Rails.logger.info "Feedback stored: #{feedback.inspect}"
    else
      # For unlogged users, show signup prompt
      if !user_signed_in?
        # Return JSON response to trigger signup modal
        render json: { 
          action: 'show_signup',
          message: 'Sign up to save your feedback and get better recommendations!',
          book_title: book_title,
          book_author: book_author,
          feedback_type: feedback_type
        }
        return
      end
    end
    
    # If refinement provided, get new recommendations
    if refinement.present?
      # Trigger refinement flow
      redirect_to new_recommendation_path(refinement: refinement)
    else
      redirect_to new_recommendation_path, notice: flash[:notice] || "Feedback recorded! We'll use this to improve future recommendations."
    end
  end

  def refine
    # Handle refinement requests with context conservation and immediate feedback
    refinement_text = params[:refinement_text]
    context = params[:context]
    

    
    # Build refined prompt with context conservation
    @user_prompt = build_refined_prompt(context, refinement_text)
    
    # Get new AI recommendation
    begin
      Rails.logger.info "Refining recommendation with: #{refinement_text}"
      recommender = BookRecommender.new
      @ai_response = recommender.get_recommendation(@user_prompt)
      @ai_error = nil
      
      # Parse AI response into structured format
      @parsed_response = parse_ai_response(@ai_response)
      Rails.logger.info "Refined recommendation generated successfully"
      
      # Store results for all users using file storage (avoid cookie overflow)
      session_id = TemporaryRecommendationStorage.store(
        @ai_response,
        @parsed_response,
        @user_prompt,
        context,
        [] # No tone chips for refinement
      )
      
      # Store only the session ID in session (very small)
      session[:refined_session_id] = session_id
      
          # Show success message
    flash[:notice] = "Recommendations refined! Here are new suggestions based on: '#{refinement_text}'"
    
    # For signed-in users, return JSON with new data (no redirect)
    if user_signed_in?
      render json: {
        success: true,
        message: "Recommendations refined!",
        data: {
          ai_response: @ai_response,
          parsed_response: @parsed_response,
          user_prompt: @user_prompt,
          session_id: session_id
        }
      }
      return
    end
    
  rescue => e
    Rails.logger.error "Error in recommendations#refine: #{e.message}"
    @ai_response = nil
    @ai_error = e.message
    @parsed_response = nil
    
    if user_signed_in?
      render json: {
        success: false,
        error: "Sorry, couldn't refine recommendations. Please try again."
      }
    else
      flash[:error] = "Sorry, couldn't refine recommendations. Please try again."
      redirect_to new_recommendation_path
    end
    return
  end
  
  # Only redirect for unlogged users
  redirect_to new_recommendation_path(refined: true), allow_other_host: false
  end

  def cleanup_refined_session
    # Clean up refined session after view has been rendered
    if session[:refined_session_id]
      Rails.logger.info "Cleaning up refined session: #{session[:refined_session_id]}"
      session.delete(:refined_session_id)
      render json: { success: true, message: "Session cleaned up" }
    else
      render json: { success: false, message: "No session to clean up" }
    end
  end

  def chat
    # Use chat layout without navigation bar
    render layout: 'chat'
  end
  
  def chat_message
    # Handle chat messages and return AI recommendations
    begin
      # Parse JSON request
      request_data = JSON.parse(request.body.read)
      context = request_data['context']
      tone_chips = request_data['tone_chips'] || []
      include_history = request_data['include_history'] || false
      user_feedback = request_data['user_feedback'] || {}
      
      Rails.logger.info "Chat message received: context=#{context.inspect}, tones=#{tone_chips.inspect}, history=#{include_history}"
      
      # Always use refined prompt since everything is refinement
      if session[:current_context]
        # Refinement of previous context
        user_prompt = build_refined_prompt(session[:current_context], context)
        Rails.logger.info "Using REFINED prompt: #{context}"
      else
        # First interaction: create initial context and use structured prompt
        user_prompt = build_structured_prompt(context, tone_chips, include_history)
        Rails.logger.info "Using INITIAL prompt: #{context}"
      end
      
      Rails.logger.info "Built prompt length: #{user_prompt&.length || 0}"
      Rails.logger.info "Prompt preview: #{user_prompt&.first(200)}..."
      
      # Get AI recommendation
      recommender = BookRecommender.new
      ai_response = recommender.get_recommendation(user_prompt)
      
      # Parse AI response
      parsed_response = parse_ai_response(ai_response)
      
      # Store only essential data in session (avoid cookie overflow)
      session[:current_context] = context
      
      # Store AI response in temporary storage instead of session
      if ai_response
        session_id = TemporaryRecommendationStorage.store(
          ai_response,
          parsed_response,
          user_prompt,
          context,
          tone_chips
        )
        session[:current_session_id] = session_id
      end
      
      # Prepare response data
      response_data = {
        success: true,
        message: "Voici mes suggestions basées sur ta demande :",
        suggestions: parsed_response&.dig(:picks) || [],
        ai_response: ai_response,
        parsed_response: parsed_response
      }
      
      render json: response_data
      
    rescue => e
      Rails.logger.error "Error in chat_message: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: {
        success: false,
        error: "Désolé, une erreur s'est produite. Veuillez réessayer.",
        details: e.message
      }, status: :internal_server_error
    end
  end



  private



  def build_refined_prompt(original_context, refinement_text)
    # Build a refined prompt that conserves context and adds refinement
    prompt = "You are a knowledgeable book recommendation expert. The user wants to REFINE their previous request.\n\n"
    prompt += "⚠️  CRITICAL: You are being asked to REFINE, not repeat. You MUST provide NEW, DIFFERENT book recommendations.\n\n"
    
    # Original context
    if original_context.present?
      prompt += "ORIGINAL REQUEST: #{original_context}\n\n"
    end
    
    # New refinement
    prompt += "REFINEMENT REQUEST: #{refinement_text}\n\n"
    
    # Add current session feedback if available (no database storage)
    if session[:current_feedback]&.any?
      prompt += "CURRENT SESSION FEEDBACK:\n"
      session[:current_feedback].each do |feedback|
        prompt += "- #{feedback[:type]}: #{feedback[:book_title]} by #{feedback[:book_author]}\n"
      end
      prompt += "\n"
    end
    
    # Add reading history if user is signed in
    if user_signed_in?
      books = current_user.user_readings.includes(:book_metadata).limit(15)
      if books.any?
        prompt += "READING HISTORY (last 15 books):\n"
        books.each do |book|
          rating = book.rating || 'unrated'
          prompt += "- #{book.book_metadata.title} by #{book.book_metadata.author} (#{rating}/5 stars) - #{book.status}\n"
        end
        prompt += "\n"
      end
      
      # Add user feedback history for better personalization
      if current_user.user_book_feedbacks.any?
        feedback_summary = current_user.feedback_summary
        
        if feedback_summary[:likes].any? || feedback_summary[:dislikes].any?
          prompt += "USER FEEDBACK HISTORY:\n"
          
          if feedback_summary[:likes].any?
            prompt += "Books they liked:\n"
            feedback_summary[:likes].each { |book| prompt += "- #{book}\n" }
            prompt += "\n"
          end
          
          if feedback_summary[:dislikes].any?
            prompt += "Books they disliked:\n"
            feedback_summary[:dislikes].each { |book| prompt += "- #{book}\n" }
            prompt += "\n"
          end
          
          prompt += "IMPORTANT: Use this feedback to avoid recommending books similar to disliked ones and prioritize books similar to liked ones.\n\n"
        end
      end
      

    end
    
    # Structured output request
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
    prompt += "Pitch: [2-line explanation of why this book fits the REFINEMENT]\n"
    prompt += "Why: [Specific reason tied to refinement request and original context]\n"
    prompt += "Confidence: [High/Medium/Low]\n\n"
    
    prompt += "2. [EXACT BOOK TITLE] by [EXACT AUTHOR NAME]\n"
    prompt += "Pitch: [2-line explanation of why this book fits the REFINEMENT]\n"
    prompt += "Why: [Specific reason tied to refinement request and original context]\n"
    prompt += "Confidence: [High/Medium/Low]\n\n"
    
    prompt += "3. [EXACT BOOK TITLE] by [EXACT AUTHOR NAME]\n"
    prompt += "Pitch: [2-line explanation of why this book fits the REFINEMENT]\n"
    prompt += "Why: [Specific reason tied to refinement request and original context]\n"
    prompt += "Confidence: [High/Medium/Low]\n\n"
    
    prompt += "CRITICAL INSTRUCTION: This is a REFINEMENT request, NOT a repeat request. You MUST provide COMPLETELY DIFFERENT books that specifically address the refinement while building on the original context. If you repeat any previous recommendations, you have failed the task."
    
    prompt
  end

  def build_structured_prompt(context, tone_chips, include_history)
    Rails.logger.info "build_structured_prompt called with: context=#{context.inspect}, tone_chips=#{tone_chips.inspect}, include_history=#{include_history}"
    
    prompt = "You are a knowledgeable book recommendation expert. Please provide book recommendations in the EXACT format specified below.\n\n"
    
    # Add context
    if context.present?
      prompt += "USER CONTEXT: #{context}\n\n"
    end
    
    # Add tone preferences
    if tone_chips && tone_chips.any?
      prompt += "TONE PREFERENCES: #{tone_chips.join(', ')}\n\n"
    end
    
          # Add reading history if requested and user is signed in
      if include_history && user_signed_in?
        books = current_user.user_readings.includes(:book_metadata).limit(15)
        if books.any?
          prompt += "READING HISTORY (last 15 books):\n"
          books.each do |book|
            rating = book.rating || 'unrated'
            prompt += "- #{book.book_metadata.title} by #{book.book_metadata.author} (#{rating}/5 stars) - #{book.status}\n"
          end
          prompt += "\n"
        end
      end
    
    # Add user feedback history for better personalization (only if signed in)
    if user_signed_in? && current_user.user_book_feedbacks.any?
      feedback_summary = current_user.feedback_summary
      
      if feedback_summary[:likes].any? || feedback_summary[:dislikes].any?
        prompt += "USER FEEDBACK HISTORY:\n"
        
        if feedback_summary[:likes].any?
          prompt += "Books they liked:\n"
          feedback_summary[:likes].each { |book| prompt += "- #{book}\n" }
          prompt += "\n"
        end
        
        if feedback_summary[:dislikes].any?
          prompt += "Books they disliked:\n"
          feedback_summary[:dislikes].each { |book| prompt += "- #{book}\n" }
          prompt += "\n"
        end
        
        if feedback_summary[:saved].any?
          prompt += "Books they saved:\n"
          feedback_summary[:saved].each { |book| prompt += "- #{book}\n" }
          prompt += "\n"
        end
        
        prompt += "IMPORTANT: Use this feedback to avoid recommending books similar to disliked ones and prioritize books similar to liked ones.\n\n"
      end
    end
    
    # Add user refinement history ONLY for refinement requests, not for new requests
    # This ensures new requests are clean and independent
    # Refinement history is handled separately in build_refined_prompt
    
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
    
    Rails.logger.info "Final prompt length: #{prompt.length}"
    Rails.logger.info "Final prompt preview: #{prompt.first(200)}..."
    
    prompt
  end

  def parse_ai_response(response)
    # Try to parse the AI response into structured format
    return { brief: {}, picks: [] } unless response
    
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
    # Enhanced extraction of book picks with better logging
    picks = []
    
    return picks unless text
    
    Rails.logger.info "Extracting book picks from text: #{text.length} characters"
    
    # Find numbered book entries with better pattern matching
    book_entries = text.scan(/(\d+)\.\s*(.+?)\s*by\s*(.+?)(?=\n\d+\.|$)/m)
    
    Rails.logger.info "Found #{book_entries.length} book entries: #{book_entries.inspect}"
    
    book_entries.each do |match|
      number, title, author = match
      
      Rails.logger.info "Processing book #{number}: '#{title}' by '#{author}'"
      
      # Extract additional information if available
      pitch = extract_field(text, number, "Pitch:")
      why = extract_field(text, number, "Why:")
      confidence = extract_field(text, number, "Confidence:")
      
      Rails.logger.info "Extracted fields - Pitch: '#{pitch}', Why: '#{why}', Confidence: '#{confidence}'"
      
      picks << {
        number: number.to_i,
        title: title.strip,
        author: author.strip,
        pitch: pitch.presence || "AI-generated pitch",
        why: why.presence || "Based on your preferences",
        confidence: confidence.presence || "Medium"
      }
    end
    
    Rails.logger.info "Final picks: #{picks.inspect}"
    picks.first(3) # Ensure we only get 3 picks
  end

  def extract_field(text, book_number, field_name)
    # Extract specific field for a book with more flexible pattern
    # Look for the field after the book entry, handling various formats
    
    return nil unless text
    
    Rails.logger.info "Extracting field '#{field_name}' for book #{book_number}"
    
    # First, find the book entry
    book_pattern = /#{book_number}\.\s*(.+?)\s*by\s*(.+?)(?=\n|$)/m
    book_match = text.match(book_pattern)
    return nil unless book_match
    
    book_start = book_match.begin(0)
    book_end = book_match.end(0)
    
    Rails.logger.info "Book entry found at positions #{book_start}-#{book_end}"
    
    # Look for the field after the book entry
    remaining_text = text[book_end..-1]
    Rails.logger.info "Remaining text after book: #{remaining_text[0..100]}..."
    
    # Try different patterns for the field
    patterns = [
      /#{field_name}\s*(.+?)(?=\n\d+\.|$)/m,  # Field followed by next book or end
      /#{field_name}\s*(.+?)(?=\n[A-Z][a-z]+:|$)/m,  # Field followed by next section or end
      /#{field_name}\s*(.+?)(?=\n\n|$)/m  # Field followed by double newline or end
    ]
    
    patterns.each_with_index do |pattern, index|
      Rails.logger.info "Trying pattern #{index + 1}: #{pattern}"
      match = remaining_text.match(pattern)
      if match && match[1].strip.present?
        Rails.logger.info "Pattern #{index + 1} succeeded: '#{match[1].strip}'"
        return match[1].strip
      end
    end
    
    Rails.logger.warn "No field '#{field_name}' found for book #{book_number}"
    nil
  end
end
