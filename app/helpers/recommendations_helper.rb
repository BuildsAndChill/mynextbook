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
end
