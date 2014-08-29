# -*- encoding: utf-8 -*-

require 'sinatra'
require 'slim'
require 'json'
require 'headless'
require 'git'
require './bitbucket-api'
require './screenshooter.rb'

user, password = JSON.load(File.read 'bitbucket.json')
api = Bitbucket::API.new(user, password)

urls_map = {}
urls_map = JSON.load(File.read('urls_map.json')) if File.exist?('urls_map.json')
p urls_map

Signal.trap(:INT)  do File.write('urls_map.json', JSON.pretty_generate(urls_map)) end
Signal.trap(:TERM) do File.write('urls_map.json', JSON.pretty_generate(urls_map)) end

get '/' do
    'Yo!'
end

get '/add' do
    @site=''
    slim :add
end

post '/add' do
    site = params[:site]

    if not urls_map.include? site
        p api.create_repository site

        repo = Git.clone("git@bitbucket.org:snapsaver/#{site}.git", site)
        repo.config('user.name', 'snapsaver')
        repo.config('user.email', 'snapsaver')

        urls_map[site] = []
    end

    @site = site
    slim :add
end

get '/edit/:site' do
    site = params[:site]
    pass if not urls_map.include? site

    @site = site
    @urls = urls_map[site].join("\n")
    slim :edit
end

post '/edit/:site' do
    site = params[:site]
    pass if not urls_map.include? site

    urls_map[site] = params[:urls].split("\n")
                                  .map { |item| item.strip }
                                  .reject { |item| item.empty? }

    @site = site
    @urls = urls_map[site].join("\n")
    @message = "saved"
    slim :edit
end

get '/shoot/:site' do
    site = params[:site]
    pass if not urls_map.include? site

    @site = site
    slim :shoot
end

post "/shoot/:site" do
    site = params[:site]
    pass if not urls_map.include? site

    Headless.ly do
        shooter = ScreenShooter.new
        Dir.chdir(site) do
            urls_map[site].each do |url|
                shooter.shoot url
            end
        end
        shooter.close
    end

    commit_message = params[:commit_message].strip

    repo = Git.open(site)
    repo.add(:all => true)

    if repo.branches.size == 0 || repo.diff('HEAD', '--').size > 0
        if commit_message.empty?
            repo.commit "Snapshots at #{Time.now.to_s}"
        else
            repo.commit commit_message
        end
        repo.push

        @is_new_commit_created = true
        @result = "https://bitbucket.org/snapsaver/#{site}/commits/#{repo.gcommit('HEAD').sha}"
    else
        @is_new_commit_created = false
        @result = "変更はありません"
    end

    @site = site
    slim :shoot
end
