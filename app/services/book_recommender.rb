# app/services/book_recommender.rb
require "openai"

class BookRecommender
  def initialize
    # Initialize without parameters for backward compatibility
  end

  def get_recommendation(prompt)
    # Use the provided prompt directly
    call_with_prompt(prompt)
  end

  private

  def call_with_prompt(prompt)
    # Check if AI is disabled (for testing/mock mode)
    if ENV["AI_DISABLED"] == "1"
      Rails.logger.info "AI_DISABLED=1, returning mock response"
      return generate_mock_response(prompt)
    end

    # Check if OpenAI API key is present
    unless ENV["OPENAI_API_KEY"].present?
      Rails.logger.error "OPENAI_API_KEY not found in environment"
      raise "OpenAI API key not configured. Please set OPENAI_API_KEY environment variable."
    end

    # 3️⃣ Appel OpenAI
    ai_raw = nil
    ai_error = nil

    begin
      Rails.logger.info "Calling OpenAI API with prompt length: #{prompt.length}"
      client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
      response = client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.7
        }
      )
      ai_raw = response.dig("choices", 0, "message", "content")
      Rails.logger.info "OpenAI API call successful, response length: #{ai_raw&.length || 0}"
    rescue => e
      Rails.logger.error "OpenAI API call failed: #{e.message}"
      ai_error = e.message
    end

    # Return the raw response or error
    if ai_error
      raise ai_error
    else
      ai_raw
    end
  end

  def generate_mock_response(prompt)
    # Generate a mock response that follows the expected format
    mock_response = <<~MOCK
      BRIEF:
      What you tend to like:
      - Engaging narratives that blend multiple disciplines
      - Books that challenge conventional thinking
      - Authors who can make complex topics accessible

      What to explore next:
      - Interdisciplinary approaches to big questions
      - Books that bridge science and humanities
      - Authors from diverse backgrounds and perspectives

      Pitfalls to avoid:
      - Overly technical books without narrative structure
      - Books that oversimplify complex topics

      TOP PICKS:
      1. The Gene: An Intimate History by Siddhartha Mukherjee
      Pitch: A masterful blend of science, history, and personal narrative that makes genetics accessible and compelling.
      Why: Combines your interest in science with engaging storytelling, similar to Sapiens
      Confidence: High

      2. The Sixth Extinction: An Unnatural History by Elizabeth Kolbert
      Pitch: A compelling exploration of human impact on the natural world, written with journalistic clarity.
      Why: Addresses big questions about humanity's role, matching your preference for thought-provoking content
      Confidence: High

      3. The Hidden Life of Trees by Peter Wohlleben
      Pitch: A fascinating look at forest ecology that reads like a nature documentary in book form.
      Why: Offers a different perspective on familiar topics, expanding your reading horizons
      Confidence: Medium
    MOCK

    Rails.logger.info "Generated mock response for testing"
    mock_response
  end
end
