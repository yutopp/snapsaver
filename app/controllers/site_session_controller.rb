class SiteSessionController < ApplicationController
  def make
    if params[:site].empty?
      @status = 400
      @message = "invalid site name"
      render template: "error/error"
      return
    else
      session[:site_name] = params[:site];
      redirect_to "/edit"
    end
  end

  def delete
    session[:site_name] = nil
    redirect_to "/"
  end
end
