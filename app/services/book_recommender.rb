# app/services/book_recommender.rb
class BookRecommender
  def initialize(user_prompt:)
    @user_prompt = user_prompt
  end

  def call
    return mock_response if ENV["AI_DISABLED"] == "1"

    # Exemple OpenAI Ruby SDK v4+ (adapte si tu utilises un autre client)
    client = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
    system_instructions = <<~SYS
      (colle ici le System prompt ci-dessus)
    SYS

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: system_instructions },
          { role: "user",   content: @user_prompt.truncate(6000) }
        ],
        temperature: 0.7,
        max_tokens: 800
      }
    )

    text = response.dig("choices", 0, "message", "content").to_s
    parse_markdown(text)
  rescue => e
    Rails.logger.error("[BookRecommender] #{e.class}: #{e.message}")
    { items: [], raw: nil, error: e.message }
  end

  private

  # Parser simple pour le format Markdown imposé
  def parse_markdown(text)
    items = []
    block = nil

    text.each_line do |line|
      line = line.strip
      # Ligne titre-auteur
      if line.start_with?("- **") && line.end_with?("**")
        items << block if block
        title_author = line.sub(/^- \*\*(.+)\*\*$/, "\\1")
        block = { title_author: title_author, justification: "", tags: [] }
      elsif line.start_with?("*Tags :") && block
        tags = line.sub("*Tags :", "").strip
        tags = tags.gsub(/\*$/, "").strip
        # Split par espaces sur #tag
        block[:tags] = tags.scan(/#\S+/)
      elsif block && !line.start_with?("###")
        # accumulate justification (2–3 phrases)
        block[:justification] << (block[:justification].present? ? " " : "") + line
      end
    end
    items << block if block

    { items: items.compact, raw: text, error: nil }
  end

  def mock_response
    sample = <<~MD
      ### Recommandations
      - **Le Maître et Marguerite – Mikhaïl Boulgakov**
        Fantaisie satirique et réflexion métaphysique : parfait si tu veux un roman riche qui bouscule. Le rythme alterne scènes enlevées et profondeur littéraire, ce qui rafraîchit après des lectures techniques.
        *Tags : #classique #satire #fantastique #philosophie*

      - **Project Hail Mary – Andy Weir**
        Hard-SF accessible, énigmes scientifiques et tension constante : idéal pour un esprit d’ingénieur en quête d’évasion intelligente. La narration te garde en haleine tout en restant crédible.
        *Tags : #sciencefiction #hardSF #survie #pageTurner*

      - **The Undoing Project – Michael Lewis**
        Non-fiction brillante sur les biais cognitifs (Kahneman/Tversky) avec un storytelling exemplaire. Tu y trouveras des parallèles utiles pour l’investissement et la prise de décision.
        *Tags : #psychologie #decision #nonfiction #behavioral*
    MD
    parse_markdown(sample)
  end
end
