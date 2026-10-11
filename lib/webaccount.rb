# webaccount.rb
# WebAccount

require 'selenium-webdriver'
require_relative './Thoran/Selenium'
require_relative './WebAccount/VERSION'

class WebAccount
  attr_accessor :username
  attr_accessor :password

  def initialize(
    username: nil, password: nil,
    browser: nil, driver_options: nil,
    login_page_url: nil,
    login_page_username_field_selector: nil, login_page_password_field_selector: nil,
    login_page_submit_button_selector: nil,
    logout_button_selector: nil,
    logged_out_xpath: nil
  )
    @username, @password = username, password
    @browser, @driver_options = browser, driver_options
    @login_page_url = login_page_url
    @login_page_username_field_selector, @login_page_password_field_selector = login_page_username_field_selector, login_page_password_field_selector
    @login_page_submit_button_selector = login_page_submit_button_selector
    @logout_button_selector = logout_button_selector
    @logged_out_xpath = logged_out_xpath
  end

  def login(username: nil, password: nil)
    @logged_in = false
    username ||= self.username
    password ||= self.password
    driver.attempt do
      get_login_page
      enter_username(username)
      enter_password(password)
      login_page_submit_button.click
    end
    @logged_in = driver_wait.until do
      driver.element_present?(logout_button_selector.keys.first, logout_button_selector.values.first)
    end
  end
  alias_method :logon, :login

  def logout
    logout_button.click
    if logged_out?
      @logged_in = false
    end
  end
  alias_method :logoff, :logout

  def shutdown
    logout if logged_in?
    driver.quit
  end

  def driver
    @driver ||= Selenium::WebDriver.for(browser, options: driver_options)
  end

  # predicate methods

  def logged_in?
    @logged_in
  end

  def logged_out?
    driver_wait.until do
      driver.element_present?(:xpath, @logged_out_xpath)
    end
  end

  def still_logged_in?
    @logged_in = driver.element_present?(logout_button_selector.keys.first, logout_button_selector.values.first)
  end

  private

  # driver construction

  def default_browser
    :chrome
  end

  def browser
    (@browser || default_browser).to_sym.downcase
  end

  def default_driver_options
    nil
  end

  def driver_options
    @driver_options || default_driver_options
  end

  # waiting

  # For navigation: a submit, the authentication behind it, and the redirect.
  def default_wait_timeout
    30
  end

  def driver_wait
    @driver_wait ||= Selenium::WebDriver::Wait.new(timeout: default_wait_timeout)
  end

  # For lookups: the element should already be on a page which has loaded.
  def default_find_timeout
    5
  end

  def find_wait
    @find_wait ||= Selenium::WebDriver::Wait.new(timeout: default_find_timeout)
  end

  def find(selector)
    find_wait.until{driver.find_element(selector.keys.first, selector.values.first)}
  end

  # logging in

  def login_page
    driver.get(@login_page_url)
  end
  alias_method :get_login_page, :login_page

  def enter_username(username = nil)
    username ||= self.username
    username_field.send_keys(username)
  end

  def default_username_field_selector
    {name: 'username'}
  end

  def username_field_selector
    @login_page_username_field_selector || default_username_field_selector
  end

  def username_field
    find(username_field_selector)
  end

  def enter_password(password = nil)
    password ||= self.password
    password_field.send_keys(password)
  end

  def default_password_field_selector
    {name: 'password'}
  end

  def password_field_selector
    @login_page_password_field_selector || default_password_field_selector
  end

  def password_field
    find(password_field_selector)
  end

  def default_login_page_submit_button_selector
    {xpath: '//input[@type="submit" and @value="Login"]'}
  end

  def login_page_submit_button_selector
    @login_page_submit_button_selector || default_login_page_submit_button_selector
  end

  def login_page_submit_button
    find(login_page_submit_button_selector)
  end

  # logging out

  def default_logout_button_selector
    {xpath: '//input[@type="submit" and @value="Logout"]'}
  end

  def logout_button_selector
    @logout_button_selector || default_logout_button_selector
  end

  def logout_button
    find(logout_button_selector)
  end
end
