#!/usr/bin/env ruby

# Script de test pour vérifier que l'initializer Resend est chargé
# Usage: ruby script/test_initializer.rb

require_relative '../config/environment'

puts "🧪 Test de l'initializer Resend"
puts "==============================="

# Vérifier que la méthode de livraison est enregistrée
puts "\n📧 Méthodes de livraison disponibles:"
puts ActionMailer::Base.delivery_methods.inspect

# Vérifier la configuration actuelle
puts "\n🔧 Configuration ActionMailer:"
puts "Delivery method: #{ActionMailer::Base.delivery_method}"
puts "Resend settings: #{ActionMailer::Base.resend_settings}" if ActionMailer::Base.respond_to?(:resend_settings)

# Vérifier que notre classe est définie
puts "\n🔍 Classes définies:"
puts "ResendDeliveryMethod défini: #{defined?(ResendDeliveryMethod)}"
puts "ResendDeliveryMethod class: #{ResendDeliveryMethod.class}" if defined?(ResendDeliveryMethod)

# Vérifier la configuration Resend
puts "\n🔑 Configuration Resend:"
puts "Resend.api_key défini: #{Resend.respond_to?(:api_key) && Resend.api_key.present?}"
puts "ENV['RESEND_API_KEY']: #{ENV['RESEND_API_KEY'] ? '✅ Définie' : '❌ Non définie'}"

puts "\n✨ Test terminé!"
