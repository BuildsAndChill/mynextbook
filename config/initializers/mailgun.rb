# Mailgun configuration for ActionMailer (COMMENTÉ - migration vers Resend)
# require 'mailgun-ruby'

# Custom delivery method for Mailgun (COMMENTÉ)
# class MailgunDeliveryMethod
#   def initialize(settings)
#     @api_key = settings[:api_key]
#     @domain = settings[:domain]
#     @region = settings[:region] || 'eu'
#   end

#   def deliver!(mail)
#     # Create Mailgun client
#     mg_client = Mailgun::Client.new(@api_key, @region)
    
#     # Prepare message parameters
#     message_params = {
#       from: mail.from.first,
#       to: mail.to,
#       subject: mail.subject,
#       html: mail.html_part&.body&.to_s || mail.body.to_s,
#       text: mail.text_part&.body&.to_s || mail.body.to_s
#     }
    
#     # Add CC if present
#     message_params[:cc] = mail.cc if mail.cc.present?
    
#     # Add BCC if present
#     message_params[:bcc] = mail.bcc if mail.bcc.present?
    
#     # Send message via Mailgun
#     begin
#       result = mg_client.messages.create(@domain, message_params)
#       Rails.logger.info "✅ Email envoyé via Mailgun: #{result['id']}"
#       result
#     rescue => e
#       Rails.logger.error "❌ Erreur Mailgun: #{e.message}"
#       raise e
#     end
#   end
# end

# Register the custom delivery method (COMMENTÉ)
# ActionMailer::Base.add_delivery_method :mailgun, MailgunDeliveryMethod
