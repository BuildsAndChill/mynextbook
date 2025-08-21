#!/usr/bin/env ruby

# Script de test pour vérifier l'envoi d'emails
# Usage: ruby script/test_email_sending.rb

require_relative '../config/environment'

puts "🧪 Test d'envoi d'emails"
puts "========================="

# Vérifier la configuration
puts "\n📋 Configuration actuelle:"
puts "Delivery method: #{ActionMailer::Base.delivery_method}"
puts "SMTP settings: #{ActionMailer::Base.smtp_settings}" if ActionMailer::Base.delivery_method == :smtp
puts "Resend settings: #{ActionMailer::Base.resend_settings}" if ActionMailer::Base.delivery_method == :resend

# Test d'envoi d'email simple
puts "\n📤 Test d'envoi d'email:"
begin
  # Créer un email de test
  test_email = ActionMailer::Base.mail(
    from: ENV.fetch('MAILER_SENDER', 'test@mynextbook.com'),
    to: 'test@example.com',
    subject: 'Test de configuration email',
    body: 'Ceci est un email de test pour vérifier la configuration.'
  )
  
  puts "✅ Email de test créé"
  puts "From: #{test_email.from}"
  puts "To: #{test_email.to}"
  puts "Subject: #{test_email.subject}"
  
  # Envoyer l'email
  puts "\n🚀 Envoi de l'email..."
  result = test_email.deliver_now
  
  puts "✅ Email envoyé avec succès !"
  puts "Résultat: #{result.class}"
  
rescue => e
  puts "❌ Erreur lors de l'envoi: #{e.message}"
  puts "Détails: #{e.backtrace.first(3).join("\n")}"
end

puts "\n✨ Test terminé!"
