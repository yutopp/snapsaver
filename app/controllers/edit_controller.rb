include EditHelper

class EditController < ApplicationController
  def edit
    site_name = session[:site_name]

    if site_name.nil?
      @status = 400
      @message = "invalid session"
      render template: "error/error"
      return
    end

    site = Site.where(["name = ?", site_name]).first

    if site.nil?
      begin
        create_bitbucket_repository site_name

        repo = Git.clone "git@bitbucket.org:#{ENV["BITBUCKET_USER"]}/#{site_name}.git", "repo/#{site_name}"
        repo.config "user.name", ENV["BITBUCKET_USER"]
        repo.config "user.email", ENV["BITBUCKET_USER"]

        site = Site.create name: site_name, urls: ""
      rescue BitbucketAPIException
        @status = 400
        @message = "cannot create repository"
        render template: "error/error"
        return
      end
    end

    @site = site.name
    @urls = site.urls.gsub "\n", "\\n"
    @urls_size = site.urls.count "\n"
  end
end
