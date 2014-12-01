require 'rails_helper'

RSpec.describe HomeController, :type => :controller do
  describe "GET #home" do
    it "returns the home page without login" do
      get :home

      expect(response).to have_http_status(200)
      expect(response).to render_template(:home)
    end

    it "returns an orphan URL list page with url_list parameter" do
      url_list = FactoryGirl.create :url_list

      get :home, url_list: url_list.name

      expect(response).to have_http_status(200)
      expect(response).to render_template(:home)

      expect(assigns(:orphan_url_list)).to be_true
      expect(assigns(:url_list_name)).to eq(url_list.name)
      expect(assigns(:urls)).to eq(url_list.urls)
      expect(assigns(:urls_size)).to eq(url_list.urls.count("\n") + 1)
    end

    it "returns an orphan URL list page with url_list parameter even with login" do
      @request.env["devise.mapping"] = Devise.mappings[:user]

      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list = FactoryGirl.create :url_list
      url_list.user = user
      url_list.save

      get :home, url_list: url_list.name

      expect(response).to have_http_status(200)
      expect(response).to render_template(:home)

      expect(assigns(:orphan_url_list)).to be_true
      expect(assigns(:url_list_name)).to eq(url_list.name)
      expect(assigns(:urls)).to eq(url_list.urls)
      expect(assigns(:urls_size)).to eq(url_list.urls.count("\n") + 1)
    end

    it "makes a default URL list with logging in user who have no URL list, and returns the URL list page" do
      @request.env["devise.mapping"] = Devise.mappings[:user]

      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      get :home

      expect(response).to have_http_status(200)
      expect(response).to render_template(:home)

      expect(assigns(:orphan_url_list)).to be_false
      expect(assigns(:url_list_name)).to eq("default")
      expect(assigns(:urls)).to eq("")
      expect(assigns(:urls_size)).to eq(0)

      expect(UrlList.count).to eq(1)
      expect(UrlList.first.name).to eq("default")
      expect(UrlList.urls).to eq("")

      expect(Dir.exist? "repo/#{user.uuid}-default").to be_true
      expect{delete_bitbucket_repository "#{user.uuid}-default"}.not_to raise_error
    end

    it "returns an URL list page with logging in an user who have some URL lists" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list = FactoryGirl.create :url_list
      url_list.user = user
      url_list.save

      get :home

      expect(response).to have_http_status(200)
      expect(response).to render_template(:home)

      expect(assigns(:orphan_url_list)).to be_false
      expect(assigns(:url_list_name)).to eq(url_list.name)
      expect(assigns(:urls)).to eq(url_list.urls)
      expect(assigns(:urls_size)).to eq(url_list.urls.count("\n") + 1)
    end
  end
end
