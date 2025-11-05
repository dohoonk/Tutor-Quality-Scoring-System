require "test_helper"

class TutorsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get tutors_show_url
    assert_response :success
  end
end
