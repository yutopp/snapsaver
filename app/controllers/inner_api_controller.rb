include InnerApiHelper

class InnerApiController < ApplicationController
  @@screen_shooters = {}

  def save_urls
    site_name = session[:site_name]

    if site_name.nil?
      render json: {error: "invalid session"}
      return
    end

    urls = params[:urls].split("\n").map{ |url| url.strip }
    valid_urls =   urls.select{ |url| begin URI.parse(url).kind_of?(URI::HTTP) rescue false end }
    invalid_urls = urls.reject{ |url| begin URI.parse(url).kind_of?(URI::HTTP) rescue false end }
    valid_urls_str = valid_urls.join "\n"

    site = Site.where(["name = ?", site_name]).first
    site.urls = valid_urls_str
    site.save

    render json: {message: "URLリストを保存しました",
                  urls: valid_urls_str,
                  urls_size: valid_urls.size,
                  invalid_urls: invalid_urls}
  end

  def shoot
    begin
      site_name = session[:site_name]

      if site_name.nil?
        render status: 400, json: {error: "invalid session"}
        return
      end

      site = Site.where(["name = ?", site_name]).first

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
      end

      Dir.chdir("repo/#{site_name}") do
        begin
          @@screen_shooters[session_id].shoot urls[index]
        rescue => e
          p e
          puts e.backtrace.join("\n")
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
      site_name = session[:site_name]

      if site_name.nil?
        render status: 400, json: {error: "invalid session"}
        return
      end

      site = Site.where(["name = ?", site_name]).first

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
