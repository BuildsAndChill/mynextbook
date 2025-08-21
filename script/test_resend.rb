#!/usr/bin/env ruby

# Script de test pour vérifier la configuration Resend
# Usage: ruby script/test_resend.rb

require_relative '../config/environment'

puts "🧪 Test de la configuration Resend"
puts "=================================="

# Vérifier les variables d'environnement
puts "\n📋 Variables d'environnement:"
puts "RESEND_API_KEY: #{ENV['RESEND_API_KEY'] ? '✅ Définie' : '❌ Non définie'}"
puts "RESEND_DOMAIN: #{ENV['RESEND_DOMAIN'] ? '✅ Définie' : '❌ Non définie'}"

# Vérifier la configuration ActionMailer
puts "\n📧 Configuration ActionMailer:"
puts "Delivery method: #{ActionMailer::Base.delivery_method}"
puts "SMTP settings: #{ActionMailer::Base.smtp_settings}" if ActionMailer::Base.delivery_method == :smtp
puts "Resend settings: #{ActionMailer::Base.resend_settings}" if ActionMailer::Base.delivery_method == :resend

# Vérifier que la gem Resend est disponible
puts "\n🔧 Gem Resend:"
begin
  require 'resend'
  puts "✅ Gem Resend chargée avec succès"
  puts "Version: #{Resend::VERSION}"
rescue LoadError => e
  puts "❌ Erreur lors du chargement de Resend: #{e.message}"
end

# Test de création d'un client Resend (si API key disponible)
if ENV['RESEND_API_KEY'].present?
  puts "\n🚀 Test de création du client Resend:"
  begin
    resend = Resend::Client.new(api_key: ENV['RESEND_API_KEY'])
    puts "✅ Client Resend créé avec succès"
    
    # Test d'envoi d'email (optionnel, commenté pour éviter l'envoi réel)
    # puts "\n📤 Test d'envoi d'email (simulation):"
    # puts "✅ Configuration prête pour l'envoi d'emails"
    
  rescue => e
    puts "❌ Erreur lors de la création du client Resend: #{e.message}"
  end
else
  puts "\n⚠️ RESEND_API_KEY non définie, impossible de tester le client"
end

puts "\n✨ Test terminé!"
