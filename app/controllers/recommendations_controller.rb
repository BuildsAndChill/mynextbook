class RecommendationsController < ApplicationController
  # Remove authentication requirement - allow unlogged users to get basic recommendations
  
  def index
    # TEMPORAIREMENT DÉSACTIVÉ: Redirection mobile vers chat UX
    # TODO: Réactiver après refactor du layout responsive desktop
    # user_agent = request.user_agent.downcase
    # is_mobile = user_agent.include?('mobile') || user_agent.include?('android') || user_agent.include?('iphone') || user_agent.include?('ipad')
    
    # Check if it's a mobile device
    # if is_mobile
    #   Rails.logger.info "Mobile device detected, redirecting to chat interface"
    #   redirect_to chat_recommendations_path
    # else
    #   Rails.logger.info "Desktop/Tablet detected, showing initial form"
    #   # Clean up any existing session data (fresh start)
    #   cleanup_all_sessions
    #   # Show the initial form directly (no redirect)
    # end
    
    # TEMPORAIRE: Tous les utilisateurs voient le formulaire principal
    Rails.logger.info "Showing main recommendation form for all devices (mobile redirect temporarily disabled)"
    # Clean up any existing session data (fresh start)
    cleanup_all_sessions
    # Show the initial form directly (no redirect)
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
      
      # Track recommendation creation with new system
      track_user_interaction('recommendation_created', context, {
        tone_chips: tone_chips,
        include_history: include_history,
        books_count: @parsed_response&.dig(:picks)&.count || 0
      })
      
      # Enrich recommendations with metadata (non-blocking)
      enrich_recommendations_with_metadata(@parsed_response)
      
      # NEW: Enrich with direct links to Goodreads/Amazon
      enrich_with_direct_links(@parsed_response)
      
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
    
    # Log user interaction for analytics
    Rails.logger.info "USER_INTERACTION: recommendation_created | session_id: #{session_id} | context: #{context} | tone_chips: #{tone_chips} | user_signed_in: #{user_signed_in?} | user_id: #{current_user&.id}"
    
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



  def refine
    # Handle refinement requests with context conservation
    refinement_text = params[:refinement_text]
    context = params[:context]
    
    # Track refinement interaction with new system
    track_user_interaction('recommendation_refined', context, {
      refinement_text: refinement_text,
      books_count: 0 # Will be updated after AI response
    })
    
    # Log refinement interaction for analytics
    Rails.logger.info "USER_INTERACTION: recommendation_refined | refinement_text: #{refinement_text} | context: #{context} | user_signed_in: #{user_signed_in?} | user_id: #{current_user&.id} | session_id: #{session[:recommendation_session_id]}"
    
    Rails.logger.info "Refining recommendation with: #{refinement_text}"
    Rails.logger.info "Context: #{context}"
    
    # SIGNUP WALL: Check if user wants to include reading history
    include_history = params[:include_history] == '1'
    
    if include_history && !user_signed_in?
      Rails.logger.info "Signup wall triggered: unauthenticated user wants to include reading history"
      
      # Track signup wall shown
      track_user_action('signup_wall_shown', {
        action: 'refine_with_history_attempted',
        refinement_text: refinement_text,
        context: context,
        include_history: true
      })
      
      # Return JSON response to trigger signup modal
      render json: {
        action: 'show_signup_wall',
        message: 'Crée ton compte pour utiliser ton historique de lecture et affiner tes recommandations',
        title: 'Personnaliser avec ton historique',
        benefits: [
          'Importer tes lectures Goodreads',
          'Ajouter tes livres manuellement',
          'Recommandations basées sur tes goûts réels'
        ],
        cta_text: 'Créer mon compte',
        redirect_url: new_user_registration_path
      }
      return
    end
    
    # Try to get previous recommendations from session storage
    previous_recommendations = nil
    if session[:recommendation_session_id]
      Rails.logger.info "Found recommendation_session_id: #{session[:recommendation_session_id]}"
      stored_data = TemporaryRecommendationStorage.retrieve(session[:recommendation_session_id])
      if stored_data && stored_data[:parsed_response]
        previous_recommendations = stored_data[:parsed_response]
        Rails.logger.info "Retrieved previous recommendations from storage: #{previous_recommendations.inspect}"
      else
        Rails.logger.info "No stored data found for session_id: #{session[:recommendation_session_id]}"
      end
    else
      Rails.logger.info "No recommendation_session_id found in session"
    end
    
    # Build refined prompt with context conservation and previous recommendations
    @user_prompt = build_refined_prompt(context, refinement_text, {}, previous_recommendations)
    
    # Get new AI recommendation
    begin
      recommender = BookRecommender.new
      @ai_response = recommender.get_recommendation(@user_prompt)
      @ai_error = nil
      
      # Parse AI response into structured format
      @parsed_response = parse_ai_response(@ai_response)
      Rails.logger.info "Refined recommendation generated successfully"
      
      # Track refinement
      track_user_action('recommendation_refined', {
        refinement_text: refinement_text,
        context: context,
        include_history: include_history
      })
      
      # Enrich recommendations with metadata (non-blocking)
      enrich_recommendations_with_metadata(@parsed_response)
      
      # NEW: Enrich with direct links to Goodreads/Amazon
      enrich_with_direct_links(@parsed_response)
      
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
      
      # No need for flash message - the new suggestions speak for themselves
      
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

  def track_user_action(action, data = {})
    # Simple tracking for MVP - log to console and session
    tracking_data = {
      action: action,
      timestamp: Time.current,
      user_id: user_signed_in? ? current_user.id : nil,
      session_id: session.id,
      data: data
    }
    
    Rails.logger.info "USER ACTION TRACKED: #{tracking_data.inspect}"
    
    # Store in session for funnel analysis
    session[:user_actions] ||= []
    session[:user_actions] << tracking_data
    
    # Keep only last 50 actions to avoid session bloat
    session[:user_actions] = session[:user_actions].last(50)
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



  def build_refined_prompt(original_context, refinement_text, user_feedback = {}, previous_recommendations = {})
    # Build a refined prompt that conserves context and adds refinement
    Rails.logger.info "=== build_refined_prompt DEBUG ==="
    Rails.logger.info "original_context: #{original_context.inspect}"
    Rails.logger.info "refinement_text: #{refinement_text.inspect}"
    Rails.logger.info "user_feedback: #{user_feedback.inspect}"
    Rails.logger.info "previous_recommendations: #{previous_recommendations.inspect}"
    Rails.logger.info "previous_recommendations[:picks]: #{previous_recommendations&.dig(:picks)&.inspect}"
    Rails.logger.info "=== END DEBUG ==="
    
    prompt = "You are a knowledgeable book recommendation expert. The user wants to REFINE their previous request.\n\n"
    prompt += "⚠️  CRITICAL: You are being asked to REFINE, not repeat. You MUST provide NEW, DIFFERENT book recommendations.\n\n"
    
    # Original context
    if original_context.present?
      prompt += "ORIGINAL REQUEST: #{original_context}\n\n"
    end
    
    # New refinement
    prompt += "REFINEMENT REQUEST: #{refinement_text}\n\n"
    
    # PREVIOUS RECOMMENDATIONS - CRITICAL TO AVOID REPETITIONS
    Rails.logger.info "DEBUG: previous_recommendations class: #{previous_recommendations.class}"
    Rails.logger.info "DEBUG: previous_recommendations['picks'] class: #{previous_recommendations&.dig('picks')&.class}"
    Rails.logger.info "DEBUG: previous_recommendations['picks'] content: #{previous_recommendations&.dig('picks')&.inspect}"
    Rails.logger.info "DEBUG: previous_recommendations['picks'] any?: #{previous_recommendations&.dig('picks')&.any?}"
    
    if previous_recommendations&.dig('picks')&.any?
      Rails.logger.info "Adding previous recommendations to prompt: #{previous_recommendations['picks'].count} picks"
      prompt += "PREVIOUS RECOMMENDATIONS (DO NOT REPEAT THESE):\n"
      previous_recommendations['picks'].each_with_index do |pick, index|
        prompt += "#{index + 1}. #{pick['title']} by #{pick['author']}\n"
        if pick['pitch'].present?
          prompt += "   Reason: #{pick['pitch']}\n"
        end
        prompt += "\n"
      end
      prompt += "⚠️  CRITICAL: You MUST provide COMPLETELY DIFFERENT books. If you repeat any of the above, you have failed.\n\n"
    else
      Rails.logger.info "No previous recommendations to add to prompt"
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
    
    # Add reading history if user is signed in
    if user_signed_in?
      # Récupérer TOUT l'historique pertinent sans limite arbitraire
      all_books = current_user.user_readings.includes(:book_metadata)
        .where.not(status: 'abandoned')  # Exclure les abandonnés
        .order(created_at: :desc)       # Plus récents d'abord
      
      if all_books.any?
        prompt += "READING HISTORY:\n"
        
        # Livres déjà lus (à éviter absolument)
        read_books = all_books.where(status: 'read')
        if read_books.any?
          prompt += "ALREADY READ (DO NOT RECOMMEND):\n"
          read_books.each do |book|
            rating = book.rating || 'unrated'
            prompt += "- #{book.book_metadata.title} by #{book.book_metadata.author} (#{rating}/5 stars)\n"
          end
          prompt += "\n"
        end
        
        # Livres dans "to read" (déjà dans la liste)
        to_read_books = all_books.where(status: 'to_read')
        if to_read_books.any?
          prompt += "ALREADY IN TO-READ LIST:\n"
          to_read_books.each do |book|
            prompt += "- #{book.book_metadata.title} by #{book.book_metadata.author}\n"
          end
          prompt += "\n"
        end
        
        # Livres en cours de lecture (contexte actuel)
        reading_books = all_books.where(status: 'reading')
        if reading_books.any?
          prompt += "CURRENTLY READING:\n"
          reading_books.each do |book|
            prompt += "- #{book.book_metadata.title} by #{book.book_metadata.author}\n"
          end
          prompt += "\n"
        end
        
        # Instructions claires pour l'IA
        prompt += "IMPORTANT RULES FOR READING HISTORY:\n"
        prompt += "1. NEVER recommend books marked as 'ALREADY READ'\n"
        prompt += "2. If suggesting a book in 'ALREADY IN TO-READ LIST', mention it clearly\n"
        prompt += "3. Use reading patterns to suggest similar but different books\n"
        prompt += "4. Consider current reading status for context\n"
        prompt += "5. Focus on NEW discoveries based on user preferences\n\n"
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
    
    # ULTRA-STRICT FORMAT - Impossible to misinterpret
    prompt += "RESPONSE FORMAT - Follow EXACTLY, no variations allowed:\n\n"
    
    prompt += "BRIEF:\n"
    prompt += "LIKES:\n"
    prompt += "- [First preference point]\n"
    prompt += "- [Second preference point]\n"
    prompt += "- [Third preference point]\n\n"
    
    prompt += "EXPLORE:\n"
    prompt += "- [First exploration suggestion]\n"
    prompt += "- [Second exploration suggestion]\n"
    prompt += "- [Third exploration suggestion]\n\n"
    
    prompt += "AVOID:\n"
    prompt += "- [First pitfall to avoid]\n"
    prompt += "- [Second pitfall to avoid]\n\n"
    
    prompt += "BOOKS:\n"
    prompt += "1. TITLE: [Exact book title]\n"
    prompt += "   AUTHOR: [Exact author name]\n"
    prompt += "   PITCH: [2-line explanation of why this book fits the REFINEMENT]\n"
    prompt += "   WHY: [Specific reason tied to refinement request and original context]\n"
    prompt += "   CONFIDENCE: [High/Medium/Low]\n\n"
    
    prompt += "2. TITLE: [Exact book title]\n"
    prompt += "   AUTHOR: [Exact author name]\n"
    prompt += "   PITCH: [2-line explanation of why this book fits the REFINEMENT]\n"
    prompt += "   WHY: [Specific reason tied to refinement request and original context]\n"
    prompt += "   CONFIDENCE: [High/Medium/Low]\n\n"
    
    prompt += "3. TITLE: [Exact book title]\n"
    prompt += "   AUTHOR: [Exact author name]\n"
    prompt += "   PITCH: [2-line explanation of why this book fits the REFINEMENT]\n"
    prompt += "   WHY: [Specific reason tied to refinement request and original context]\n"
    prompt += "   CONFIDENCE: [High/Medium/Low]\n\n"
    

    
    prompt += "CRITICAL INSTRUCTION: This is a REFINEMENT request, NOT a repeat request. You MUST provide COMPLETELY DIFFERENT books that specifically address the refinement while building on the original context. \n\n"
    prompt += "⚠️  FINAL WARNING: If you repeat ANY of the previous recommendations listed above, you have completely failed this task. Each new recommendation must be unique and different from the previous ones."
    
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
    
      # Add reading history if user is signed in
      if user_signed_in?
        # Récupérer TOUT l'historique pertinent sans limite arbitraire
        all_books = current_user.user_readings.includes(:book_metadata)
          .where.not(status: 'abandoned')  # Exclure les abandonnés
          .order(created_at: :desc)       # Plus récents d'abord
        
        if all_books.any?
          prompt += "READING HISTORY:\n"
          
          # Livres déjà lus (à éviter absolument)
          read_books = all_books.where(status: 'read')
          if read_books.any?
            prompt += "ALREADY READ (DO NOT RECOMMEND):\n"
            read_books.each do |book|
              rating = book.rating || 'unrated'
              prompt += "- #{book.book_metadata.title} by #{book.book_metadata.author} (#{rating}/5 stars)\n"
            end
            prompt += "\n"
          end
          
          # Livres dans "to read" (déjà dans la liste)
          to_read_books = all_books.where(status: 'to_read')
          if to_read_books.any?
            prompt += "ALREADY IN TO-READ LIST:\n"
            to_read_books.each do |book|
              prompt += "- #{book.book_metadata.title} by #{book.book_metadata.author}\n"
            end
            prompt += "\n"
          end
          
          # Livres en cours de lecture (contexte actuel)
          reading_books = all_books.where(status: 'reading')
          if reading_books.any?
            prompt += "CURRENTLY READING:\n"
            reading_books.each do |book|
              prompt += "- #{book.book_metadata.title} by #{book.book_metadata.author}\n"
            end
            prompt += "\n"
          end
          
          # Instructions claires pour l'IA
          prompt += "IMPORTANT RULES FOR READING HISTORY:\n"
          prompt += "1. NEVER recommend books marked as 'ALREADY READ'\n"
          prompt += "2. If suggesting a book in 'ALREADY IN TO-READ LIST', mention it clearly\n"
          prompt += "3. Use reading patterns to suggest similar but different books\n"
          prompt += "4. Consider current reading status for context\n"
          prompt += "5. Focus on NEW discoveries based on user preferences\n\n"
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
    
    # ULTRA-STRICT FORMAT - Impossible to misinterpret
    prompt += "RESPONSE FORMAT - Follow EXACTLY, no variations allowed:\n\n"
    prompt += "BRIEF:\n"
    prompt += "LIKES:\n"
    prompt += "- [First preference point]\n"
    prompt += "- [Second preference point]\n"
    prompt += "- [Third preference point]\n\n"
    
    prompt += "EXPLORE:\n"
    prompt += "- [First exploration suggestion]\n"
    prompt += "- [Second exploration suggestion]\n"
    prompt += "- [Third exploration suggestion]\n\n"
    
    prompt += "AVOID:\n"
    prompt += "- [First pitfall to avoid]\n"
    prompt += "- [Second pitfall to avoid]\n\n"
    
    prompt += "BOOKS:\n"
    prompt += "1. TITLE: [Exact book title]\n"
    prompt += "   AUTHOR: [Exact author name]\n"
    prompt += "   PITCH: [2-line explanation of why this book fits]\n"
    prompt += "   WHY: [Specific reason tied to preferences]\n"
    prompt += "   CONFIDENCE: [High/Medium/Low]\n\n"
    
    prompt += "2. TITLE: [Exact book title]\n"
    prompt += "   AUTHOR: [Exact author name]\n"
    prompt += "   PITCH: [2-line explanation of why this book fits]\n"
    prompt += "   WHY: [Specific reason tied to preferences]\n"
    prompt += "   CONFIDENCE: [High/Medium/Low]\n\n"
    
    prompt += "3. TITLE: [Exact book title]\n"
    prompt += "   AUTHOR: [Exact author name]\n"
    prompt += "   PITCH: [2-line explanation of why this book fits]\n"
    prompt += "   WHY: [Specific reason tied to preferences]\n"
    prompt += "   CONFIDENCE: [High/Medium/Low]\n\n"
    
    prompt += "CRITICAL: Use EXACTLY this format. Each field must be on its own line. Use real book titles and authors."
    
    Rails.logger.info "Final prompt length: #{prompt.length}"
    Rails.logger.info "Final prompt preview: #{prompt.first(200)}..."
    
    prompt
  end

  def parse_ai_response(response)
    # ULTRA-ROBUST PARSING using new strict format
    return { brief: {}, picks: [] } unless response
    
    Rails.logger.info "=== ULTRA-ROBUST PARSING ==="
    Rails.logger.info "Response length: #{response.length}"
    Rails.logger.info "Response contains 'BRIEF:': #{response.include?('BRIEF:')}"
    Rails.logger.info "Response contains 'BOOKS:': #{response.include?('BOOKS:')}"
    
    parsed = {
      brief: {},
      picks: []
    }
    
    # Split into sections using new format
    if response.include?("BRIEF:")
      Rails.logger.info "Found BRIEF section, attempting to split by BOOKS:"
      
      # Split by new BOOKS keyword
      if response.include?("BOOKS:")
        sections = response.split("BOOKS:")
        if sections.length >= 2
          brief_section = sections[0]
          books_section = sections[1]
          
          Rails.logger.info "Split successful:"
          Rails.logger.info "Brief section length: #{brief_section.length}"
          Rails.logger.info "Books section length: #{books_section.length}"
          Rails.logger.info "Books section preview: #{books_section[0..200]}..."
          
          # Parse brief sections using new keywords
          parsed[:brief][:likes] = extract_bullet_points_ultra_robust(brief_section, "LIKES:")
          parsed[:brief][:explore] = extract_bullet_points_ultra_robust(brief_section, "EXPLORE:")
          parsed[:brief][:avoid] = extract_bullet_points_ultra_robust(brief_section, "AVOID:")
          
          # Parse books using new ultra-robust method
          parsed[:picks] = extract_books_ultra_robust(books_section)
        else
          Rails.logger.error "Split failed: expected 2 sections, got #{sections.length}"
        end
      else
        Rails.logger.error "Response contains BRIEF but not BOOKS"
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

  def extract_bullet_points_ultra_robust(text, section_name)
    # ULTRA-ROBUST: Extract bullet points using new strict format
    Rails.logger.info "Extracting bullet points for: #{section_name}"
    
    if text.include?(section_name)
      Rails.logger.info "Found section: #{section_name}"
      
      # Find the start of this section
      start_index = text.index(section_name) + section_name.length
      
      # Find the end by looking for the next section
      end_index = if section_name == "LIKES:"
                    text.index("EXPLORE:") || text.length
                  elsif section_name == "EXPLORE:"
                    text.index("AVOID:") || text.length
                  else
                    text.length
                  end
      
      section_text = text[start_index...end_index].strip
      Rails.logger.info "Section text: '#{section_text}'"
      
      # ULTRA-ROBUST: Extract by line breaks with strict format
      lines = section_text.split("\n").map(&:strip).reject(&:empty?)
      bullet_points = []
      
      lines.each do |line|
        if line.start_with?("- ") || line.start_with?("-")
          # Clean up the bullet point
          point = line.sub(/^-\s*/, "").strip
          bullet_points << point unless point.empty?
        end
      end
      
      Rails.logger.info "Extracted points: #{bullet_points.inspect}"
      bullet_points
    else
      Rails.logger.info "Section not found: #{section_name}"
      []
    end
  end

  def extract_books_ultra_robust(text)
    # ULTRA-ROBUST: Extract books using new strict format with keywords
    Rails.logger.info "Extracting books from text: #{text.length} characters"
    Rails.logger.info "Text preview: '#{text[0..100]}...'"
    
    picks = []
    return picks unless text
    
    # ULTRA-ROBUST: Split by book numbers and extract by keywords
    book_blocks = text.split(/(?=\d+\.)/)
    Rails.logger.info "Found #{book_blocks.length} book blocks"
    
    book_blocks.each_with_index do |block, index|
      next if index == 0 # Skip first empty block
      
      Rails.logger.info "Processing book block #{index}: '#{block[0..100]}...'"
      
      # Extract fields using new keywords
      title = extract_field_by_keyword(block, "TITLE:")
      author = extract_field_by_keyword(block, "AUTHOR:")
      pitch = extract_field_by_keyword(block, "PITCH:")
      why = extract_field_by_keyword(block, "WHY:")
      confidence = extract_field_by_keyword(block, "CONFIDENCE:")
      
      if title && author
        pick = {
          number: index,
          title: title.strip,
          author: author.strip,
          pitch: pitch&.strip || "AI-generated pitch",
          why: why&.strip || "Based on your preferences",
          confidence: confidence&.strip || "Medium"
        }
        
        Rails.logger.info "Created pick: #{pick.inspect}"
        picks << pick
      else
        Rails.logger.warn "Book block #{index} missing title or author: title=#{title.inspect}, author=#{author.inspect}"
      end
    end
    
    Rails.logger.info "Final picks: #{picks.inspect}"
    picks.first(3) # Ensure we only get 3 picks
  end
  
  def extract_field_by_keyword(text, keyword)
    # ULTRA-ROBUST: Extract field value by keyword
    return nil unless text.include?(keyword)
    
    start_index = text.index(keyword) + keyword.length
    end_index = text.length
    
    # Look for next keyword or end of text
    next_keywords = ["TITLE:", "AUTHOR:", "PITCH:", "WHY:", "CONFIDENCE:"]
    next_keywords.each do |next_keyword|
      if next_keyword != keyword
        pos = text.index(next_keyword, start_index)
        if pos && pos < end_index
          end_index = pos
        end
      end
    end
    
    value = text[start_index...end_index].strip
    Rails.logger.info "Extracted #{keyword}: '#{value}'"
    value
  end

  def extract_field_fixed(text, book_number, field_name)
    # IMPROVED VERSION: Extract individual fields with better handling
    Rails.logger.info "Extracting #{field_name} for book #{book_number}"
    
    # Find the book section first - handle * and ** formats with optional quotes
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
    
    # Also look for the next book number - handle * and ** formats with optional quotes
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

  # Enrich recommendations with direct links based on SEARCH_MODIFIER
  def enrich_with_direct_links(parsed_response)
    return unless parsed_response&.dig(:picks)&.any?
    
    search_modifier = ENV.fetch('SEARCH_MODIFIER', 'goodreads')
    Rails.logger.info "Enriching recommendations with direct links using #{search_modifier}..."
    
    # Enrich each book pick with direct links
    parsed_response[:picks].each do |pick|
      begin
        # Generate search query for this book using the search modifier
        search_query = "#{pick[:title]} #{pick[:author]} #{search_modifier}"
        
        # Get the first search result (direct link)
        direct_link = GoogleCustomSearchService.get_first_search_result(search_query)
        
        # Add the direct link to the pick
        pick[:direct_link] = direct_link
        
        Rails.logger.info "Added direct link for '#{pick[:title]}': #{direct_link}"
      rescue => e
        Rails.logger.error "Failed to get direct link for '#{pick[:title]}': #{e.message}"
        # Fallback to search URL if direct link fails
        search_url = "https://www.google.com/search?q=#{CGI.escape("#{pick[:title]} #{pick[:author]} #{search_modifier}")}"
        pick[:direct_link] = search_url
        Rails.logger.info "Using fallback search URL for '#{pick[:title]}': #{search_url}"
      end
    end
    
    Rails.logger.info "Direct links enrichment completed using #{search_modifier}"
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
