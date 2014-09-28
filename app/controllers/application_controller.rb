class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  #rescue_from Exception do |e|
  #  p e
  #  puts e.backtrace.join("\n")
  #  @status = e[:status].to_s
  #  @message = e[:message]
  #  render template: "error/error", status: e.status
  #end
end
