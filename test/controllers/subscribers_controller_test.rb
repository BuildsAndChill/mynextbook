require "test_helper"

class SubscribersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @valid_email = "test@example.com"
    @invalid_email = "invalid-email"
    @session_id = "test_session_123"
  end

  test "should create subscriber with valid email" do
    assert_difference('Subscriber.count') do
      post subscribers_path, params: { 
        email: @valid_email, 
        session_id: @session_id 
      }, as: :json
    end

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal 'Parfait ! Tu recevras tes prochaines découvertes par email.', json_response['message']
    assert_equal @valid_email, json_response['subscriber']['email']
    assert_equal 1, json_response['subscriber']['interaction_count']
  end

  test "should not create subscriber with invalid email" do
    assert_no_difference('Subscriber.count') do
      post subscribers_path, params: { 
        email: @invalid_email, 
        session_id: @session_id 
      }, as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response['success']
    assert_includes json_response['error'], 'invalide'
  end

  test "should update existing subscriber" do
    # Créer un subscriber existant
    existing_subscriber = Subscriber.create!(
      email: @valid_email,
      context: "Ancien contexte",
      interaction_count: 1,
      session_id: @session_id
    )

    assert_no_difference('Subscriber.count') do
      post subscribers_path, params: { 
        email: @valid_email, 
        session_id: @session_id 
      }, as: :json
    end

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal 2, json_response['subscriber']['interaction_count']
    
    # Vérifier que le subscriber a été mis à jour
    existing_subscriber.reload
    assert_equal 2, existing_subscriber.interaction_count
  end

  test "should handle missing email parameter" do
    assert_no_difference('Subscriber.count') do
      post subscribers_path, params: { 
        session_id: @session_id 
      }, as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response['success']
  end

  test "should use session id from params or generate one" do
    # Test avec session_id fourni
    post subscribers_path, params: { 
      email: @valid_email, 
      session_id: "custom_session_123" 
    }, as: :json
    
    assert_response :success
    subscriber = Subscriber.last
    assert_equal "custom_session_123", subscriber.session_id

    # Test sans session_id (doit utiliser session.id)
    post subscribers_path, params: { 
      email: "another@example.com"
    }, as: :json
    
    assert_response :success
    subscriber = Subscriber.last
    assert_not_nil subscriber.session_id
  end
end
