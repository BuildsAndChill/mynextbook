#!/usr/bin/env ruby

# Script de test direct de l'API Resend
# Usage: ruby script/test_resend_direct.rb

require_relative '../config/environment'
require 'resend'

puts "🧪 Test direct de l'API Resend"
puts "==============================="

# Vérifier les variables d'environnement
puts "\n📋 Variables d'environnement:"
puts "RESEND_API_KEY: #{ENV['RESEND_API_KEY'] ? '✅ Définie' : '❌ Non définie'}"
puts "RESEND_DOMAIN: #{ENV['RESEND_DOMAIN'] ? '✅ Définie' : '❌ Non définie'}"

# Vérifier la gem
puts "\n🔧 Gem Resend:"
puts "Version: #{Resend::VERSION}"
puts "Gem path: #{Gem.loaded_specs['resend'].full_gem_path}"

# Test de création du client avec différentes approches
api_key = ENV['RESEND_API_KEY']
puts "\n🚀 Test de création du client:"
puts "API Key: #{api_key}"
puts "Type: #{api_key.class}"
puts "Length: #{api_key.length}"

# Test 1: Méthode directe
begin
  puts "\nTentative 1: Resend::Client.new"
  client = Resend::Client.new(api_key)
  puts "✅ Client créé avec succès"
  
  # Test d'envoi d'email
  puts "\n📤 Test d'envoi d'email:"
  response = Resend::Emails.send({
    from: "test@#{ENV.fetch('RESEND_DOMAIN', 'mynextbook.com')}",
    to: "test@example.com",
    subject: "Test direct Resend",
    html: "<p>Ceci est un test direct de l'API Resend</p>"
  })
  
  puts "✅ Email envoyé avec succès!"
  puts "Response: #{response.inspect}"
  
rescue => e
  puts "❌ Erreur: #{e.message}"
  puts "Class: #{e.class}"
  puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
end

puts "\n✨ Test terminé!"
