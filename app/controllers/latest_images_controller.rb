require "git"

# FIXME: BREAKPOINTSのために別のコントローラのヘルパーを使ってる
include HomeHelper

class LatestImagesController < ApplicationController
  def latest_images
    id = params[:id]

    if user_signed_in?
      @site_name = user_session["current_site_name"]
      urls = current_user.sites.find_by(name: @site_name).urls
      repository_name = current_user.uuid + "-" + @site_name

    elsif id
      @site_name = id
      urls = Site.find_by(name: @site_name).urls
      repository_name = id
    else
      redirect_to "/"
      return
    end

    repository = Git.open("repo/#{repository_name}")

    if repository.branches.size > 0
      head_sha = repository.gcommit("HEAD").sha
    else
      redirect_to "/"
      return
    end

    
    @latest_images = urls.split("\n").map{ |url|
      BREAKPOINTS.map{ |breakpoint|
        {
          breakpoint: breakpoint,
          url: url,
          url_to_image: "https://bytebucket.org/snapsaver/#{repository_name}/raw/#{head_sha}/#{url.gsub "/", "_"}.#{breakpoint}.png"
        }
      }
    }

  end
end
