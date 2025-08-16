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
      Rails.logger.info "Desktop/Tablet detected, showing initial form"
      # Clean up any existing session data (fresh start)
      cleanup_all_sessions
      # Show the initial form directly (no redirect)
    end
  end

  def create
    # Clean up any existing session data at the start to ensure clean state
    if session[:recommendation_session_id]
      Rails.logger.info "Cleaning up existing recommendation session data"
      TemporaryRecommendationStorage.delete(session[:recommendation_session_id])
      session.delete(:recommendation_session_id)
    end
    if session[:refined_session_id]
      Rails.logger.info "Cleaning up existing refined session data"
      TemporaryRecommendationStorage.delete(session[:refined_session_id])
      session.delete(:refined_session_id)
    end
    
    # Build the prompt for AI with better structure
    context = params[:context]
    # Ensure tone_chips is always an array
    tone_chips = if params[:tone_chips].is_a?(Array)
                   params[:tone_chips]
                 elsif params[:tone_chips].present?
                   [params[:tone_chips]]
                 else
                   []
                 end
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
      
      # Enrich recommendations with metadata (non-blocking)
      enrich_recommendations_with_metadata(@parsed_response)
      
      # Store results for all users using file-based storage instead of session
      # Store AI data in temporary files using the service
      Rails.logger.info "DEBUG: About to store data - @parsed_response present: #{@parsed_response.present?}"
      Rails.logger.info "DEBUG: @parsed_response keys: #{@parsed_response&.keys&.inspect}"
      Rails.logger.info "DEBUG: @parsed_response[:picks] count: #{@parsed_response&.dig(:picks)&.count || 0}"
      
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
      Rails.logger.info "DEBUG: Session ID stored in session: #{session[:recommendation_session_id]}"
      
    rescue => e
      Rails.logger.error "Error in recommendations#create: #{e.message}"
      Rails.logger.error "Error class: #{e.class}"
      Rails.logger.error e.backtrace.join("\n")
      @ai_response = nil
      @ai_error = e.message
      @parsed_response = nil
    end
    
    # Display results directly in show view
    render :show
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
      redirect_to recommendations_path(refinement: refinement)
    else
              redirect_to recommendations_path, notice: flash[:notice] || "Feedback recorded! We'll use this to improve future recommendations."
    end
  end

  def refine
    # Handle refinement requests with context conservation
    refinement_text = params[:refinement_text]
    context = params[:context]
    
    Rails.logger.info "Refining recommendation with: #{refinement_text}"
    
    # Build refined prompt with context conservation
    @user_prompt = build_refined_prompt(context, refinement_text)
    
    # Get new AI recommendation
    begin
      recommender = BookRecommender.new
      @ai_response = recommender.get_recommendation(@user_prompt)
      @ai_error = nil
      
      # Parse AI response into structured format
      @parsed_response = parse_ai_response(@ai_response)
      Rails.logger.info "Refined recommendation generated successfully"
      
      # Enrich recommendations with metadata (non-blocking)
      enrich_recommendations_with_metadata(@parsed_response)
      
      # Store results for all users using file storage (avoid cookie overflow)
      session_id = TemporaryRecommendationStorage.store(
        @ai_response,
        @parsed_response,
        @user_prompt,
        context,
        [] # No tone chips for refinement
      )
      
      # Store only the session ID in session (very small) - CRITICAL FOR DISPLAY
      session[:refined_session_id] = session_id
      Rails.logger.info "Stored refined_session_id: #{session_id}"
      
      # Show success message
      flash[:notice] = "Recommendations refined! Here are new suggestions based on: '#{refinement_text}'"
      
      # For signed-in users, we could return JSON, but let's redirect to new for consistency
      # This ensures the refined data is always displayed through the new action
      
    rescue => e
      Rails.logger.error "Error in recommendations#refine: #{e.message}"
      @ai_error = e.message
      @parsed_response = nil
      
      if user_signed_in?
        render json: {
          success: false,
          error: "Sorry, couldn't refine recommendations. Please try again."
        }
      else
        flash[:error] = "Sorry, couldn't refine recommendations. Please try again."
        redirect_to recommendations_path
      end
      return
    end
    
    # Display refined results directly in show view
    render :show
  end

  private

  def cleanup_all_sessions
    # Clean up all existing session data for fresh start
    if session[:recommendation_session_id]
      Rails.logger.info "Cleaning up existing recommendation session data"
      TemporaryRecommendationStorage.delete(session[:recommendation_session_id])
      session.delete(:recommendation_session_id)
    end
    if session[:refined_session_id]
      Rails.logger.info "Cleaning up existing refined session data"
      TemporaryRecommendationStorage.delete(session[:refined_session_id])
      session.delete(:refined_session_id)
    end
    Rails.logger.info "All session data cleaned up for fresh start"
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
      
      # Validate user feedback - ensure likes and dislikes are mutually exclusive
      if user_feedback['likes'] && user_feedback['dislikes']
        # Remove any books that appear in both likes and dislikes
        user_feedback['likes'] = user_feedback['likes'].reject { |book| user_feedback['dislikes'].include?(book) }
        Rails.logger.info "Cleaned conflicting feedback - removed books that were both liked and disliked"
      end
      
      Rails.logger.info "Chat message received: context=#{context.inspect}, tones=#{tone_chips.inspect}, history=#{include_history}, feedback=#{user_feedback.inspect}"
      
      # Clean up any stale session data that might interfere
      if !session[:current_session_id] || !session[:current_context]
        Rails.logger.info "Cleaning up stale session data"
        session.delete(:current_context)
        session.delete(:current_session_id)
        session.delete(:current_feedback)
      end
      
      # Determine if this is a new session or refinement
      has_valid_session = session[:current_session_id] && session[:current_context]
      
      if has_valid_session
        # Refinement of previous context - we have a valid ongoing session
        user_prompt = build_refined_prompt(session[:current_context], context, user_feedback)
        Rails.logger.info "Using REFINED prompt for existing session: #{context}"
      else
        # First interaction or new session: create initial context and use structured prompt
        user_prompt = build_structured_prompt(context, tone_chips, include_history, user_feedback)
        Rails.logger.info "Using INITIAL prompt for new session: #{context}"
        
        # Clear any stale session data to ensure clean start
        session.delete(:current_context)
        session.delete(:current_session_id)
        session.delete(:current_feedback)
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
      
      # Include debug data only in development environment
      if Rails.env.development?
        response_data[:raw_prompt] = user_prompt
        response_data[:raw_ai_response] = ai_response
        response_data[:debug_enabled] = true
        
        # Log debug info to Rails logger
        Rails.logger.debug "=== DEBUG INFO ==="
        Rails.logger.debug "Raw Prompt: #{user_prompt}"
        Rails.logger.debug "Raw AI Response: #{ai_response}"
        Rails.logger.debug "=================="
      end
      
      render json: response_data
      
    rescue => e
      Rails.logger.error "Error in chat_message: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: {
        success: false,
        error: "Sorry, an error occurred. Please try again.",
        details: e.message
      }, status: :internal_server_error
    end
  end

  def clear_session
    # Clear all session data related to recommendations
    session.delete(:current_context)
    session.delete(:current_session_id)
    session.delete(:current_feedback)
    session.delete(:recommendation_session_id)
    session.delete(:refined_session_id)
    session.delete(:last_context)
    session.delete(:current_session_feedback)
    
    # Clear temporary storage for all possible session IDs
    [:current_session_id, :recommendation_session_id, :refined_session_id].each do |session_key|
      if session[session_key]
        begin
          TemporaryRecommendationStorage.clear(session[session_key])
          Rails.logger.info "Cleared temporary storage for session: #{session[session_key]}"
        rescue => e
          Rails.logger.warn "Could not clear temporary storage for #{session_key}: #{e.message}"
        end
      end
    end
    
    # Clear any other potential session variables with pattern matching
    session.keys.grep(/recommendation|refinement|feedback|context|session/).each do |key|
      Rails.logger.info "Clearing session key: #{key}"
      session.delete(key)
    end
    
    # Force session cleanup by setting to nil
    session[:current_context] = nil
    session[:current_session_id] = nil
    session[:current_feedback] = nil
    
    Rails.logger.info "Session completely cleared for user"
    
    render json: {
      success: true,
      message: "Session cleared successfully"
    }
  end


  private



  def build_refined_prompt(original_context, refinement_text, user_feedback = {})
    # Build a refined prompt that conserves context and adds refinement
    prompt = "You are a knowledgeable book recommendation expert. The user wants to REFINE their previous request.\n\n"
    prompt += "⚠️  CRITICAL: You are being asked to REFINE, not repeat. You MUST provide NEW, DIFFERENT book recommendations.\n\n"
    
    # Original context
    if original_context.present?
      prompt += "ORIGINAL REQUEST: #{original_context}\n\n"
    end
    
    # New refinement
    prompt += "REFINEMENT REQUEST: #{refinement_text}\n\n"
    
    # Add current session user feedback (likes/dislikes from current conversation)
    if user_feedback && (user_feedback['likes']&.any? || user_feedback['dislikes']&.any?)
      prompt += "CURRENT SESSION FEEDBACK:\n"
      
      if user_feedback['likes']&.any?
        prompt += "Books they liked in this session:\n"
        user_feedback['likes'].each { |book| prompt += "- #{book}\n" }
        prompt += "\n"
      end
      
      if user_feedback['dislikes']&.any?
        prompt += "Books they disliked in this session:\n"
        user_feedback['dislikes'].each { |book| prompt += "- #{book}\n" }
        prompt += "\n"
      end
      
      prompt += "IMPORTANT: Use this current session feedback to avoid recommending books similar to disliked ones and prioritize books similar to liked ones.\n\n"
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

  def build_structured_prompt(context, tone_chips, include_history, user_feedback = {})
    Rails.logger.info "build_structured_prompt called with: context=#{context.inspect}, tone_chips=#{tone_chips.inspect}, include_history=#{include_history}, user_feedback=#{user_feedback.inspect}"
    
    prompt = "You are a knowledgeable book recommendation expert. Please provide book recommendations in the EXACT format specified below.\n\n"
    
    # Add context
    if context.present?
      prompt += "USER CONTEXT: #{context}\n\n"
    end
    
    # Add tone preferences
    if tone_chips && tone_chips.any?
      prompt += "TONE PREFERENCES: #{tone_chips.join(', ')}\n\n"
    end
    
    # Add current session user feedback (likes/dislikes from current conversation)
    if user_feedback && (user_feedback['likes']&.any? || user_feedback['dislikes']&.any?)
      prompt += "CURRENT SESSION FEEDBACK:\n"
      
      if user_feedback['likes']&.any?
        prompt += "Books they liked in this session:\n"
        user_feedback['likes'].each { |book| prompt += "- #{book}\n" }
        prompt += "\n"
      end
      
      if user_feedback['dislikes']&.any?
        prompt += "Books they disliked in this session:\n"
        user_feedback['dislikes'].each { |book| prompt += "- #{book}\n" }
        prompt += "\n"
      end
      
      prompt += "IMPORTANT: Use this current session feedback to avoid recommending books similar to disliked ones and prioritize books similar to liked ones.\n\n"
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
    
    prompt += "CRITICAL: Each preference must be on a separate line with its own dash (-). Do NOT combine multiple preferences on the same line with dashes.\n\n"
    
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
    
    Rails.logger.info "=== PARSING AI RESPONSE ==="
    Rails.logger.info "Response length: #{response.length}"
    Rails.logger.info "Response contains 'BRIEF:': #{response.include?('BRIEF:')}"
    Rails.logger.info "Response contains 'TOP PICKS:': #{response.include?('TOP PICKS:')}"
    
    parsed = {
      brief: {},
      picks: []
    }
    
    # Split into sections
    if response.include?("BRIEF:")
      Rails.logger.info "Found BRIEF section, attempting to split by TOP PICKS:"
      
      # More robust splitting
      if response.include?("TOP PICKS:")
        sections = response.split("TOP PICKS:")
        if sections.length >= 2
          brief_section = sections[0]
          picks_section = sections[1]
          
          Rails.logger.info "Split successful:"
          Rails.logger.info "Brief section length: #{brief_section.length}"
          Rails.logger.info "Picks section length: #{picks_section.length}"
          Rails.logger.info "Picks section preview: #{picks_section[0..200]}..."
          
          # Parse brief sections with FIXED method
          parsed[:brief][:likes] = extract_bullet_points_fixed(brief_section, "What you tend to like:")
          parsed[:brief][:explore] = extract_bullet_points_fixed(brief_section, "What to explore next:")
          parsed[:brief][:avoid] = extract_bullet_points_fixed(brief_section, "Pitfalls to avoid:")
          
          # Parse picks with FIXED method
          parsed[:picks] = extract_book_picks_fixed(picks_section)
        else
          Rails.logger.error "Split failed: expected 2 sections, got #{sections.length}"
        end
      else
        Rails.logger.error "Response contains BRIEF but not TOP PICKS"
      end
    else
      Rails.logger.error "Response does not contain BRIEF section"
    end
    
    Rails.logger.info "Final parsed result:"
    Rails.logger.info "Brief keys: #{parsed[:brief].keys}"
    Rails.logger.info "Picks count: #{parsed[:picks].length}"
    Rails.logger.info "=== END PARSING ==="
    
    parsed
  end

  def extract_bullet_points_fixed(text, section_name)
    # FIXED VERSION: Extract bullet points properly
    Rails.logger.info "Extracting bullet points for: #{section_name}"
    
    if text.include?(section_name)
      Rails.logger.info "Found section: #{section_name}"
      
      # Find the start of this section
      start_index = text.index(section_name) + section_name.length
      
      # Find the end by looking for the next section
      end_index = if section_name == "What you tend to like:"
                    text.index("What to explore next:") || text.length
                  elsif section_name == "What to explore next:"
                    text.index("Pitfalls to avoid:") || text.length
                  else
                    text.length
                  end
      
      section_text = text[start_index...end_index].strip
      Rails.logger.info "Section text: '#{section_text}'"
      
      # IMPROVED: First try to extract by line breaks (proper format)
      # Look for lines starting with "- " or "-"
      lines = section_text.split("\n").map(&:strip).reject(&:empty?)
      bullet_points = []
      
      lines.each do |line|
        if line.start_with?("- ") || line.start_with?("-")
          # Clean up the bullet point
          point = line.sub(/^-\s*/, "").strip
          bullet_points << point unless point.empty?
        end
      end
      
      # If no bullet points found by line breaks, fall back to dash splitting
      if bullet_points.empty?
        Rails.logger.info "No bullet points found by line breaks, falling back to dash splitting"
        bullet_points = section_text.split(" - ").map(&:strip).reject(&:empty?)
      end
      
      Rails.logger.info "Extracted points: #{bullet_points.inspect}"
      bullet_points
    else
      Rails.logger.info "Section not found: #{section_name}"
      []
    end
  end

  def extract_book_picks_fixed(text)
    # FIXED VERSION: Extract book picks properly
    Rails.logger.info "Extracting book picks from text: #{text.length} characters"
    Rails.logger.info "Text preview: '#{text[0..100]}...'"
    
    picks = []
    return picks unless text
    
    # IMPROVED: More robust regex that handles BOTH formats
    # Look for: "1. *Title* by Author" OR "1. **Title** by Author"
    # The key is to handle both single and double asterisks
    book_pattern = /(\d+)\.\s*\*{1,2}(.+?)\*{1,2}\s*by\s*(.+?)\s*Pitch:\s*(.+?)\s*Why:\s*(.+?)\s*Confidence:\s*(.+?)(?=\d+\.|$)/m
    
    matches = text.scan(book_pattern)
    Rails.logger.info "Found #{matches.length} book entries with improved pattern"
    
    if matches.empty?
      Rails.logger.info "Improved pattern failed, trying simpler approach..."
      # Fallback: just extract title and author with more flexible spacing
      simple_pattern = /(\d+)\.\s*\*{1,2}(.+?)\*{1,2}\s*by\s*(.+?)(?=\d+\.|$)/m
      matches = text.scan(simple_pattern)
      Rails.logger.info "Found #{matches.length} book entries with simple pattern"
    end
    
    matches.each_with_index do |match, index|
      if match.length >= 6
        # Full pattern matched
        number, title, author, pitch, why, confidence = match
        Rails.logger.info "Processing book #{number} (full match): '#{title}' by '#{author}'"
      else
        # Simple pattern matched
        number, title, author = match
        Rails.logger.info "Processing book #{number} (simple match): '#{title}' by '#{author}'"
        
        # Try to extract fields manually with improved field extraction
        pitch = extract_field_fixed(text, number, "Pitch:")
        why = extract_field_fixed(text, number, "Why:")
        confidence = extract_field_fixed(text, number, "Confidence:")
      end
      
      pick = {
        number: number.to_i,
        title: title.strip,
        author: author.strip,
        pitch: pitch&.strip || "AI-generated pitch",
        why: why&.strip || "Based on your preferences",
        confidence: confidence&.strip || "Medium"
      }
      
      Rails.logger.info "Created pick: #{pick.inspect}"
      picks << pick
    end
    
    Rails.logger.info "Final picks: #{picks.inspect}"
    picks.first(3) # Ensure we only get 3 picks
  end

  def extract_field_fixed(text, book_number, field_name)
    # IMPROVED VERSION: Extract individual fields with better handling
    Rails.logger.info "Extracting #{field_name} for book #{book_number}"
    
    # Find the book section first - handle both * and ** formats
    book_start = text.index("#{book_number}. *")
    book_start = text.index("#{book_number}. **") if book_start.nil?
    return nil unless book_start
    
    # Find where this book section ends (next book or end of text) - handle both formats
    next_book = text.index("#{book_number.to_i + 1}. *", book_start)
    next_book = text.index("#{book_number.to_i + 1}. **", book_start) if next_book.nil?
    book_end = next_book || text.length
    
    book_section = text[book_start...book_end]
    Rails.logger.info "Book section: '#{book_section[0..100]}...'"
    
    # Find the field in this section
    field_start = book_section.index(field_name)
    return nil unless field_start
    
    # Find where this field ends (next field or end of book section)
    field_start += field_name.length
    
    # Look for the next field - handle the case where fields might be adjacent
    next_field = nil
    ['Why:', 'Confidence:'].each do |next_field_name|
      pos = book_section.index(next_field_name, field_start)
      if pos && (next_field.nil? || pos < next_field)
        next_field = pos
      end
    end
    
    # Also look for the next book number - handle both * and ** formats
    next_book_in_section = book_section.index(/\d+\.\s*\*{1,2}/, field_start)
    if next_book_in_section && (next_field.nil? || next_book_in_section < next_field)
      next_field = next_book_in_section
    end
    
    field_end = next_field || book_section.length
    value = book_section[field_start...field_end].strip
    
    Rails.logger.info "Found #{field_name}: '#{value}'"
    value
  end

  # Enrich recommendations with metadata from Google Books API
  def enrich_recommendations_with_metadata(parsed_response)
    return unless parsed_response&.dig(:picks)&.any?
    
    # Initialize metadata service
    metadata_service = BookMetadataService.new
    
    # Enrich each book pick synchronously to ensure UI displays enriched data
    parsed_response[:picks].each do |pick|
      begin
        metadata = metadata_service.fetch_book_metadata(
          pick[:title],
          pick[:author]
        )
        
        # Merge metadata with pick
        pick.merge!(metadata)
        Rails.logger.info "Enriched '#{pick[:title]}' with metadata: #{metadata.inspect}"
      rescue => e
        Rails.logger.error "Failed to enrich metadata for '#{pick[:title]}': #{e.message}"
        # Continue without metadata - don't block the recommendation
      end
    end
  end

  # Cleanup session data after view is rendered
  def cleanup_session
    session_type = params[:session_type]
    session_id = params[:session_id]
    
    Rails.logger.info "Cleaning up session: #{session_type}, ID: #{session_id}"
    
    if session_type == 'recommendation' && session[:recommendation_session_id] == session_id
      # Clean up the temporary file
      TemporaryRecommendationStorage.delete(session_id)
      # Clear the session
      session.delete(:recommendation_session_id)
      Rails.logger.info "Recommendation session cleaned up successfully"
    elsif session_type == 'refined' && session[:refined_session_id] == session_id
      # Clean up the temporary file
      TemporaryRecommendationStorage.delete(session_id)
      # Clear the session
      session.delete(:refined_session_id)
      Rails.logger.info "Refined session cleaned up successfully"
    else
      Rails.logger.warn "Session cleanup failed: type=#{session_type}, session_id=#{session_id}"
    end
    
    render json: { success: true, message: 'Session cleaned up' }
  end
end
