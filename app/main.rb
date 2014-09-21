# -*- encoding: utf-8 -*-

require "sinatra"
require "sinatra/json"
require "rack/contrib"
require "slim"
require "json"
require "yaml"
require "headless"
require "git"
require "securerandom"
require "digest/sha2"
require "uri"
require "./bitbucket-api"
require "./screenshooter.rb"

# app/
# db/
# repo/
# config.yml
# Dockerfile

raise "no repo directory" unless Dir.exist? "../repo"
raise "no db directory"   unless Dir.exist? "../db"

config = YAML.load(File.read "../config.yml")
api = Bitbucket::API.new config["bitbucket"]["user"], config["bitbucket"]["password"]

sites = {}
sites = JSON.load(File.read("../db/sites.json")) if File.exist?("../db/sites.json")

Signal.trap(:INT)  do File.write("../db/sites.json", JSON.pretty_generate(sites)) end
Signal.trap(:TERM) do File.write("../db/sites.json", JSON.pretty_generate(sites)) end

def show_error(status_code, message)
    @status_code = status_code.to_s
    @message = message
    slim :error
end

configure do
    use Rack::Session::Pool, :secret => config["rack_secret"]
    use Rack::PostBodyContentTypeParser
    set :bind, "0.0.0.0"
end

error do
    show_error 500, "internal server error"
end

get "/" do
    slim :index
end

post "/save_session" do
    if params[:site].empty?
        show_error 400, "invalid site name"
    else
        session[:site] = params[:site];
        session[:password] = params[:password];

        redirect to("/edit")
    end
end

post "/delete_session" do
    session[:site] = nil
    session[:password] = nil

    redirect to("/")
end

get "/edit" do
    site = session[:site]

    if site.nil?
        show_error 400, "invalid session"
    else
        if sites.include? site
            show_error 401, "invalid site or password" if Digest::SHA256.hexdigest(session[:password] + sites[site]["salt"]) != sites[site]["salted_hash"]
        else
            begin
                api.create_repository site

                sites[site] = {}
                sites[site]["urls"] = []
                sites[site]["salt"] = SecureRandom.uuid()
                sites[site]["salted_hash"] = Digest::SHA256.hexdigest(session[:password] + sites[site]["salt"])

                repo = Git.clone("git@bitbucket.org:#{config["bitbucket"]["user"]}/#{site}.git", "../repo/#{site}")
                repo.config("user.name", config["bitbucket"]["user"])
                repo.config("user.email", config["bitbucket"]["user"])
            rescue
                return show_error 400, "cannot create repository"
            end

            @site = site
            @urls = sites[site]["urls"].join("\\n")
            @urls_size = sites[site]["urls"].size
            slim :edit
        end
    end
end

post "/save_urls" do
    site = session[:site]

    urls = params[:urls].split("\n").map{ |url| url.strip }
    valid_urls =   urls.select{ |url| begin URI.parse(url).kind_of?(URI::HTTP) rescue false end }
    invalid_urls = urls.reject{ |url| begin URI.parse(url).kind_of?(URI::HTTP) rescue false end }
    sites[site]["urls"] = valid_urls
    {:message => "URLリストを保存しました", :urls => valid_urls.join("\n"), :urls_size => valid_urls.size, :invalid_urls => invalid_urls}.to_json
end

post "/shoot" do
    begin
        if session.include? :site
            site = session[:site]
        else
            halt 400, {:error => "site is required"}.to_json if not params.include? :site
            halt 400, {:error => "password is required"}.to_json if not params.include? :password
            halt 400, {:error => "invalid site or password"}.to_json if Digest::SHA256.hexdigest(session[:password] + sites[site]["salt"]) != sites[site]["salted_hash"]

            site = params[:site]
        end

        if not sites.include? site
            halt 404, {:error => "requested site is not in our database"}.to_json
        end

        if sites[site]["urls"].size == 0
            halt 400, {:error => "empty URL list"}.to_json
        end

        index = params[:index]

        if sites[site]["urls"].size <= index
            halt 400, {:error => "index out of range"}
        end

        Headless.ly do
            shooter = ScreenShooter.new
            Dir.chdir("../repo/#{site}") do
                begin
                    shooter.shoot sites[site]["urls"][index]
                rescue
                    halt 400, {:error => "invalid URL: #{url}"}.to_json
                end
            end
            shooter.close
        end

        {:url => sites[site]["urls"][index], :last => index + 1 == sites[site]["urls"].size}.to_json
    rescue => e
        p e
        puts e.backtrace.join("\n")
        halt 500, {:error => "internal server error"}.to_json
    end
end

post "/push_repository" do
    begin
        if session.include? :site
            site = session[:site]
        else
            halt 400, {:error => "site is required"}.to_json if not params.include? :site
            halt 400, {:error => "password is required"}.to_json if not params.include? :password
            halt 400, {:error => "invalid site or password"}.to_json if Digest::SHA256.hexdigest(session[:password] + sites[site]["salt"]) != sites[site]["salted_hash"]

            site = params[:site]
        end

        if not sites.include? site
            halt 404, {:error => "requested site is not in our database"}.to_json
        end

        if params.include? :commit_message
            commit_message = params[:commit_message].strip
        else
            commit_message = ""
        end

        repo = Git.open("../repo/#{site}")
        repo.add(:all => true)

        if repo.branches.size == 0 || repo.diff("HEAD", "--").size > 0
            if commit_message.empty?
                repo.commit "Snapshots at #{Time.now.to_s}"
            else
                repo.commit commit_message
            end
            repo.push

            {:url => "https://bitbucket.org/#{config["bitbucket"]["user"]}/#{site}/commits/#{repo.gcommit("HEAD").sha}"}.to_json
        else
            halt 400, {:error => "no changes in URLs"}.to_json
        end
    rescue => e
        p e
        puts e.backtrace.join("\n")
        halt 500, {:error => "internal server error"}.to_json
    end
end
