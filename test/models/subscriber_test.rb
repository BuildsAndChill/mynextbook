require "test_helper"

class SubscriberTest < ActiveSupport::TestCase
  def setup
    @valid_attributes = {
      email: "test@example.com",
      context: "Je cherche des livres de science-fiction",
      tone_chips: "Aventure, Mystère",
      ai_response: "Voici mes recommandations...",
      parsed_response: { picks: [{ title: "Dune", author: "Frank Herbert" }] }.to_json,
      interaction_count: 1,
      session_id: "session_123"
    }
  end

  test "should create subscriber with valid attributes" do
    subscriber = Subscriber.new(@valid_attributes)
    assert subscriber.save
  end

  test "should require email" do
    subscriber = Subscriber.new(@valid_attributes.except(:email))
    assert_not subscriber.save
    assert_includes subscriber.errors[:email], "can't be blank"
  end

  test "should validate email format" do
    subscriber = Subscriber.new(@valid_attributes.merge(email: "invalid-email"))
    assert_not subscriber.save
    assert_includes subscriber.errors[:email], "is invalid"
  end

  test "should normalize email to lowercase" do
    subscriber = Subscriber.create!(@valid_attributes.merge(email: "TEST@EXAMPLE.COM"))
    assert_equal "test@example.com", subscriber.email
  end

  test "should ensure interaction_count is at least 1" do
    subscriber = Subscriber.new(@valid_attributes.merge(interaction_count: 0))
    subscriber.save
    assert_equal 1, subscriber.interaction_count
  end

  test "should find or create by email" do
    # Première création
    subscriber1 = Subscriber.find_or_create_by_email("new@example.com", @valid_attributes)
    assert subscriber1.persisted?
    assert_equal 1, subscriber1.interaction_count

    # Deuxième appel avec le même email
    subscriber2 = Subscriber.find_or_create_by_email("new@example.com", @valid_attributes.merge(context: "Nouveau contexte"))
    assert_equal subscriber1.id, subscriber2.id
    assert_equal 2, subscriber2.interaction_count
    assert_equal "Nouveau contexte", subscriber2.context
  end

  test "should update context correctly" do
    subscriber = Subscriber.create!(@valid_attributes)
    new_context = "Nouveau contexte de test"
    
    subscriber.update_context({
      context: new_context,
      tone_chips: ["Nouveau", "Contexte"],
      ai_response: "Nouvelle réponse IA"
    })
    
    assert_equal new_context, subscriber.context
    assert_equal "Nouveau, Contexte", subscriber.tone_chips
    assert_equal "Nouvelle réponse IA", subscriber.ai_response
    assert_equal 2, subscriber.interaction_count
  end

  test "should parse preferences correctly" do
    subscriber = Subscriber.create!(@valid_attributes)
    preferences = subscriber.preferences
    
    assert_equal "Je cherche des livres de science-fiction", preferences[:context]
    assert_equal ["Aventure", "Mystère"], preferences[:tone_chips]
    assert_equal ["Dune by Frank Herbert"], preferences[:liked_books]
    assert_equal 1, preferences[:interaction_count]
  end

  test "should determine engagement level correctly" do
    subscriber = Subscriber.create!(@valid_attributes)
    assert_equal "new", subscriber.engagement_level

    subscriber.update!(interaction_count: 5)
    assert_equal "engaged", subscriber.engagement_level

    subscriber.update!(interaction_count: 8)
    assert_equal "very_engaged", subscriber.engagement_level

    subscriber.update!(interaction_count: 15)
    assert_equal "super_engaged", subscriber.engagement_level
  end

  test "should check if subscriber is active" do
    subscriber = Subscriber.create!(@valid_attributes)
    assert subscriber.active?

    # Simuler un subscriber inactif
    subscriber.update!(created_at: 31.days.ago)
    assert_not subscriber.active?
  end

  test "should provide engagement stats" do
    # Créer quelques subscribers de test
    Subscriber.create!(@valid_attributes)
    Subscriber.create!(@valid_attributes.merge(email: "test2@example.com", interaction_count: 3))
    Subscriber.create!(@valid_attributes.merge(email: "test3@example.com", created_at: 31.days.ago))

    stats = Subscriber.engagement_stats
    
    assert_equal 3, stats[:total]
    assert_equal 2, stats[:active_30_days]
    assert_in_delta 2.0, stats[:avg_interactions], 0.5
    assert_includes stats[:top_contexts].keys, "Je cherche des livres de science-fiction"
  end
end
