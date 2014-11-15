require 'test_helper'

class InnerApiControllerTest < ActionController::TestCase
  include Devise::TestHelpers
  include InnerApiHelper

  self.test_order = :defined

  sub_test_case "未ログイン時" do
    test "make_id" do
      post :make_id

      assert_response :bad_request
    end

    test "save_urls" do
      post :save_urls

      assert_response :bad_request
    end

    test "shoot" do
      post :shoot

      assert_response :bad_request
    end

    test "push_repository" do
      post :push_repository

      assert_response :bad_request
    end
  end

  sub_test_case "IDリスト表示時" do
    setup do
      url_list = FactoryGirl.create :url_list
      user_session["current_url_list_name"] = url_list.name
    end

    test "make_id" do
      post :make_id

      assert_response :bad_request
    end

    test "save_urls" do
      post :save_urls, urls: "http://www.example.com\nhttps://www.google.com\nfile:///etc/passwd"

      assert_response :success
      assert_equal URLList.find_by(name: FactoryGirl.attributes_for(:url_list)[:name]), "http://www.example.com\nhttps://www.google.com"
    end

    test "shoot" do
      Dir.mkdir "repo/"
    end

    test "push_repository" do
    end
  end

  sub_test_case "ログイン時" do
    setup do
      sign_in FactoryGirl.build(:user)
    end

    test "make_id" do
      sign_in FactoryGirl.build(:user)

      post :make_id

      assert_response :redirect
      assert_equal URLList.count, 1

      name = URLList.first.name

      assert_match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/, name)
      assert_nothing_raised do
        delete_bitbucket_repository name
      end
    end
  end


end
