include HomeHelper

class HomeController < ApplicationController
  def home
    if user_signed_in?
      sites = current_user.sites

      if sites.empty?
        begin
          create_bitbucket_repository "default"
        rescue BitbucketAPIException
          @status = 400
          @message = "cannot create repository"
          render template: "error/error"
          return
        end

        repo = Git.clone "git@bitbucket.org:#{ENV["BITBUCKET_USER"]}/default.git", "repo/default"
        repo.config "user.name", ENV["BITBUCKET_USER"]
        repo.config "user.email", ENV["BITBUCKET_USER"]

        sites.create! name: "default", urls: ""
        user_session["current_site_name"] = "default"
      end

      @sites = sites.map{ |site| site.name }

      if user_session["current_site_name"].nil?
        user_session["current_site_name"] = @sites[0]
      end

      @site = user_session["current_site_name"]
      site = current_user.sites.find_by name: @site

      @urls = site.urls
      @urls_size = @urls.count("\n") + 1

      @site = user_session["current_site_name"]
    elsif params[:id]
      @id = params[:id]
      @site = @id
      site = Site.find_by name: @id
      @urls = site.urls
      @urls_size = @urls.count("\n") + 1
    end
  end

  def add_site
    current_site_name = params[:site]

    begin
      create_bitbucket_repository current_site_name
    rescue BitbucketAPIException
      @status = 400
      @message = "cannot create repository"
      render template: "error/error"
      return
    end

    repo = Git.clone "git@bitbucket.org:#{ENV["BITBUCKET_USER"]}/#{current_site_name}.git", "repo/#{current_site_name}"
    repo.config "user.name", ENV["BITBUCKET_USER"]
    repo.config "user.email", ENV["BITBUCKET_USER"]

    current_user.sites.create! name: current_site_name, urls: ""
    user_session["current_site_name"] = current_site_name
    redirect_to "/"
  end

  def change_site
    user_session["current_site_name"] = params[:site]
    redirect_to "/"
  end
end
