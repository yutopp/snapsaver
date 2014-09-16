# -*- encoding: utf-8 -*-

require 'sinatra'
require 'sinatra/json'
require 'rack/contrib'
require 'slim'
require 'json'
require 'headless'
require 'git'
require 'securerandom'
require 'digest/sha2'
require 'uri'
require './bitbucket-api'
require './screenshooter.rb'


user, password = JSON.load(File.read('bitbucket.json'))
api = Bitbucket::API.new(user, password)

sites = {}
sites = JSON.load(File.read('sites.json')) if File.exist?('sites.json')

Signal.trap(:INT)  do File.write('sites.json', JSON.pretty_generate(sites)) end
Signal.trap(:TERM) do File.write('sites.json', JSON.pretty_generate(sites)) end

def show_server_error(status_code)
    @status_code = status_code.to_s
    slim :error
end

configure do
    use Rack::Session::Cookie
    use Rack::PostBodyContentTypeParser
    set :bind, "0.0.0.0"
end

error do
    show_server_error(500)
end

get '/' do
    slim :index
end

post '/save_session' do
    if params[:site].empty?
        show_server_error 400
    else
        session[:site] = params[:site];
        session[:password] = params[:password];

        redirect to('/edit')
    end
end

post '/delete_session' do
    session[:site] = nil
    session[:password] = nil

    redirect to('/')
end

get '/edit' do
    site = session[:site]

    if site.nil?
        show_server_error 400
    else
        if sites.include? site
            pass if Digest::SHA256.hexdigest(session[:password] + sites[site]['salt']) != sites[site]['salted_hash']
        else
            sites[site] = {}
            sites[site]['urls'] = []
            sites[site]['salt'] = SecureRandom.uuid()
            sites[site]['salted_hash'] = Digest::SHA256.hexdigest(session[:password] + sites[site]['salt'])

            api.create_repository site

            repo = Git.clone("git@bitbucket.org:snapsaver/#{site}.git", "repos/#{site}")
            repo.config('user.name', 'snapsaver')
            repo.config('user.email', 'snapsaver')
        end

        @site = site
        @urls = sites[site]['urls'].join("\\n")
        slim :edit
    end
end

post '/save_urls' do
    site = session[:site]

    urls = params[:urls].split("\n").map{ |url| url.strip }
    valid_urls =   urls.select{ |url| begin URI.parse(url).kind_of?(URI::HTTP) rescue false end }
    invalid_urls = urls.reject{ |url| begin URI.parse(url).kind_of?(URI::HTTP) rescue false end }
    sites[site]['urls'] = valid_urls
    {:message => "URLリストを保存しました", :urls => valid_urls.join("\n"), :invalid_urls => invalid_urls}.to_json
end

post "/shoot" do
    begin
        if session.include? :site
            site = session[:site]
        else
            halt 400, {:error => "site is required"}.to_json if not params.include? :site
            halt 400, {:error => "password is required"}.to_json if not params.include? :password
            halt 400, {:error => "invalid site or password"}.to_json if Digest::SHA256.hexdigest(session[:password] + sites[site]['salt']) != sites[site]['salted_hash']

            site = params[:site]
        end

        if not sites.include? site
            halt 404, {:error => "requested site is not in our database"}.to_json
        end

        if sites[site]['urls'].size == 0
            halt 400, {:error => "empty URL list"}.to_json
        end

        Headless.ly do
            shooter = ScreenShooter.new
            Dir.chdir("repos/#{site}") do
                sites[site]['urls'].each do |url|
                    begin
                        shooter.shoot url
                    rescue
                        halt 400, {:error => "invalid URL: #{url}"}.to_json
                    end
                end
            end
            shooter.close
        end

        if params.include? :commit_message
            commit_message = params[:commit_message].strip
        else
            commit_message = ""
        end

        repo = Git.open("repos/#{site}")
        repo.add(:all => true)

        if repo.branches.size == 0 || repo.diff('HEAD', '--').size > 0
            if commit_message.empty?
                repo.commit "Snapshots at #{Time.now.to_s}"
            else
                repo.commit commit_message
            end
            repo.push

            {:url => "https://bitbucket.org/snapsaver/#{site}/commits/#{repo.gcommit('HEAD').sha}"}.to_json
        else
            halt 400, {:error => "no changes in URLs"}.to_json
        end
    rescue => e
        p e
        puts e.backtrace.join("\n")
        halt 500, {:error => "internal server error"}.to_json
    end
end
