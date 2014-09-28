require 'test_helper'

class SiteSessionControllerTest < ActionController::TestCase
  test "should get make_session" do
    get :make_session
    assert_response :success
  end

  test "should get delete_session" do
    get :delete_session
    assert_response :success
  end

end
