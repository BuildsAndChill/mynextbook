# app/services/book_recommender.rb
require "openai"

class BookRecommender
  def initialize(context:, include_readings: true, user: nil)
    @context = context
    @user = user
    @include_readings = include_readings
  end

  def call
    # 1️⃣ Récupération des lectures depuis la base (full import)
    readings = @include_readings ? Reading.all : []

    # 2️⃣ Construction du méga prompt

    prompt = <<~PROMPT
      Contexte utilisateur :
      #{@context.presence || "(non fourni)"}

      #{if @include_readings && readings.any?
          "Livres déjà lus :\n" +
          readings.map { |r| "#{r.title} – #{r.author}" }.join("\n")
        else
          "(Aucun historique de lecture inclus)"
        end}

      # 🎯 Tâche
      En tenant compte du contexte#{' et des livres déjà lus' if @include_readings}, propose-moi de nouvelles lectures pertinentes.
    PROMPT

    # 3️⃣ Appel OpenAI
    ai_raw = nil
    ai_error = nil

    begin
      client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
      response = client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.7
        }
      )
      ai_raw = response.dig("choices", 0, "message", "content")
    rescue => e
      ai_error = e.message
    end

    # 4️⃣ Retour complet pour la vue
    {
      raw: ai_raw,
      items: [], # parsing optionnel
      error: ai_error,
      prompt_debug: prompt
    }
  end
end
