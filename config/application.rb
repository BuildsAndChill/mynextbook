require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MyNextBook
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    
    # Debug des variables d'environnement au runtime
    config.after_initialize do
      puts "🔍 DEBUG Runtime - Variables d'environnement:"
      puts "  - RAILS_ENV: #{ENV['RAILS_ENV'].inspect}"
      puts "  - RESEND_API_KEY: #{ENV['RESEND_API_KEY'] ? '✅ Définie' : '❌ Non définie'}"
      puts "  - RESEND_DOMAIN: #{ENV['RESEND_DOMAIN'].inspect}"
      puts "  - MAILER_SENDER: #{ENV['MAILER_SENDER'].inspect}"
      puts "  - ActionMailer delivery_method: #{ActionMailer::Base.delivery_method}"
      puts "  - ActionMailer resend_settings: #{ActionMailer::Base.resend_settings.inspect}"
    end

  end
end
