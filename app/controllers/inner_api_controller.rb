require "securerandom"

include InnerApiHelper

# FIXME: BREAKPOINTSのために他のコントローラのヘルパーを使ってる
include HomeHelper

class InnerApiController < ApplicationController
  @@screen_shooters = {}

  def make_id
    id = SecureRandom.uuid

    create_bitbucket_repository id

    repo = Git.clone "git@bitbucket.org:#{ENV["BITBUCKET_USER"]}/#{id}.git", "repo/#{id}"
    repo.config "user.name", ENV["BITBUCKET_USER"]
    repo.config "user.email", ENV["BITBUCKET_USER"]

    Site.create name: id, urls: params[:urls]
    redirect_to "/id/#{id}"
  end

  def save_urls
    if user_signed_in?
      current_site_name = user_session["current_site_name"]

      if current_site_name.nil?
        render json: {error: "invalid session"}
        return
      end
    end

    urls = params[:urls].split("\n").map{ |url| url.strip }
    valid_urls =   urls.select{ |url| URI.parse(url).kind_of?(URI::HTTP) rescue false }
    invalid_urls = urls.reject{ |url| URI.parse(url).kind_of?(URI::HTTP) rescue false }
    valid_urls_str = valid_urls.join "\n"

    if user_signed_in?
      site = current_user.sites.find_by name: current_site_name
      site.urls = valid_urls_str
      site.save
    else
      site = Site.find_by name: params[:id]
      site.urls = valid_urls_str
      site.save
    end

    render json: {message: "URLリストを保存しました",
                  urls: valid_urls_str,
                  urls_size: valid_urls.size,
                  invalid_urls: invalid_urls}
  end

  def shoot
    begin
      if user_signed_in?
        site_name = user_session["current_site_name"]
      else
        site_name = params[:id]
      end

      if site_name.nil?
        render status: 400, json: {error: "invalid session"}
        return
      end

      if user_signed_in?
        site = current_user.sites.find_by name: site_name
        # FIXME: 非常にアレな実装。repository_nameとかを使うべき
        site_name = current_user.uuid + "-" + site_name
      else
        site = Site.find_by name: site_name
      end

      if site.nil?
        render status: 400, json: {error: "invalid session"}
        return
      end

      if site.urls.empty?
        render status: 400, json: {error: "empty URL list"}
        return
      end

      index = params[:index].to_i
      urls = site.urls.split "\n"

      if urls.size <= index
        render status: 400, json: {error: "index out of range"}
        return
      end

      session_id = request.session_options[:id]

      if index == 0
        @@screen_shooters[session_id] = ScreenShooter.new

        if params[:breakpoint] != "all"
          @@screen_shooters[session_id].set_width BREKPONT_TO_WIDTH[params[:breakpoint]]
        end
      end

      Dir.chdir("repo/#{site_name}") do
        begin
          if params[:breakpoint] == "all"
            for breakpoint in BREAKPOINTS
              @@screen_shooters[session_id].set_width BREKPONT_TO_WIDTH[breakpoint]
              @@screen_shooters[session_id].shoot urls[index], breakpoint
            end
          else
            @@screen_shooters[session_id].shoot urls[index], params[:breakpoint]
          end
        rescue => e
          p e
          puts e.backtrace.join("\n")

          @@screen_shooters[session_id].close
          @@screen_shooters.delete session_id

          render status: 400, json: {error: "invalid URL: #{urls[index]}"}
          return
        end
      end

      if index + 1 == urls.size
        @@screen_shooters[session_id].close
        @@screen_shooters.delete session_id
      end

      render json: {url: urls[index], last: index + 1 == urls.size}
      return
    rescue => e
      p e
      puts e.backtrace.join("\n")
      render status: 500, json: {error: "internal server error"}
      return
    end
  end

  def push_repository
    begin
      if user_signed_in?
        site_name = user_session["current_site_name"]
      else
        site_name = params[:id]
      end

      if site_name.nil?
        render status: 400, json: {error: "invalid session"}
        return
      end

      if user_signed_in?
        site = current_user.sites.find_by name: site_name
        site_name = current_user.uuid + "-" + site_name
      else
        site = Site.find_by name: site_name
      end

      if site.nil?
        render status: 400, json: {error: "invalid session"}
        return
      end

      commit_message = params[:commit_message].strip

      repo = Git.open("repo/#{site_name}")
      repo.add(:all => true)

      if repo.branches.size == 0 || repo.diff("HEAD", "--").size > 0
        if commit_message.empty?
          repo.commit "Snapshots at #{Time.now.to_s}"
        else
          repo.commit commit_message
        end
        repo.push

        render json: {url: "https://bitbucket.org/#{ENV["BITBUCKET_USER"]}/#{site_name}/commits/#{repo.gcommit("HEAD").sha}"}
        return
      else
        render status: 400, json: {error: "no changes in URLs"}
        return
      end
    rescue => e
      p e
      puts e.backtrace.join("\n")
      render status: 500, json: {error: "internal server error"}
    end
  end
end
