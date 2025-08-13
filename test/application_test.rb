require "test_helper"

class ApplicationTest < ActionDispatch::IntegrationTest
  test "application loads successfully" do
    get root_path
    assert_response :success
  end
end
