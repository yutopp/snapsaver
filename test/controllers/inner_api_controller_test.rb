require 'test_helper'

class InnerApiControllerTest < ActionController::TestCase
  test "should get save_urls" do
    get :save_urls
    assert_response :success
  end

  test "should get shoot" do
    get :shoot
    assert_response :success
  end

  test "should get push_repository" do
    get :push_repository
    assert_response :success
  end

end
