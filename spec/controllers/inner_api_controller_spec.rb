require 'rails_helper'

RSpec.describe InnerApiController, :type => :controller do
  before(:each) do
    @url_list = FactoryGirl.create(:url_list)
  end

  context "User doesn't login," do
    describe "POST #make_id" do
      it "makes new url_list and bitbucket repository" do
        post :make_id

        expect(response).to have_http_status(302)
        expect(UrlList.count).to eq(2)

        url_list_name = UrlList.last.name

        expect(url_list_name).to match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/)
        expect{ delete_bitbucket_repository url_list_name }.not_to raise_error
      end
    end

    describe "POST #save_urls" do
      it "saves URL into Database" do
        post :save_urls
        expect(response).to have_http_status(400)
        expect(JSON.parse(@response.body)["error"]).to eq("URL list not specified")

        post :save_urls, list_name: @url_list.name, urls: "http://www.example.com\nhttps://www.google.com\nfile:///etc/passwd"
        expect(response).to have_http_status(200)
        expect(@url_list.urls).to eq("http://www.example.com\nhttps://www.google.com")
      end
    end

    describe "POST #shoot" do
      it "takes snapshot and saves them to the url_list's repository" do
        Dir.mkdir "repo/#{@url_list.name}"

        begin
          post :shoot
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("URL list not specified")

          post :shoot, list_name: @url_list.name + "oops", index: "0", breakpoint: "lg"
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("URL list not found")

          post :shoot, list_name: @url_list.name, index: "-1", breakpoint: "lg"
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("index out of range")

          post :shoot, list_name: @url_list.name, index: "0", breakpoint: "all"
          expect(response).to have_http_status(200)

          post :shoot, list_name: @url_list.name, index: "1", breakpoint: "lg"
          expect(response).to have_http_status(200)

          post :shoot, list_name: @url_list.name, index: "2", breakpoint: "lg"
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("index out of range")

          @url_list.urls = ""
          @url_list.save

          post :shoot, list_name: @url_list.name, index: "0", breakpoint: "lg"
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("empty URL list")
        ensure
          FileUtils.rm_rf "repo/#{@url_list.name}"
        end
      end
    end

    describe "POST #push_repository" do
      it "pushes contents in repository to bitbucket" do
        create_bitbucket_repository @url_list.name
        repository = Git.clone "git@bitbucket.org:snapsaver/#{@url_list.name}.git", "repo/#{@url_list.name}"
        repository.config "user.name", ENV["BITBUCKET_USER"]
        repository.config "user.email", ENV["BITBUCKET_USER"]

        begin
          post :push_repository
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("URL list not specified")

          post :push_repository, list_name: @url_list.name + "salt"
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("URL list not found")

          post :push_repository, list_name: @url_list.name, commit_message: ""
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("no changes in URLs")

          File.open "repo/#{@url_list.name}/piyo", "w" do end

          post :push_repository, list_name: @url_list.name, commit_message: ""
          expect(response).to have_http_status(200)

          post :push_repository, list_name: @url_list.name, commit_message: ""
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("no changes in URLs")

          File.open "repo/#{@url_list.name}/fuga", "w" do end

          post :push_repository, list_name: @url_list.name, commit_message: "this is a pen"
          expect(response).to have_http_status(200)
        ensure
          FileUtils.rm_rf "repo/#{@url_list.name}"
          delete_bitbucket_repository @url_list.name
        end
      end
    end
  end

  context "An user login," do
    before(:each) do
      @request.env["devise.mapping"] = Devise.mappings[:user]

      @user = FactoryGirl.create :user
      @user.confirm!
      sign_in @user

      @url_list.user = @user
      @url_list.save
    end

    describe "POST #make_id" do
      it "fails when sign in" do
        @user.confirm!
        sign_in @user

        post :make_id

        expect(response).to have_http_status(400)
        expect(JSON.parse(@response.body)["error"]).to eq("should not log in")
      end
    end

    describe "POST #save_urls" do
      it "saves URL into Database" do
        post :save_urls
        expect(response).to have_http_status(400)
        expect(JSON.parse(@response.body)["error"]).to eq("URL list not specified")

        post :save_urls, list_name: @url_list.name, urls: "http://www.example.com\nhttps://www.google.com\nfile:///etc/passwd"
        expect(response).to have_http_status(200)
        expect(@url_list.urls).to eq("http://www.example.com\nhttps://www.google.com")
      end
    end

    describe "POST #shoot" do
      it "takes snapshot and saves them to the url_list's repository" do
        Dir.mkdir "repo/#{@user.uuid}-#{@url_list.name}"

        begin
          post :shoot
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("URL list not specified")

          post :shoot, list_name: @url_list.name + "oops", index: "0", breakpoint: "lg"
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("URL list not found")

          post :shoot, list_name: @url_list.name, index: "-1", breakpoint: "lg"
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("index out of range")

          post :shoot, list_name: @url_list.name, index: "0", breakpoint: "lg"
          expect(response).to have_http_status(200)

          post :shoot, list_name: @url_list.name, index: "1", breakpoint: "all"
          expect(response).to have_http_status(200)

          post :shoot, list_name: @url_list.name, index: "2", breakpoint: "lg"
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("index out of range")

          @url_list.urls = ""
          @url_list.save

          post :shoot, list_name: @url_list.name, index: "0", breakpoint: "lg"
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("empty URL list")
        ensure
          FileUtils.rm_rf "repo/#{@user.uuid}-#{@url_list.name}"
        end
      end
    end

    describe "POST #push_repository" do
      it "pushes contents in repository to bitbucket" do
        create_bitbucket_repository "#{@user.uuid}-#{@url_list.name}"
        repository = Git.clone "git@bitbucket.org:snapsaver/#{@user.uuid}-#{@url_list.name}.git", "repo/#{@user.uuid}-#{@url_list.name}"
        repository.config "user.name", ENV["BITBUCKET_USER"]
        repository.config "user.email", ENV["BITBUCKET_USER"]

        begin
          post :push_repository
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("URL list not specified")

          post :push_repository, list_name: @url_list.name + "salt"
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("URL list not found")

          post :push_repository, list_name: @url_list.name, commit_message: ""
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("no changes in URLs")

          File.open "repo/#{@user.uuid}-#{@url_list.name}/piyo", "w" do end

          post :push_repository, list_name: @url_list.name, commit_message: ""
          expect(response).to have_http_status(200)

          post :push_repository, list_name: @url_list.name, commit_message: ""
          expect(response).to have_http_status(400)
          expect(JSON.parse(@response.body)["error"]).to eq("no changes in URLs")

          File.open "repo/#{@user.uuid}-#{@url_list.name}/fuga", "w" do end

          post :push_repository, list_name: @url_list.name, commit_message: "this is a pen"
          expect(response).to have_http_status(200)
        ensure
          FileUtils.rm_rf "repo/#{@user.uuid}-#{@url_list.name}"
          delete_bitbucket_repository "#{@user.uuid}-#{@url_list.name}"
        end
      end
    end
  end
end
