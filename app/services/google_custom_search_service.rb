require 'net/http'
require 'json'

class GoogleCustomSearchService
  def self.get_first_search_result(search_query)
    begin
      # Get API credentials from environment variables
      api_key = ENV['GOOGLE_CUSTOM_SEARCH_API_KEY']
      search_engine_id = ENV['GOOGLE_CUSTOM_SEARCH_ENGINE_ID']
      
      unless api_key && search_engine_id
        Rails.logger.error "Google Custom Search API credentials not configured"
        return fallback_search_url(search_query)
      end
      
      # Build the API request URL
      uri = URI("https://www.googleapis.com/customsearch/v1")
      params = {
        key: api_key,
        cx: search_engine_id,
        q: search_query,
        num: 1, # Get only the first result
        safe: 'active'
      }
      uri.query = URI.encode_www_form(params)
      
      # Make the request
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request['Accept'] = 'application/json'
      
      response = http.request(request)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        
        if data['items'] && data['items'].any?
          first_result = data['items'].first
          direct_link = first_result['link']
          
          Rails.logger.info "Google Custom Search successful for '#{search_query}': #{direct_link}"
          return direct_link
        else
          Rails.logger.warn "No search results found for '#{search_query}'"
          return fallback_search_url(search_query)
        end
      else
        Rails.logger.error "Google Custom Search API failed with status: #{response.code}"
        Rails.logger.error "Response body: #{response.body}"
        return fallback_search_url(search_query)
      end
      
    rescue => e
      Rails.logger.error "Error in GoogleCustomSearchService: #{e.message}"
      return fallback_search_url(search_query)
    end
  end
  
  private
  
  def self.fallback_search_url(search_query)
    # Fallback to Google search if API fails
    "https://www.google.com/search?q=#{CGI.escape(search_query)}"
  end
end

