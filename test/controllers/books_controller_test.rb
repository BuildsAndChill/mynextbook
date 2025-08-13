require "test_helper"

class BooksControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get books_path
    assert_response :redirect # Redirect to login
  end

  test "should get new" do
    get new_book_path
    assert_response :redirect # Redirect to login
  end
end
