class BookMetadataService
  require 'net/http'
  require 'json'
  
  def initialize
    @api_key = ENV['GOOGLE_BOOKS_API_KEY']
  end

  def fetch_book_metadata(title, author = nil, isbn = nil)
    return {} unless @api_key && @api_key.strip.length > 0

    begin
      # Try Google Books first
      metadata = fetch_from_google_books(title, author, isbn)
      return metadata if metadata && !metadata.empty?

      # Fallback to Open Library if Google Books fails
      fetch_from_open_library(title, author, isbn)
    rescue => e
      log_error "Failed to fetch metadata for '#{title}': #{e.message}"
      {} # Return empty hash to avoid blocking
    end
  end

  private

  def fetch_from_google_books(title, author = nil, isbn = nil)
    # Build search query
    query_parts = [title]
    query_parts << author if author && author.strip.length > 0
    query_parts << "isbn:#{isbn}" if isbn && isbn.strip.length > 0
    
    query = query_parts.join(" ")
    
    # Make API call
    uri = URI("https://www.googleapis.com/books/v1/volumes")
    params = {
      q: query,
      key: @api_key,
      maxResults: 1
    }
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)
    return {} unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    return {} unless data['items']&.any?

    book = data['items'].first
    volume_info = book['volumeInfo']
    
    {
      cover_url: extract_cover_url(volume_info),
      rating: volume_info['averageRating'],
      review_count: volume_info['ratingsCount'],
      page_count: volume_info['pageCount'],
      published_date: volume_info['publishedDate'],
      categories: volume_info['categories']&.first,
      description: volume_info['description']
    }
  end

  def fetch_from_open_library(title, author = nil, isbn = nil)
    # Simple fallback to Open Library
    return {} unless isbn && isbn.strip.length > 0

    uri = URI("https://openlibrary.org/api/books?bibkeys=ISBN:#{isbn}&format=json&jscmd=data")
    response = Net::HTTP.get_response(uri)
    return {} unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    book_key = "ISBN:#{isbn}"
    book_data = data[book_key]
    return {} unless book_data

    {
      cover_url: extract_open_library_cover(book_data),
      rating: nil, # Open Library doesn't provide ratings
      review_count: nil,
      page_count: book_data['number_of_pages'],
      published_date: book_data['publish_date'],
      categories: book_data['subjects']&.first,
      description: nil
    }
  end

  def extract_cover_url(volume_info)
    image_links = volume_info['imageLinks']
    return nil unless image_links

    # Prefer larger cover images
    image_links['extraLarge'] || 
    image_links['large'] || 
    image_links['medium'] || 
    image_links['small'] || 
    image_links['thumbnail']
  end

  def extract_open_library_cover(book_data)
    covers = book_data['cover']
    return nil unless covers&.any?

    cover = covers.first
    "https://covers.openlibrary.org/b/id/#{cover['id']}-L.jpg"
  end

  def log_error(message)
    if defined?(Rails)
      Rails.logger.error message
    else
      puts "ERROR: #{message}"
    end
  end
end
