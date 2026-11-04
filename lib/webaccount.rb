# webaccount.rb
# WebAccount

require 'selenium-webdriver'
require_relative './Thoran/Selenium'
require_relative './WebAccount/VERSION'

class WebAccount
  attr_accessor :username
  attr_accessor :password
  attr_reader :download_directory

  def initialize(
    username: nil, password: nil,
    browser: nil, driver_options: nil,
    profile_directory: nil, download_directory: File.join('~', 'Downloads'),
    headless: false, window_size: nil, user_agent: nil,
    login_page_url: nil,
    login_page_username_field_selector: nil, login_page_password_field_selector: nil,
    login_page_submit_button_selector: nil,
    logout_button_selector: nil,
    logged_out_xpath: nil
  )
    @username, @password = username, password
    @browser, @driver_options = browser, driver_options
    @profile_directory = profile_directory && File.expand_path(profile_directory)
    @download_directory = File.expand_path(download_directory)
    @headless, @window_size, @user_agent = headless, window_size, user_agent
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

  # The browser is quit whether or not logging out succeeds, so as a failed logout doesn't leave a logged-in browser behind.
  def shutdown
    logout if logged_in?
  ensure
    driver.quit
  end

  # The window is sized once the browser has started, so as it's the same for every browser, and holds whether or not driver_options are given.
  def driver
    @driver ||= Selenium::WebDriver.for(browser, options: driver_options).tap do |driver|
      driver.manage.window.resize_to(*@window_size) if @window_size
    end
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
    case browser
    when :chrome then default_chrome_options
    when :firefox then default_firefox_options
    end
  end

  # Chromedriver starts Chrome with a temporary profile unless given one. PDFs, which Chrome would otherwise show itself, are saved like anything else.
  def default_chrome_options
    Selenium::WebDriver::Chrome::Options.new.tap do |o|
      o.add_argument("--user-data-dir=#{@profile_directory}") if @profile_directory
      o.add_argument('--headless=new') if @headless
      o.add_argument("--user-agent=#{@user_agent}") if @user_agent
      o.add_argument('--disable-blink-features=AutomationControlled')
      o.exclude_switches << 'enable-automation'
      o.add_preference(:credentials_enable_service, false)
      o.add_preference(:download, default_directory: @download_directory, prompt_for_download: false, directory_upgrade: true, extensions_to_open: '')
      o.add_preference(:plugins, always_open_pdf_externally: true)
    end
  end

  # Geckodriver starts Firefox with a temporary profile unless given one with -profile, which it uses in place. Firefox has no preference which masks navigator.webdriver. PDFs, which it would otherwise show itself, are saved like anything else.
  def default_firefox_options
    Selenium::WebDriver::Firefox::Options.new.tap do |o|
      if @profile_directory
        o.add_argument('-profile')
        o.add_argument(@profile_directory)
      end
      o.add_argument('-headless') if @headless
      o.add_preference('general.useragent.override', @user_agent) if @user_agent
      o.add_preference('signon.rememberSignons', false)
      o.add_preference('browser.download.folderList', 2)
      o.add_preference('browser.download.dir', @download_directory)
      o.add_preference('browser.download.useDownloadDir', true)
      o.add_preference('browser.download.always_ask_before_handling_new_types', false)
      o.add_preference('browser.download.start_downloads_in_tmp_dir', false)
      o.add_preference('browser.download.alwaysOpenPanel', false)
      o.add_preference('browser.download.open_pdf_attachments_inline', false)
      o.add_preference('pdfjs.disabled', true)
    end
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

  # For downloads: a file arriving, which takes as long as it's large.
  def default_download_timeout
    120
  end

  def download_wait
    @download_wait ||= Selenium::WebDriver::Wait.new(timeout: default_download_timeout)
  end

  def find(selector)
    find_wait.until{driver.find_element(selector.keys.first, selector.values.first)}
  end

  def wait_for(selector)
    driver_wait.until{driver.find_elements(selector.keys.first, selector.values.first).any?(&:displayed?)}
  end

  # page interaction

  # Found afresh on each attempt, so as an element replaced by a redrawn page is retried rather than ending in StaleElementReferenceError. One which isn't displayed, such as a link in a closed menu, is clicked by JavaScript.
  def click(selector)
    driver.attempt do
      element = find(selector)
      element.displayed? ? element.click : driver.execute_script('arguments[0].click();', element)
    end
  end

  def stale?(element)
    element.displayed?
    false
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    true
  end

  # By JavaScript, so as a date picker or the like doesn't open over the field; the change event is for the page's own handlers.
  def set_value(element, value)
    driver.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('change', {bubbles: true}));", element, value)
  end

  # downloads

  # Waits up to default_download_timeout for a finished download.
  def wait_for_download(since:, extension: 'csv')
    download_wait.until{newest_download(since: since, extension: extension)}
  end

  # The newest finished file with that extension in download_directory changed at or after since; nil where there's none.
  def newest_download(since:, extension: 'csv')
    Dir.glob("*.#{extension}", base: @download_directory)
      .map{|basename| File.join(@download_directory, basename)}
      .select{|filename| File.mtime(filename) >= since && !downloading?(filename)}
      .max_by{|filename| File.mtime(filename)}
  end

  # Chrome downloads into <name>.crdownload, and renames it <name> once done. Firefox makes an empty <name> at once, and downloads into <stem>.<random>.<extensions>.part beside it, the stem being the name up to its first dot.
  def downloading?(filename)
    basename = File.basename(filename)
    stem, extensions = basename.split('.', 2)
    firefox_part_file = /\A#{Regexp.escape(stem)}\.([^.]+\.)?#{Regexp.escape(extensions.to_s)}\.part\z/
    Dir.children(File.dirname(filename)).any?{|child| child == "#{basename}.crdownload" || child.match?(firefox_part_file)}
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
