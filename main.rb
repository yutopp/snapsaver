# -*- encoding: utf-8 -*-

require 'sinatra'
require 'slim'
require 'json'
require 'headless'
require 'git'
require 'securerandom'
require 'digest/sha2'
require './bitbucket-api'
require './screenshooter.rb'

configure do
    enable :sessions
    set :port, 80
    set :bind, "0.0.0.0"
end

user, password = JSON.load(File.read('bitbucket.json'))
api = Bitbucket::API.new(user, password)

sites = {}
sites = JSON.load(File.read('sites.json')) if File.exist?('sites.json')

Signal.trap(:INT)  do File.write('sites.json', JSON.pretty_generate(sites)) end
Signal.trap(:TERM) do File.write('sites.json', JSON.pretty_generate(sites)) end

get '/' do
    slim :index
end

post '/save_session' do
    session[:site] = params[:site];
    session[:password] = params[:password];

    redirect to('/edit')
end

get '/edit' do
    site = session[:site]

    if sites.include? site
        pass if Digest::SHA256.hexdigest(session[:password] + sites[site]['salt']) != sites[site]['salted_hash']
    else
        sites[site] = {}
        sites[site]['urls'] = []
        sites[site]['salt'] = SecureRandom.uuid()
        sites[site]['salted_hash'] = Digest::SHA256.hexdigest(session[:password] + sites[site]['salt'])

        api.create_repository site

        repo = Git.clone("git@bitbucket.org:snapsaver/#{site}.git", site)
        repo.config('user.name', 'snapsaver')
        repo.config('user.email', 'snapsaver')
    end

    @site = site
    @urls = sites[site]['urls'].join("\\n")
    slim :edit
end

post '/save' do
    site = session[:site]

    sites[site]['urls'] = params[:urls].split("\n").map{ |url| url.strip }.select{ |url| url =~ URI::regexp }
    {:message => "保存しました", :urls => sites[site]['urls'].join("\n")}.to_json
end

post "/shoot" do
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

    Headless.ly do
        shooter = ScreenShooter.new
        Dir.chdir(site) do
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

    repo = Git.open(site)
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
        halt 400, {:error => "No changes in URLs"}.to_json
    end
end
