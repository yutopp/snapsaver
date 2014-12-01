require "securerandom"

include InnerApiHelper

# FIXME: BREAKPOINTSのために他のコントローラのヘルパーを使ってる
include HomeHelper

class InnerApiController < ApplicationController
  @@screen_shooters = {}

  def make_id
    if user_signed_in?
      render status: 400, json: {error: "should not log in"}
      return
    end

    url_list_name = SecureRandom.uuid

    create_bitbucket_repository url_list_name

    repo = Git.clone "git@bitbucket.org:#{ENV["BITBUCKET_USER"]}/#{url_list_name}.git", "repo/#{url_list_name}"
    repo.config "user.name", ENV["BITBUCKET_USER"]
    repo.config "user.email", ENV["BITBUCKET_USER"]

    UrlList.create name: url_list_name, urls: params[:urls]
    redirect_to "/id/#{url_list_name}"
  end

  def save_urls
    if params[:list_name]
      url_list_name = params[:list_name]
    else
      render status: 400, json: {error: "URL list not specified"}
      return
    end

    urls = params[:urls].split("\n").map{ |url| url.strip }
    valid_urls =   urls.select{ |url| URI.parse(url).kind_of?(URI::HTTP) rescue false }
    invalid_urls = urls.reject{ |url| URI.parse(url).kind_of?(URI::HTTP) rescue false }
    valid_urls_joined = valid_urls.join "\n"

    if user_signed_in?
      url_list = current_user.url_lists.find_by name: url_list_name
      url_list.urls = valid_urls_joined
      url_list.save
    else
      url_list = UrlList.find_by name: url_list_name
      url_list.urls = valid_urls_joined
      url_list.save
    end

    render json: {message: "URLリストを保存しました",
                  urls: valid_urls_joined,
                  urls_size: valid_urls.size,
                  invalid_urls: invalid_urls}
  end

  def shoot
    url_list_name = params[:list_name]

    if url_list_name.nil?
      render status: 400, json: {error: "URL list not specified"}
      return
    end

    if user_signed_in?
      url_list = current_user.url_lists.find_by name: url_list_name
      repository_name = current_user.uuid + "-" + url_list_name
    else
      url_list = UrlList.find_by name: url_list_name
      repository_name = url_list_name
    end

    if url_list.nil?
      render status: 400, json: {error: "URL list not found"}
      return
    end

    if url_list.urls.empty?
      render status: 400, json: {error: "empty URL list"}
      return
    end

    index = params[:index].to_i
    urls = url_list.urls.split "\n"

    if index < 0 || urls.size <= index
      render status: 400, json: {error: "index out of range"}
      return
    end

    session_id = request.session_options[:id]

    if index == 0
      @@screen_shooters[session_id] = ScreenShooter.new
    end

    Dir.chdir("repo/#{repository_name}") do
      begin
        if params[:breakpoint] == "all"
          for breakpoint in BREAKPOINTS
            @@screen_shooters[session_id].set_width BREKPONT_TO_WIDTH[breakpoint]
            @@screen_shooters[session_id].shoot urls[index], breakpoint
          end
        else
          @@screen_shooters[session_id].set_width BREKPONT_TO_WIDTH[params[:breakpoint]]
          @@screen_shooters[session_id].shoot urls[index], params[:breakpoint]
        end
      rescue => e
        p e
        puts e.backtrace.join("\n")

        @@screen_shooters[session_id].close
        @@screen_shooters.delete session_id

        render status: 500, json: {error: "internal server error: #{urls[index]}"}
        return
      end
    end

    if index + 1 == urls.size
      @@screen_shooters[session_id].close
      @@screen_shooters.delete session_id
    end

    render json: {url: urls[index], last: index + 1 == urls.size}
  end

  def push_repository
    begin
      url_list_name = params[:list_name]

      if url_list_name.nil?
        render status: 400, json: {error: "URL list not specified"}
        return
      end

      if user_signed_in?
        url_list = current_user.url_lists.find_by name: url_list_name
        repository_name = current_user.uuid + "-" + url_list_name
      else
        url_list = UrlList.find_by name: url_list_name
        repository_name = url_list_name
      end

      if url_list.nil?
        render status: 400, json: {error: "URL list not found"}
        return
      end

      commit_message = params[:commit_message].strip

      repo = Git.open("repo/#{repository_name}")
      repo.add(all: true)

      if not File.exist? repo.index.to_s
        render status: 400, json: {error: "no changes in URLs"}
        return
      end

      if repo.branches.size == 0 || repo.diff("HEAD", "--").size > 0
        if commit_message.empty?
          repo.commit "Snapshots at #{Time.now.to_s}"
        else
          repo.commit commit_message
        end
        repo.push

        render json: {url: "https://bitbucket.org/#{ENV["BITBUCKET_USER"]}/#{repository_name}/commits/#{repo.gcommit("HEAD").sha}"}
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
