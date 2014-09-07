require 'selenium-webdriver'

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
        @driver.close
    end
end
