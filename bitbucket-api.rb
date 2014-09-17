require "net/https"

module Bitbucket
    class API
        def initialize(user, pass)
            @user = user
            @pass = pass
        end

        def create_repository(name)
            req = Net::HTTP::Post.new("/2.0/repositories/snapsaver/#{name}", {"Content-Type" => "application/json"})
            req.body = {"scm" => "git", "is_private" => "false", "fork_policy" => "allow_forks"}.to_json
            req.basic_auth(@user, @pass)

            sock = Net::HTTP.new("api.bitbucket.org", 443)
            sock.use_ssl = true
            sock.verify_mode = OpenSSL::SSL::VERIFY_NONE

            sock.start do |http|
                response = http.request(req)
                raise response.body if response.code != '200'
                response.body
            end
        end

        def delete_repository(name)
            req = Net::HTTP::Delete.new("/2.0/repositories/snapsaver/#{name}")
            req.basic_auth(@user, @pass)

            sock = Net::HTTP.new("api.bitbucket.org", 443)
            sock.use_ssl = true
            sock.verify_mode = OpenSSL::SSL::VERIFY_NONE

            sock.start do |s|
                s.request(req).body
            end
        end
    end
end
