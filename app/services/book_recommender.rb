# app/services/book_recommender.rb
require "openai"

class BookRecommender
  def initialize(context:, user: nil)
    @context = context
    @user = user
  end

  def call
    # 1️⃣ Récupération des lectures depuis la base (full import)
    readings = Reading.all

    # 2️⃣ Construction du méga prompt
    prompt = <<~PROMPT
      Contexte utilisateur :
      #{@context.presence || "(non fourni)"}

      Livres déjà lus :
      #{readings.map { |r| "#{r.title} – #{r.author}" }.join("\n")}

      # 🎯 Tâche
      En tenant compte du contexte et des livres déjà lus, propose-moi de nouvelles lectures pertinentes.
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
