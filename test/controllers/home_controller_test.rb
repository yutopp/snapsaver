require 'test_helper'

class HomeControllerTest < ActionController::TestCase
  include Devise::TestHelpers

  setup do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  test "should get home" do
    get :home
    assert_response :success
  end

  test "shoud get home with login" do
    sign_in FactoryGirl.build(:user)
    get :home
    assert_response :success
  end

end
