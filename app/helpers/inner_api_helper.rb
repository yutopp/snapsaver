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

    sock.start do |http|
      response = http.request(req)
      raise BitbucketAPIException.new if response.code != '200'
      response.body
    end
  end

  def delete_bitbucket_repository(name)
    user = ENV["BITBUCKET_USER"]
    pass = ENV["BITBUCKET_PASSWORD"]

    req = Net::HTTP::Delete.new("/2.0/repositories/snapsaver/#{name}")
    req.basic_auth(user, pass)

    sock = Net::HTTP.new("api.bitbucket.org", 443)
    sock.use_ssl = true
    sock.verify_mode = OpenSSL::SSL::VERIFY_NONE

    sock.start do |http|
      response = http.request(req)
      raise BitbucketAPIException.new if response.code != '204'
      response.body
    end
  end

  BREKPONT_TO_WIDTH = {"lg" => 1210, "md" => 1002, "sm" => 778, "xs" => 758}

  class ScreenShooter
    def initialize
      Selenium::WebDriver::Firefox.path = "vendor/firefox/firefox"

      profile = Selenium::WebDriver::Firefox::Profile.new
      profile['browser.cache.disk.enable'] = false
      profile['browser.cache.memory.enable'] = false
      profile['browser.cache.offline.enable'] = false
      profile['network.http.use-cache'] = false

      @driver = Selenium::WebDriver.for :firefox, profile: profile
    end

    def set_width(width)
      @driver.manage.window.resize_to width, 1024
    end

    def shoot(url, breakpoint)
      @driver.navigate.to url

      @driver.execute_script <<-"JavaScript"
        boxes = document.getElementsByClassName("fb-like-box")
        for (i = 0; i < boxes.length; ++i) {
          boxes[i].style.opacity = 0;
        }
      JavaScript

      @driver.save_screenshot("#{url.gsub("/", "_")}.#{breakpoint}.png")
    end

    def close
      @driver.quit
    end
  end
end
