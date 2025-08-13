# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store, 
  key: '_my_next_book_session',
  expire_after: 15.minutes,
  secure: Rails.env.production?,
  same_site: :lax

# Limit session data size to prevent CookieOverflow
Rails.application.config.session_options[:expire_after] = 15.minutes
Rails.application.config.session_options[:secure] = Rails.env.production?
