# Mailgun configuration for ActionMailer
require 'net/http'
require 'uri'
require 'base64'

# Custom delivery method for Mailgun using Net::HTTP
class MailgunDeliveryMethod
  def initialize(settings = {})
    # Read directly from environment variables
    @api_key = ENV['MAILGUN_API_KEY']
    @domain = ENV['MAILGUN_DOMAIN']
    @region = ENV.fetch('MAILGUN_REGION', 'eu')
  end

  def deliver!(mail)
    # Determine API endpoint based on region
    api_host = @region == 'us' ? 'api.mailgun.net' : 'api.eu.mailgun.net'
    uri = URI("https://#{api_host}/v3/#{@domain}/messages")
    
    # Prepare message parameters
    params = {
      'from' => mail.from.first,
      'to' => mail.to.join(','),
      'subject' => mail.subject
    }
    
    # Handle HTML and text content
    if mail.html_part
      params['html'] = mail.html_part.body.to_s
    end
    
    if mail.text_part
      params['text'] = mail.text_part.body.to_s
    elsif !mail.html_part
      params['text'] = mail.body.to_s
    end
    
    # Add CC if present
    params['cc'] = mail.cc.join(',') if mail.cc.present?
    
    # Add BCC if present
    params['bcc'] = mail.bcc.join(',') if mail.bcc.present?
    
    # Send message via Mailgun HTTP API
    begin
      Rails.logger.info "📤 Envoi via Mailgun domain: #{@domain}"
      Rails.logger.info "📤 API URL: #{uri}"
      Rails.logger.info "📤 Message params: #{params.except('html', 'text').inspect}"
      
      # Create HTTP request
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri)
      request.basic_auth('api', @api_key)
      request.set_form_data(params)
      
      # Send request
      response = http.request(request)
      
      if response.code.to_i >= 200 && response.code.to_i < 300
        Rails.logger.info "✅ Email envoyé via Mailgun: #{response.body}"
        response
      else
        Rails.logger.error "❌ Erreur Mailgun HTTP: #{response.body}"
        Rails.logger.error "❌ Status: #{response.code}"
        raise "Mailgun error: #{response.code} - #{response.body}"
      end
      
    rescue => e
      Rails.logger.error "❌ Erreur Mailgun: #{e.message}"
      Rails.logger.error "❌ Domain utilisé: #{@domain}"
      Rails.logger.error "❌ API URL: #{uri}"
      raise e
    end
  end
end

# Register the custom delivery method
ActionMailer::Base.add_delivery_method :mailgun, MailgunDeliveryMethod
