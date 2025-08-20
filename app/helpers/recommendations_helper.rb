module RecommendationsHelper
  # Generate intelligent search URLs for books
  def book_search_url(book_title, book_author)
    # Strategy: Try Goodreads first, then Amazon, then Google Books as fallback
    
    # 1. Goodreads search (most relevant for book lovers)
    goodreads_query = "#{book_title} #{book_author} goodreads"
    goodreads_url = "https://www.google.com/search?q=#{CGI.escape(goodreads_query)}"
    
    # 2. Amazon search (for purchasing)
    amazon_query = "#{book_title} #{book_author} amazon"
    amazon_url = "https://www.google.com/search?q=#{CGI.escape(amazon_query)}"
    
    # 3. Google Books (reliable fallback)
    google_books_query = "#{book_title} #{book_author}"
    google_books_url = "https://books.google.com/books?q=#{CGI.escape(google_books_query)}"
    
    # Return the Goodreads search as primary, with fallbacks available
    {
      primary: goodreads_url,
      fallback: amazon_url,
      google_books: google_books_url
    }
  end
  
  # Generate a simple search URL for immediate use
  def simple_book_search_url(book_title, book_author)
    # Smart search: title + author + goodreads
    Rails.logger.info "simple_book_search_url called with: title=#{book_title.inspect}, author=#{book_author.inspect}"
    query = "#{book_title} #{book_author} goodreads"
    
    # Try to get the first search result directly
    begin
                      direct_url = GoogleCustomSearchService.get_first_search_result(query)
      Rails.logger.info "Direct URL found: #{direct_url}"
      return direct_url
    rescue => e
      Rails.logger.error "Failed to get direct URL: #{e.message}, falling back to Google Books"
      # Fallback to Google Books (more reliable than Google Search)
      google_books_url = "https://books.google.com/books?q=#{CGI.escape("#{book_title} #{book_author}")}"
      Rails.logger.info "Fallback Google Books URL: #{google_books_url}"
      return google_books_url
    end
  end
  
  # Détermine si on doit afficher le CTA email et avec quel message
  def should_show_email_cta?
    return false if user_signed_in? # Pas de CTA pour les utilisateurs connectés
    
    # Compter les interactions de la session actuelle
    interaction_count = count_current_session_interactions
    
    case interaction_count
    when 1
      { show: true, type: 'soft', message: 'Recevoir ces recommandations dans ta boîte mail ?' }
    when 2
      { show: true, type: 'gentle', message: 'Pour continuer à explorer, entre ton email gratuit' }
    when 3..Float::INFINITY
      { show: true, type: 'friendly', message: 'Recevoir tes prochaines découvertes par email ?' }
    else
      { show: false, type: nil, message: nil }
    end
  end
  
  # Compte les interactions de la session actuelle
  def count_current_session_interactions
    user_actions = session[:user_actions] || []
    session_actions = user_actions.select { |action| action[:session_id] == session.id.to_s }
    
    recommendations = session_actions.count { |action| action[:action] == 'recommendation_created' }
    refinements = session_actions.count { |action| action[:action] == 'recommendation_refined' }
    
    recommendations + refinements
  end
  
  # Génère un message personnalisé basé sur le contexte
  def personalized_email_message
    context = session[:last_context] || 'tes préférences'
    
    messages = [
      "Recevoir tes prochaines découvertes basées sur '#{context.truncate(30)}' ?",
      "Garder une trace de tes recommandations personnalisées ?",
      "Recevoir des suggestions similaires par email ?",
      "Ne jamais perdre tes bonnes découvertes ?"
    ]
    
    messages.sample
  end
  
  # Vérifie si l'utilisateur a déjà fourni un email dans cette session
  def email_already_captured?
    session[:email_captured] == true
  end
  
  # Marque l'email comme capturé dans cette session
  def mark_email_captured
    session[:email_captured] = true
  end
end
