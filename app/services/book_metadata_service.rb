class BookMetadataService
  require 'net/http'
  require 'json'
  
  # Base URL pour l'API OpenLibrary
  OPENLIBRARY_API_BASE = 'https://openlibrary.org/api/books'
  
  # Récupère les informations complètes d'un livre depuis OpenLibrary
  def self.fetch_book_info(isbn)
    return nil if isbn.blank?
    
    begin
      # Normaliser l'ISBN (supprimer les tirets et espaces)
      clean_isbn = isbn.gsub(/[-\s]/, '')
      
      # Construire l'URL de l'API
      url = "#{OPENLIBRARY_API_BASE}?bibkeys=ISBN:#{clean_isbn}&format=json&jscmd=data"
      
      # Faire la requête HTTP
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        book_key = "ISBN:#{clean_isbn}"
        
        if data[book_key]
          book_data = data[book_key]
          {
            title: book_data['title'],
            author: extract_author(book_data['authors']),
            isbn: clean_isbn,
            pages: book_data['number_of_pages'],
            cover_url: book_data.dig('cover', 'large') || book_data.dig('cover', 'medium') || book_data.dig('cover', 'small'),
            publisher: book_data['publishers']&.first&.dig('name'),
            publish_date: book_data['publish_date'],
            subjects: book_data['subjects']&.map { |s| s['name'] }&.first(5),
            description: truncate_description(book_data['description']),
            language: book_data['languages']&.first&.dig('key')&.split('/')&.last
          }
        else
          nil
        end
      else
        Rails.logger.warn "Failed to fetch book info for ISBN #{isbn}: HTTP #{response.code}"
        nil
      end
    rescue => e
      Rails.logger.error "Error fetching book info for ISBN #{isbn}: #{e.message}"
      nil
    end
  end
  
  # Récupère les informations pour plusieurs ISBN en une seule fois
  def self.fetch_multiple_books_info(isbns)
    return {} if isbns.blank?
    
    results = {}
    isbns.each do |isbn|
      results[isbn] = fetch_book_info(isbn)
    end
    results
  end
  
  # Enrichit les métadonnées d'un livre existant
  def self.enrich_book_metadata(book_metadata)
    return book_metadata unless book_metadata.has_reliable_identifier?
    
    # Essayer d'abord avec ISBN13, puis ISBN
    isbn_to_try = book_metadata.isbn13.presence || book_metadata.isbn
    
    if isbn_to_try
      api_data = fetch_book_info(isbn_to_try)
      
      if api_data
        # Mettre à jour les métadonnées avec les informations de l'API
        book_metadata.update!(
          pages: api_data[:pages] || book_metadata.pages,
          average_rating: book_metadata.average_rating # Garder la note existante
        )
        
        # Log de l'enrichissement
        Rails.logger.info "Enriched book metadata for '#{book_metadata.title}' with OpenLibrary data"
      end
    end
    
    book_metadata
  end
  
  # Recherche de livres par titre et auteur
  def self.search_books(query, limit = 10)
    return [] if query.blank?
    
    begin
      # Utiliser l'API de recherche OpenLibrary
      search_url = "https://openlibrary.org/search.json?q=#{CGI.escape(query)}&limit=#{limit}"
      
      uri = URI(search_url)
      response = Net::HTTP.get_response(uri)
      
      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        books = data['docs'] || []
        
        books.map do |book|
          {
            title: book['title'],
            author: extract_author(book['author_name']),
            isbn: book['isbn']&.first,
            isbn13: book['isbn_13']&.first,
            pages: book['number_of_pages_median'],
            cover_url: book['cover_i'] ? "https://covers.openlibrary.org/b/id/#{book['cover_i']}-L.jpg" : nil,
            publish_date: book['first_publish_year'],
            key: book['key']
          }
        end
      else
        Rails.logger.warn "Failed to search books: HTTP #{response.code}"
        []
      end
    rescue => e
      Rails.logger.error "Error searching books: #{e.message}"
      []
    end
  end
  
  # Récupère les couvertures disponibles pour un livre
  def self.get_cover_urls(isbn, size = 'L')
    return [] if isbn.blank?
    
    clean_isbn = isbn.gsub(/[-\s]/, '')
    base_url = "https://covers.openlibrary.org/b/isbn/#{clean_isbn}"
    
    # Tailles disponibles : S (small), M (medium), L (large)
    sizes = ['S', 'M', 'L']
    
    sizes.map do |s|
      "#{base_url}-#{s}.jpg"
    end
  end
  
  private
  
  # Extrait le nom de l'auteur principal
  def self.extract_author(authors)
    return nil if authors.blank?
    
    if authors.is_a?(Array)
      authors.first&.dig('name') || authors.first
    else
      authors
    end
  end
  
  # Tronque la description si elle est trop longue
  def self.truncate_description(description, max_length = 500)
    return nil if description.blank?
    
    if description.length > max_length
      description[0...max_length] + '...'
    else
      description
    end
  end
end
