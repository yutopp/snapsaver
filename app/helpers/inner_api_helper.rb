require "selenium-webdriver"

module InnerApiHelper
  class BitbucketAPIException < Exception
  end

  def create_bitbucket_repository(name)
    user = ENV["BITBUCKET_USER"]
    pass = ENV["BITBUCKET_PASSWORD"]

    req = Net::HTTP::Post.new("/2.0/repositories/snapsaver/#{name}", {"Content-Type" => "application/json"})
    req.body = {"scm" => "git", "is_private" => "false", "fork_policy" => "allow_forks"}.to_json
    req.basic_auth(user, pass)

    sock = Net::HTTP.new("api.bitbucket.org", 443)
    sock.use_ssl = true
    sock.verify_mode = OpenSSL::SSL::VERIFY_NONE
    sock.set_debug_output $stderr

    sock.start do |http|
      response = http.request(req)
      raise BitbucketAPIException.new if response.code != '200'
      response.body
    end
  end

  class ScreenShooter
    def initialize
      Selenium::WebDriver::Firefox.path = "vendor/firefox/firefox"
      @driver = Selenium::WebDriver.for :firefox
    end

    def shoot(url)
      @driver.navigate.to url
      @driver.save_screenshot("#{url.gsub("/", "_")}.png")
    end

    def close
      @driver.quit
    end
  end
end
