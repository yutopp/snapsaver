require 'test_helper'

class LatestImagesControllerTest < ActionController::TestCase
  test "should get latest_images" do
    get :latest_images
    assert_response :success
  end

end
