include HomeHelper

require "securerandom"

class HomeController < ApplicationController
  def home
    if user_signed_in?
      sites = current_user.sites

      if sites.empty?
        begin
          uuid = SecureRandom.uuid
          current_user.uuid = uuid
          current_user.save!

          create_bitbucket_repository "#{uuid}-default"
        rescue BitbucketAPIException
          @status = 400
          @message = "cannot create repository"
          render template: "error/error"
          return
        end

        repo = Git.clone "git@bitbucket.org:#{ENV["BITBUCKET_USER"]}/#{uuid}-default.git", "repo/#{uuid}-default"
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

      @uuid = current_user.uuid
    elsif params[:id]
      @id = params[:id]
      @site = @id
      site = Site.find_by name: @id
      @urls = site.urls
      @urls_size = @urls.count("\n") + 1
    end

    @breakpoints = BREAKPOINTS
  end

  def add_site
    adding_site_name = params[:site]
    uuid = current_user.uuid

    begin
      create_bitbucket_repository uuid + "-" + adding_site_name
    rescue BitbucketAPIException
      @status = 400
      @message = "cannot create repository"
      render template: "error/error"
      return
    end

    repo = Git.clone "git@bitbucket.org:#{ENV["BITBUCKET_USER"]}/#{uuid}-#{adding_site_name}.git", "repo/#{uuid}-#{adding_site_name}"
    repo.config "user.name", ENV["BITBUCKET_USER"]
    repo.config "user.email", ENV["BITBUCKET_USER"]

    current_user.sites.create! name: adding_site_name, urls: ""
    user_session["current_site_name"] = adding_site_name
    redirect_to "/"
  end

  def change_site
    user_session["current_site_name"] = params[:site]
    redirect_to "/"
  end
end
