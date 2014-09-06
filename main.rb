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

user, password = JSON.load(File.read('bitbucket.json'))
api = Bitbucket::API.new(user, password)

sites = {}
sites = JSON.load(File.read('sites.json')) if File.exist?('sites.json')
p sites

Signal.trap(:INT)  do File.write('sites.json', JSON.pretty_generate(sites)) end
Signal.trap(:TERM) do File.write('sites.json', JSON.pretty_generate(sites)) end

get '/' do
    'Yo!'
end

get '/add' do
    slim :add
end

post '/edit' do
    site = params[:site]

    if sites.include? site
        pass if Digest::SHA256.hexdigest(params[:password] + sites[site]['salt']) != sites[site]['salted_hash']
    else
        sites[site] = {}
        sites[site]['urls'] = []
        sites[site]['salt'] = SecureRandom.uuid()
        sites[site]['salted_hash'] = Digest::SHA256.hexdigest(params[:password] + sites[site]['salt'])
        p sites[site]

        p api.create_repository site

        repo = Git.clone("git@bitbucket.org:snapsaver/#{site}.git", site)
        repo.config('user.name', 'snapsaver')
        repo.config('user.email', 'snapsaver')
    end

    @site = site
    @urls = sites[site]['urls'].join("\n")
    slim :edit
end

post '/save' do
    site = params[:site]
    sites[site]['urls'] = params[:urls].split("\n").map{ |url| url.strip }.select{ |url| url =~ URI::regexp }
    return "保存しました"
end

post "/shoot" do
    site = params[:site]

    Headless.ly do
        shooter = ScreenShooter.new
        Dir.chdir(site) do
            sites[site]['urls'].each do |url|
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

        "https://bitbucket.org/snapsaver/#{site}/commits/#{repo.gcommit('HEAD').sha}"
    else
        "変更はありません"
    end
end
