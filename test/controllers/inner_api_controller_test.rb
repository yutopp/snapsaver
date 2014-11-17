require 'test_helper'
require 'fileutils'

class InnerApiControllerTest < ActionController::TestCase
  include Devise::TestHelpers
  include InnerApiHelper

  self.test_order = :defined

  sub_test_case "未ログイン時" do
    test "make_id" do
      post :make_id

      assert_response :redirect
      assert_equal UrlList.count, 1

      name = UrlList.first.name

      assert_match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/, name)
      assert_nothing_raised do
        delete_bitbucket_repository name
      end
    end

    test "save_urls" do
      post :save_urls

      assert_response :bad_request
      assert_equal JSON.parse(@response.body)["error"], "invalid session"
    end

    test "shoot" do
      post :shoot

      assert_response :bad_request
      assert_equal JSON.parse(@response.body)["error"], "invalid session"
    end

    test "push_repository" do
      post :push_repository

      assert_response :bad_request
      assert_equal JSON.parse(@response.body)["error"], "invalid session"
    end
  end

  sub_test_case "IDリスト表示時" do
    setup do
      FactoryGirl.create :url_list
    end

    test "make_id" do
      # 絶対に呼ばれないはず
    end

    test "save_urls" do
      post :save_urls, id: "hoge_list", urls: "http://www.example.com\nhttps://www.google.com\nfile:///etc/passwd"

      assert_response :success
      assert_equal UrlList.find_by(name: FactoryGirl.attributes_for(:url_list)[:name]).urls, "http://www.example.com\nhttps://www.google.com"
    end

    test "shoot" do
      Dir.mkdir "repo/hoge_list"

      post :shoot, id: "hoge_list", index: "-1", breakpoint: "lg"
      assert_response :bad_request
      assert_equal JSON.parse(@response.body)["error"], "index out of range"

      post :shoot, id: "hoge_list", index: "0", breakpoint: "lg"
      assert_response :success

      post :shoot, id: "hoge_list", index: "1", breakpoint: "lg"
      assert_response :success

      post :shoot, id: "hoge_list", index: "2", breakpoint: "lg"
      assert_response :bad_request
      assert_equal JSON.parse(@response.body)["error"], "index out of range"

      FileUtils.rm_rf "repo/hoge_list"
    end

    test "push_repository" do
      create_bitbucket_repository "hoge_list"
      Git.clone "git@bitbucket.org:snapsaver/hoge_list.git", "repo/hoge_list"

      post :push_repository, id: "hoge_list", commit_message: ""
      assert_response :bad_request
      assert_equal JSON.parse(@response.body)["error"], "no changes in URLs"

      File.open "repo/hoge_list/piyo", "w" do end

      post :push_repository, id: "hoge_list", commit_message: ""
      assert_response :success

      FileUtils.rm_rf "repo/hoge_list"
      delete_bitbucket_repository "hoge_list"
    end
  end

  sub_test_case "ログイン時" do
    setup do
      user = FactoryGirl.create(:user)
      url_list = FactoryGirl.create(:url_list)

      url_list.user = user

      sign_in user
    end

    test "make_id" do
      post :make_id

      assert_response :bad_request
      assert_equal JSON.parse(@response.body)["error"], "invalid session"
    end

    test "save_urls" do
      post :save_urls, urls: "http://www.example.com\nhttps://www.google.com\nfile:///etc/passwd"

      assert_response :success
      assert_equal User.find_by(email: FactoryGirl.attributes_for(:user)[:email]).url_lists.find_by(name: FactoryGirl.attributes_for(:url_list)[:name]).urls, "http://www.example.com\nhttps://www.google.com"
    end

    test "shoot" do
      Dir.mkdir "repo/this-is-uuid-hoge_list"

      post :save_urls, id: "hoge_list", index: "-1", breakpoint: "lg"
      assert_response :bad_request

      post :save_urls, id: "hoge_list", index: "0", breakpoint: "lg"
      assert_response :success

      post :save_urls, id: "hoge_list", index: "1", breakpoint: "lg"
      assert_response :success

      post :save_urls, id: "hoge_list", index: "2", breakpoint: "lg"
      assert_response :bad_request

      FileUtils.rm_rf "repo/this-is-uuid-hoge_list"
    end

    test "push_repository" do
      Dir.mkdir "repo/this-is-uuid-hoge_list"

      post :push_repository
      assert_response :bad_request

      File.open "repo/this-is-uuid-hoge_list/piyo", "w" do end

      post :push_repository
      assert_response :success

      FileUtils.rm_rf "repo/this-is-uuid-hoge_list"
    end
  end
end
