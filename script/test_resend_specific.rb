#!/usr/bin/env ruby

# Script de test spécifique pour Resend
# Usage: ruby script/test_resend_specific.rb

require_relative '../config/environment'

puts "🧪 Test spécifique Resend"
puts "========================="

# Vérifier les variables d'environnement Resend
puts "\n📋 Variables d'environnement Resend:"
puts "RESEND_API_KEY: #{ENV['RESEND_API_KEY'] ? '✅ Définie' : '❌ Non définie'}"
puts "RESEND_API_KEY type: #{ENV['RESEND_API_KEY'].class}"
puts "RESEND_API_KEY length: #{ENV['RESEND_API_KEY'].to_s.length}"
puts "RESEND_API_KEY preview: #{ENV['RESEND_API_KEY'].to_s[0..10]}..."
puts "RESEND_DOMAIN: #{ENV['RESEND_DOMAIN'] ? '✅ Définie' : '❌ Non définie'}"

# Vérifier que la gem Resend est disponible
puts "\n🔧 Gem Resend:"
begin
  require 'resend'
  puts "✅ Gem Resend chargée avec succès"
  puts "Version: #{Resend::VERSION}"
rescue LoadError => e
  puts "❌ Erreur lors du chargement de Resend: #{e.message}"
  exit 1
end

# Test de création du client Resend
puts "\n🚀 Test de création du client Resend:"
begin
  # Debug de la clé API
  api_key = ENV['RESEND_API_KEY']
  puts "API Key raw: '#{api_key}'"
  puts "API Key inspect: #{api_key.inspect}"
  puts "API Key bytes: #{api_key.bytes}"
  
  # Test avec différentes méthodes
  puts "\nTentative 1: Client.new avec api_key direct:"
  resend = Resend::Client.new(api_key)
  puts "✅ Client Resend créé avec succès (méthode 1)"
  
rescue => e
  puts "❌ Erreur méthode 1: #{e.message}"
  
  begin
    puts "\nTentative 2: Client.new avec string explicite:"
    resend = Resend::Client.new(api_key.to_s)
    puts "✅ Client Resend créé avec succès (méthode 2)"
  rescue => e2
    puts "❌ Erreur méthode 2: #{e2.message}"
    
    begin
      puts "\nTentative 3: Client.new avec string nettoyée:"
      resend = Resend::Client.new(api_key.to_s.strip)
      puts "✅ Client Resend créé avec succès (méthode 3)"
    rescue => e3
      puts "❌ Erreur méthode 3: #{e3.message}"
      puts "❌ Impossible de créer le client Resend"
      exit 1
    end
  end
end

# Forcer la configuration ActionMailer pour utiliser Resend
puts "\n📧 Configuration ActionMailer pour Resend:"
ActionMailer::Base.delivery_method = :resend
ActionMailer::Base.resend_settings = {
  api_key: ENV['RESEND_API_KEY'],
  domain: ENV.fetch('RESEND_DOMAIN', 'mynextbook.com')
}

puts "✅ ActionMailer configuré pour Resend"
puts "Delivery method: #{ActionMailer::Base.delivery_method}"
puts "Resend settings: #{ActionMailer::Base.resend_settings}"

# Test d'envoi d'email via Resend
puts "\n📤 Test d'envoi d'email via Resend:"
begin
  # Créer un email de test
  test_email = ActionMailer::Base.mail(
    from: "test@#{ENV.fetch('RESEND_DOMAIN', 'mynextbook.com')}",
    to: 'test@example.com',
    subject: 'Test Resend - Configuration email',
    body: 'Ceci est un email de test envoyé via Resend pour vérifier la configuration.'
  )
  
  puts "✅ Email de test créé"
  puts "From: #{test_email.from}"
  puts "To: #{test_email.to}"
  puts "Subject: #{test_email.subject}"
  
  # Envoyer l'email via Resend
  puts "\n🚀 Envoi de l'email via Resend..."
  result = test_email.deliver_now
  
  puts "✅ Email envoyé avec succès via Resend !"
  puts "Résultat: #{result.class}"
  
rescue => e
  puts "❌ Erreur lors de l'envoi via Resend: #{e.message}"
  puts "Détails: #{e.backtrace.first(3).join("\n")}"
end

puts "\n✨ Test Resend terminé!"
